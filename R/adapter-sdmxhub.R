# SDMX hub adapter ------------------------------------------------------------
#
# Talks to the KNBS Data Portal at opendata.knbs.or.ke, traced 2026-08-08
# (audit F-28): an Istat DataBrowser hub over an SDMX service, carrying 323
# dataflows across five statistical domains.
#
# Two behaviours of that API shape this adapter:
#
#   - Data queries are POSTs. A GET of the data route answers 405; the body is
#     a JSON array of criteria, and an empty array returns the whole dataflow.
#   - Responses are JSON-stat with sparse values, parsed by the same generic
#     parser the census adapter uses, and carry a `role` field naming the time
#     and geography dimensions outright.

#' A hub GET
#'
#' One of the adapter's two network entry points, mocked in tests.
#' @noRd
hub_get <- function(source, path, call = rlang::caller_env()) {
  req <- knbs_request(paste0(sub("/+$", "", source$base_url), "/", path), throttle = 2)
  resp <- knbs_perform(req, source_id = source$source_id, expect = "json", call = call)
  parse_json_response(resp, source_id = source$source_id, call = call)
}

#' A hub data POST
#'
#' The other network entry point. The criteria body is always the empty array:
#' dataflows here are small (tens of kilobytes), and client-side filtering
#' keeps the caching story simple.
#' @noRd
hub_post_data <- function(source, ref, call = rlang::caller_env()) {
  req <- knbs_request(
    paste0(sub("/+$", "", source$base_url), "/datasets/", ref, "/data"),
    throttle = 2
  )
  req <- httr2::req_body_json(req, list(), auto_unbox = FALSE)
  resp <- knbs_perform(req, source_id = source$source_id, expect = "json", call = call)
  parse_json_response(resp, source_id = source$source_id, call = call)
}

#' The hub catalogue payload, cached
#' @noRd
hub_catalog_payload <- function(source, call = rlang::caller_env()) {
  cache_fetch(
    cache_key(source$source_id, "hub_catalog", resource_id = "catalog"),
    fetch = function() {
      payload <- hub_get(source, "catalog", call = call)
      if (!is.list(payload) || is.null(payload$datasetMap)) {
        knbs_abort(
          c(
            "The hub catalogue changed shape; please report it.",
            "i" = "Expected an object carrying {.field datasetMap}."
          ),
          class = "knbs_error_schema_changed",
          call = call
        )
      }
      payload
    },
    ttl = knbs_cache_ttl("catalogue"),
    info = list(source_id = source$source_id, operation = "hub_catalog")
  )
}

#' Walk the category tree, mapping each dataflow ref to its domain
#' @noRd
hub_topic_map <- function(payload) {
  acc <- new.env(parent = emptyenv())
  walk <- function(node, topic) {
    for (ref in as.character(unlist(node$datasetIdentifiers))) {
      assign(ref, topic, envir = acc)
    }
    for (child in c(node$categories, node$childrenCategories)) {
      walk(child, topic)
    }
  }
  for (group in payload$categoryGroups) {
    label <- group$label
    if (is.list(label)) label <- label$en %||% label[[1]]
    walk(group, as.character(label %||% NA_character_))
  }
  refs <- ls(acc)
  stats::setNames(vapply(refs, get, character(1), envir = acc), refs)
}

#' The catalogue as a tibble, plus the id -> full-ref map
#' @noRd
hub_catalogue <- function(source, call = rlang::caller_env()) {
  payload <- hub_catalog_payload(source, call = call)
  refs <- names(payload$datasetMap)

  titles <- vapply(payload$datasetMap, function(d) {
    t <- d$title
    if (is.list(t)) t <- t$en %||% t[[1]]
    as.character(t %||% NA_character_)
  }, character(1))

  # "KE1,DF_NAT_GDPCP,1.0" -> id "DF_NAT_GDPCP". The middle segment is the
  # user-facing id; a collision would make ids ambiguous, so it is refused.
  ids <- vapply(strsplit(refs, ",", fixed = TRUE), function(p) {
    if (length(p) == 3L) p[[2]] else NA_character_
  }, character(1))
  if (anyNA(ids) || anyDuplicated(ids) > 0L) {
    knbs_abort(
      c("The hub's dataflow references changed shape; please report it.",
        "i" = "Expected unique {.val agency,id,version} triples."),
      class = "knbs_error_schema_changed",
      call = call
    )
  }

  topics <- hub_topic_map(payload)
  list(
    table = tibble::tibble(
      indicator_id = ids,
      indicator_name = unname(titles),
      topic = unname(topics[refs]),
      frequency = NA_character_,
      unit = NA_character_,
      source_id = source$source_id
    ),
    refs = stats::setNames(refs, ids)
  )
}

#' @export
source_search.knbs_source_sdmxhub <- function(source, query, ...) {
  check_operation(source, "list_indicators")
  check_source_verified(source)
  check_supported_filters(query, c("search", "topic"))

  out <- hub_catalogue(source)$table

  filters <- query$filters
  if (!is.null(filters$topic)) {
    out <- out[!is.na(out$topic) &
                 tolower(out$topic) %in% tolower(as.character(filters$topic)), ]
  }
  if (!is.null(filters$search)) {
    out <- out[grepl(filters$search, out$indicator_name, ignore.case = TRUE), ]
  }

  new_knbs_catalogue(
    out,
    new_knbs_metadata(
      title = paste0(source$source_name, " dataflow catalogue"),
      resource_type = "indicator",
      source_id = source$source_id,
      source_name = source$source_name,
      source_url = source$landing_page %||% source$base_url,
      producer = source$owner,
      licence = "Not stated by the source",
      access = "open"
    )
  )
}

