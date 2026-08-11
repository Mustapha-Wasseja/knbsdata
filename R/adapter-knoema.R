# Knoema adapter ---------------------------------------------------------------
#
# Talks to kenya.opendataforafrica.org, the Knoema-platform portal that
# republishes KNBS and partner-agency datasets. Traced 2026-08-11 (audit F-30);
# it is a third-party republisher, so every result's provenance names the
# portal and points at the original producer.
#
# Portal behaviours that shape this adapter:
#
#   - An unknown dataset id answers 200 with a bare explanatory string, not a
#     404 (audit F-31, the F-17 family); the string is recognised and classed
#     as a missing resource.
#   - The dataset listing's structural fields are unreliable (audit F-32);
#     structure is read only from each dataset's own metadata.
#   - Datasets may mix frequencies in one id (audit F-33); the standardiser
#     requires an explicit frequency choice rather than picking silently.
#   - robots.txt disallows the /api/1.0/sdmx export route; this adapter uses
#     only the JSON API it permits.

#' A portal GET
#'
#' The adapter's single network entry point, mocked in tests.
#' @noRd
knoema_get <- function(source, path, query = list(), call = rlang::caller_env()) {
  req <- knbs_request(paste0(sub("/+$", "", source$base_url), "/", path), throttle = 2)
  # Pin plain HTTP/1.1 (libcurl's CURL_HTTP_VERSION_1_1). The portal's edge
  # intermittently challenges libcurl's default version negotiation while
  # serving this same transparently-identified client over an explicit
  # standard version (audit F-34). Identity is never disguised and challenges
  # are never solved: if one returns anyway, it surfaces as the classed
  # access error.
  req <- httr2::req_options(req, http_version = 2)
  if (length(query) > 0L) {
    req <- httr2::req_url_query(req, !!!query)
  }
  resp <- knbs_perform(req, source_id = source$source_id, expect = "json", call = call)
  payload <- parse_json_response(resp, source_id = source$source_id, call = call)

  # The portal answers 200 with a bare explanatory string where other APIs
  # would answer 404 (audit F-31). That is a missing resource, not data.
  if (is.character(payload) && length(payload) == 1L) {
    if (grepl("exist|access", payload, ignore.case = TRUE)) {
      knbs_abort(
        c(
          "The source has no dataset with that identifier.",
          "x" = "It said: {.val {payload}}.",
          "i" = "List what exists with {.fn knbs_indicators}."
        ),
        class = "knbs_error_resource_not_found",
        call = call
      )
    }
    knbs_abort(
      c(
        "The source answered a bare string where an object was expected; please report it.",
        "x" = "It said: {.val {payload}}."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  payload
}

#' The dataset listing as the indicator-catalogue schema
#'
#' Only identity fields are read here: the listing's structural fields
#' contradict the per-dataset metadata (audit F-32), and the API states no
#' subject classification, so `topic` is honestly `NA`.
#' @noRd
knoema_catalogue <- function(source, call = rlang::caller_env()) {
  payload <- knoema_get(source, "1.0/meta/dataset", call = call)
  ok <- is.list(payload) && length(payload) > 0L &&
    all(vapply(
      payload,
      function(d) is.list(d) && !is.null(d$id) && !is.null(d$name),
      logical(1)
    ))
  if (!ok) {
    knbs_abort(
      c(
        "The dataset listing changed shape; please report it.",
        "i" = "Expected an array of objects carrying {.field id} and {.field name}."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  ids <- vapply(payload, function(d) as.character(d$id), character(1))
  if (anyDuplicated(ids) > 0L) {
    knbs_abort(
      c("The dataset listing repeats an id; please report it."),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  tibble::tibble(
    indicator_id = ids,
    indicator_name = vapply(payload, function(d) as.character(d$name), character(1)),
    topic = NA_character_,
    frequency = NA_character_,
    unit = NA_character_,
    source_id = source$source_id
  )
}

#' A dataset's own metadata payload, shape-checked
#' @noRd
knoema_dataset_meta <- function(source, resource_id, call = rlang::caller_env()) {
  payload <- knoema_get(source, paste0("1.0/meta/dataset/", resource_id),
                        call = call)
  if (!is.list(payload) || is.null(payload$name) || !is.list(payload$dimensions)) {
    knbs_abort(
      c(
        "The dataset's metadata changed shape; please report it.",
        "i" = "Expected an object carrying {.field name} and {.field dimensions}."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  payload
}

#' Every series of a dataset, following continuation tokens
#' @noRd
knoema_all_series <- function(source, resource_id, call = rlang::caller_env()) {
  pages <- 0L
  token <- NULL
  series <- list()
  repeat {
    pages <- pages + 1L
    if (pages > 50L) {
      knbs_abort(
        c(
          "The dataset did not finish paging within 50 pages; please report it.",
          "i" = "Returning part of a dataset silently is not an option."
        ),
        class = "knbs_error_schema_changed",
        call = call
      )
    }
    query <- list(datasetId = resource_id)
    if (!is.null(token)) {
      query$continuationToken <- token
    }
    payload <- knoema_get(source, "2.0/data", query = query, call = call)
    if (!is.list(payload) || !is.list(payload$data)) {
      knbs_abort(
        c(
          "The data response changed shape; please report it.",
          "i" = "Expected an object carrying a {.field data} array."
        ),
        class = "knbs_error_schema_changed",
        call = call
      )
    }
    series <- c(series, payload$data)
    token <- payload$continuationToken
    if (is.null(token)) {
      return(series)
    }
  }
}

#' Provenance notes shared by fetch and metadata results
#' @noRd
knoema_provenance_notes <- function(source, meta) {
  original <- as.character(meta$ref %||% "")
  published <- substr(as.character(meta$publicationDate %||% ""), 1, 10)
  updated <- substr(as.character(meta$lastUpdatedOn %||% ""), 1, 10)
  c(
    paste0(
      "Republished by ", source$source_name,
      if (nzchar(original)) paste0("; the original data lives at ", original),
      "."
    ),
    if (nzchar(published)) {
      paste0(
        "Published by the source ", published,
        if (nzchar(updated)) paste0("; the portal copy was last updated ", updated),
        "."
      )
    }
  )
}

#' The licence label a dataset states, verbatim
#' @noRd
knoema_licence <- function(meta) {
  licence <- as.character(meta$source$licenseTypeName %||% "")
  if (nzchar(licence)) licence else "Not stated by the source"
}

#' Human-readable dimension names of a dataset
#' @noRd
knoema_dim_names <- function(meta) {
  vapply(
    meta$dimensions,
    function(d) as.character(d$name %||% d$id %||% "?"),
    character(1)
  )
}

#' @export
source_search.knbs_source_knoema <- function(source, query, ...) {
  check_operation(source, "list_indicators")
  check_source_verified(source)
  check_supported_filters(query, c("search", "topic"))

  out <- knoema_catalogue(source)

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
      title = paste0(source$source_name, " dataset catalogue"),
      resource_type = "indicator",
      source_id = source$source_id,
      source_name = source$source_name,
      source_url = source$landing_page %||% source$base_url,
      producer = source$owner,
      licence = "Varies by dataset; each dataset's metadata states its own label",
      access = "open"
    )
  )
}

#' @export
source_fetch.knbs_source_knoema <- function(source, query, ...) {
  check_operation(source, "get_indicator")
  check_source_verified(source)
  check_supported_filters(query, c("geo_code", "frequency"))

  resource_id <- query$resource_id %||% ""
  meta <- knoema_dataset_meta(source, resource_id)
  series <- knoema_all_series(source, resource_id)
  out <- standardise_knoema_obs(
    series, meta, resource_id, source$source_id,
    frequency = query$filters$frequency
  )

  filters <- query$filters
  if (!is.null(filters$geo_code)) {
    if (!"geo_code" %in% names(out$table)) {
      knbs_abort(
        c(
          "{.val {resource_id}} has no geography dimension.",
          "i" = "Its dimensions: {.val {knoema_dim_names(meta)}}."
        ),
        class = "knbs_error_invalid_query"
      )
    }
    out$table <- out$table[out$table$geo_code %in% as.character(filters$geo_code), ]
  }

  new_knbs_data(
    out$table,
    new_knbs_metadata(
      title = as.character(meta$name),
      resource_id = resource_id,
      resource_type = "indicator",
      source_id = source$source_id,
      source_name = source$source_name,
      source_url = paste0(
        sub("/+$", "", source$landing_page %||% source$base_url), "/", resource_id
      ),
      producer = as.character(meta$source$name %||% source$owner),
      reference_period = if (nrow(out$table) > 0L) {
        paste(min(out$table$period_label), "to", max(out$table$period_label))
      } else {
        NULL
      },
      unit = out$unit,
      frequency = out$frequency,
      licence = knoema_licence(meta),
      access = "open",
      notes = c(
        knoema_provenance_notes(source, meta),
        if (length(out$fixed) > 0L) {
          paste0(
            "Fixed for the whole dataset: ",
            paste(out$fixed, collapse = "; "), "."
          )
        },
        out$scale_note,
        if ("geo_code" %in% names(out$table)) {
          paste0(
            "Geography codes are the portal's own region codes, not census ",
            "territories; do not join them against knbs_geographies()."
          )
        }
      )
    ),
    class = "knbs_indicator"
  )
}

#' @export
source_metadata.knbs_source_knoema <- function(source, resource_id, ...) {
  check_operation(source, "indicator_metadata")
  check_source_verified(source)
  check_string(resource_id, "resource_id")

  meta <- knoema_dataset_meta(source, resource_id)
  next_release <- substr(as.character(meta$nextReleaseDate %||% ""), 1, 10)

  new_knbs_metadata(
    title = as.character(meta$name),
    resource_id = resource_id,
    resource_type = "indicator",
    source_id = source$source_id,
    source_name = source$source_name,
    source_url = paste0(
      sub("/+$", "", source$landing_page %||% source$base_url), "/", resource_id
    ),
    producer = as.character(meta$source$name %||% source$owner),
    licence = knoema_licence(meta),
    access = "open",
    notes = c(
      knoema_provenance_notes(source, meta),
      paste0("Dimensions: ", paste(knoema_dim_names(meta), collapse = ", "), "."),
      if (nzchar(next_release)) {
        paste0("The source announced a next release for ", next_release, ".")
      }
    )
  )
}

#' @export
source_health.knbs_source_knoema <- function(source, ...) {
  started <- Sys.time()
  outcome <- tryCatch(
    {
      catalogue <- knoema_catalogue(source)
      list(
        status = "ok",
        message = paste0(
          "Dataset listing answered; ", nrow(catalogue), " datasets listed."
        )
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