#' @export
source_fetch.knbs_source_sdmxhub <- function(source, query, ...) {
  check_operation(source, "get_indicator")
  check_source_verified(source)
  check_supported_filters(query, c("start", "end", "geo_code"))

  catalogue <- hub_catalogue(source)
  ref <- unname(catalogue$refs[query$resource_id %||% ""])
  if (is.na(ref)) {
    knbs_abort(
      c(
        "This source has no dataflow {.val {query$resource_id}}.",
        "i" = "List what exists with {.fn knbs_indicators}."
      ),
      class = "knbs_error_resource_not_found"
    )
  }

  payload <- hub_post_data(source, ref)
  roles <- list(
    time = as.character(unlist(payload$role$time)),
    geo = as.character(unlist(payload$role$geo))
  )
  parsed <- parse_jsonstat(payload, source_id = source$source_id)
  out <- standardise_sdmx_obs(parsed, query$resource_id, source$source_id, roles)

  filters <- query$filters
  if (!is.null(filters$geo_code)) {
    if (!"geo_code" %in% names(out$table)) {
      knbs_abort(
        c("{.val {query$resource_id}} has no geography dimension.",
          "i" = "Its dimensions: {.val {unname(parsed$meta$dimension_labels)}}."),
        class = "knbs_error_invalid_query"
      )
    }
    out$table <- out$table[out$table$geo_code %in% as.character(filters$geo_code), ]
  }

  name <- catalogue$table$indicator_name[
    catalogue$table$indicator_id == query$resource_id
  ]
  new_knbs_data(
    out$table,
    new_knbs_metadata(
      title = parsed$meta$label %||% name,
      resource_id = query$resource_id,
      resource_type = "indicator",
      source_id = source$source_id,
      source_name = source$source_name,
      source_url = source$landing_page %||% source$base_url,
      producer = source$owner,
      reference_period = if (nrow(out$table) > 0L) {
        paste(min(out$table$period_label), "to", max(out$table$period_label))
      } else {
        NULL
      },
      unit = out$unit,
      frequency = out$frequency,
      licence = "Not stated by the source",
      access = "open",
      notes = c(
        paste0("Dimensions: ",
               paste(unname(parsed$meta$dimension_labels), collapse = ", "), "."),
        if (length(out$fixed) > 0L) {
          paste0("Fixed for the whole dataflow: ",
                 paste(out$fixed, collapse = "; "), ".")
        },
        if ("geo_code" %in% names(out$table)) {
          "Geography codes are SDMX area codes, not census territories; do not join them against knbs_geographies()."
        }
      )
    ),
    class = "knbs_indicator"
  )
}

#' @export
source_metadata.knbs_source_sdmxhub <- function(source, resource_id, ...) {
  check_operation(source, "indicator_metadata")
  check_source_verified(source)
  check_string(resource_id, "resource_id")

  catalogue <- hub_catalogue(source)
  ref <- unname(catalogue$refs[resource_id])
  if (is.na(ref)) {
    knbs_abort(
      c("This source has no dataflow {.val {resource_id}}.",
        "i" = "List what exists with {.fn knbs_indicators}."),
      class = "knbs_error_resource_not_found"
    )
  }
  row <- catalogue$table[catalogue$table$indicator_id == resource_id, ]

  structure_payload <- hub_get(source, paste0("datasets/", ref, "/structure"))
  criteria <- vapply(structure_payload$criteria %||% list(), function(cr) {
    as.character(cr$label %||% cr$id %||% "?")
  }, character(1))

  new_knbs_metadata(
    title = row$indicator_name,
    resource_id = resource_id,
    resource_type = "indicator",
    source_id = source$source_id,
    source_name = source$source_name,
    source_url = source$landing_page %||% source$base_url,
    producer = source$owner,
    licence = "Not stated by the source",
    access = "open",
    notes = c(
      if (!is.na(row$topic)) paste0("Domain: ", row$topic, "."),
      paste0("Dimensions: ", paste(criteria, collapse = ", "), ".")
    )
  )
}

#' @export
source_health.knbs_source_sdmxhub <- function(source, ...) {
  started <- Sys.time()
  outcome <- tryCatch(
    {
      payload <- hub_get(source, "catalog")
      list(
        status = if (is.list(payload) && !is.null(payload$datasetMap)) "ok" else "unavailable",
        message = paste0("Catalogue answered; ",
                         length(payload$datasetMap %||% list()), " dataflows listed.")
      )
    },
    knbs_error = function(cnd) {
      list(status = "unavailable", message = conditionMessage(cnd))
    }
  )
  tibble::tibble(
    source_id = source$source_id,
    operation = "list_indicators",
    status = outcome$status,
    http_status = NA_integer_,
    response_time_ms = as.numeric(difftime(Sys.time(), started, units = "secs")) * 1000,
    checked_at = started,
    message = outcome$message
  )
}
