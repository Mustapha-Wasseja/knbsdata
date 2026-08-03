# NADA adapter ----------------------------------------------------------------
#
# Talks to a NADA catalogue over its JSON API. Verified against the Kenya
# National Data Archive on 2026-08-03; see dev/source-discovery/source-audit.md.
#
# Two behaviours of that API shape this adapter:
#
#   F-02  Detail endpoints key on the DDI idno, not the numeric id.
#         /api/catalog/128 is a 400; /api/catalog/DDI-KEN-... is the study.
#
#   F-08  An unknown subpath does not 404. It returns 200 with the *study*
#         payload. So a request for variables at a renamed path would come back
#         looking successful, carrying entirely the wrong object. Every response
#         is therefore checked for the fields it must have, and a study payload
#         arriving where it was not asked for is reported as a schema change.

#' Build an API URL for a NADA source
#' @noRd
nada_url <- function(source, path) {
  paste0(sub("/+$", "", source$base_url), "/", path)
}

#' A NADA API request
#'
#' Requests are throttled to one per second and issued serially: the catalogue
#' is a small public service and this package should not be the reason it slows
#' down (plan section 24.4).
#'
#' @noRd
nada_get <- function(source, path, query = list(), call = rlang::caller_env()) {
  req <- knbs_request(nada_url(source, path), throttle = 1)
  if (length(query) > 0L) {
    req <- httr2::req_url_query(req, !!!query)
  }
  resp <- knbs_perform(
    req,
    source_id = source$source_id,
    expect = "json",
    body_check = function(resp) nada_body_check(resp, source$source_id, call = call),
    call = call
  )
  payload <- parse_json_response(resp, source_id = source$source_id, call = call)
  # Carried for the health check, which reports the status it actually saw
  # rather than assuming one.
  attr(payload, "knbs_http_status") <- httr2::resp_status(resp)
  payload
}

#' Turn NADA's own failure messages into the right condition
#'
#' The API answers an unknown identifier with `400` and
#' `{"status":"failed","message":"IDNO-NOT-FOUND"}`. That is a missing resource,
#' not a malformed query, and callers need to be able to tell them apart.
#'
#' @noRd
nada_body_check <- function(resp, source_id, call = rlang::caller_env()) {
  if (httr2::resp_status(resp) != 400L) {
    return(invisible(resp))
  }
  body <- tryCatch(httr2::resp_body_string(resp), error = function(cnd) "")
  if (!grepl("IDNO-NOT-FOUND", body, fixed = TRUE)) {
    return(invisible(resp))
  }
  knbs_abort(
    c(
      "The source has no study with that identifier.",
      "i" = "Detail endpoints use the DDI identifier, for example {.val KEN-KNBS-KIHBS-2015-2016-v01}.",
      "i" = "Search the catalogue with {.fn knbs_search_surveys} to find it."
    ),
    class = "knbs_error_resource_not_found",
    call = call
  )
}

#' Insist that a payload has the fields the operation requires
#'
#' See F-08 above: without this, a study payload returned from a renamed
#' endpoint would be parsed as though it were the thing that was asked for.
#'
#' @noRd
nada_expect <- function(payload, fields, source_id, operation, call = rlang::caller_env()) {
  missing_fields <- setdiff(fields, names(payload))
  if (length(missing_fields) == 0L) {
    return(invisible(payload))
  }

  bullets <- c(
    "The source returned an unexpected payload for {.field {operation}}.",
    "x" = "Missing: {.field {missing_fields}}.",
    "i" = "Source: {.val {source_id}}."
  )
  if ("dataset" %in% names(payload)) {
    bullets <- c(bullets, "i" = paste(
      "It returned a study record instead, which is what this API does when an",
      "endpoint no longer exists. The endpoint has probably been renamed."
    ))
  }
  knbs_abort(bullets, class = "knbs_error_schema_changed", call = call)
}

# Operations ------------------------------------------------------------------

#' @export
source_search.knbs_source_nada <- function(source, query, ...) {
  check_operation(source, "search_surveys")
  check_source_verified(source)
  check_supported_filters(query, c("search", "year_from", "year_to", "limit", "page"))

  filters <- query$filters
  params <- compact_list(list(
    sk = filters$search,
    from = filters$year_from,
    to = filters$year_to,
    ps = filters$limit,
    page = filters$page
  ))
  params <- lapply(params, as.character)

  payload <- nada_get(source, "catalog/search", params)
  nada_expect(payload, "result", source$source_id, "search_surveys")
  result <- payload$result
  nada_expect(result, c("rows", "found"), source$source_id, "search_surveys")

  rows <- result$rows
  out <- if (length(rows) == 0L) {
    empty_tibble(knbs_survey_columns())
  } else {
    standardise_nada_surveys(rows, source$source_id)
  }

  new_knbs_catalogue(
    out,
    new_knbs_metadata(
      title = paste0(source$source_name, " study catalogue"),
      resource_type = "survey",
      source_id = source$source_id,
      source_name = source$source_name,
      source_url = source$landing_page %||% source$base_url,
      producer = source$owner,
      access = "public",
      notes = paste0(
        "Matched ", json_int(result, "found"), " of ",
        json_int(result, "total"), " studies in the catalogue."
      )
    )
  )
}

#' @export
source_metadata.knbs_source_nada <- function(source, resource_id, ...) {
  check_operation(source, "survey_metadata")
  check_source_verified(source)
  check_string(resource_id, "resource_id")

  payload <- nada_get(source, paste0("catalog/", utils::URLencode(resource_id, TRUE)))
  nada_expect(payload, "dataset", source$source_id, "survey_metadata")
  dataset <- payload$dataset
  study <- dataset$metadata$study_desc

  new_knbs_survey_metadata(
    title = json_chr(dataset, "title"),
    resource_id = json_chr(dataset, "idno"),
    resource_type = "survey",
    source_id = source$source_id,
    source_name = source$source_name,
    source_url = nada_study_url(source, dataset),
    producer = json_chr(dataset, "authoring_entity"),
    release_date = json_date(dataset, "created"),
    reference_period = nada_reference_period(dataset),
    version = json_chr(study$version_statement, "version"),
    geographic_level = json_chr(dataset, "nation"),
    access = nada_access_type(json_chr(dataset, "data_access_type")),
    citation = json_chr(study$data_access$dataset_use, "cit_req"),
    notes = json_chr_vec(study$data_access$dataset_use, "disclaimer"),
    sections = study,
    variable_count = json_int(dataset, "varcount"),
    raw = dataset
  )
}

#' @export
source_files.knbs_source_nada <- function(source, resource_id, ...) {
  check_operation(source, "files")
  check_source_verified(source)
  check_string(resource_id, "resource_id")

  payload <- nada_get(
    source,
    paste0("catalog/", utils::URLencode(resource_id, TRUE), "/data_files")
  )
  nada_expect(payload, "datafiles", source$source_id, "files")

  files <- payload$datafiles
  # An absent listing is reported as `false`, not as an empty list.
  if (identical(files, FALSE) || length(files) == 0L) {
    return(empty_tibble(knbs_file_columns()))
  }
  standardise_nada_files(
    files,
    survey_id = resource_id,
    source_id = source$source_id,
    access_type = NA_character_
  )
}

#' @export
source_variables.knbs_source_nada <- function(source, resource_id, ...) {
  check_operation(source, "variables")
  check_source_verified(source)
  check_string(resource_id, "resource_id")

  payload <- nada_get(
    source,
    paste0("catalog/", utils::URLencode(resource_id, TRUE), "/variables")
  )
  nada_expect(payload, c("total", "variables"), source$source_id, "variables")

  variables <- payload$variables
  # Several studies are catalogued without variable metadata (audit F-04), so an
  # empty set is a normal answer rather than a failure.
  if (length(variables) == 0L) {
    return(empty_tibble(knbs_variable_columns()))
  }
  standardise_nada_variables(variables, survey_id = resource_id, source_id = source$source_id)
}

#' @export
source_variable_detail.knbs_source_nada <- function(source, resource_id, variable_id, ...) {
  check_operation(source, "variables")
  nada_variable_detail(source, resource_id, variable_id)
}

#' Fetch one variable's full record
#' @noRd
nada_variable_detail <- function(source, resource_id, variable_id) {
  payload <- nada_get(
    source,
    paste0(
      "catalog/", utils::URLencode(resource_id, TRUE),
      "/variables/", utils::URLencode(variable_id, TRUE)
    )
  )
  nada_expect(payload, "variable", source$source_id, "variable detail")
  payload
}

#' @export
source_health.knbs_source_nada <- function(source, ...) {
  started <- Sys.time()
  outcome <- tryCatch(
    {
      payload <- nada_get(source, "catalog/search", list(ps = "1"))
      list(
        status = "ok",
        http_status = attr(payload, "knbs_http_status") %||% NA_integer_,
        message = "Catalogue search answered."
      )
    },
    knbs_error = function(cnd) {
      list(
        status = "unavailable",
        http_status = cnd$http_status %||% NA_integer_,
        message = conditionMessage(cnd)
      )
    }
  )
  tibble::tibble(
    source_id = source$source_id,
    operation = "search_surveys",
    status = outcome$status,
    http_status = as.integer(outcome$http_status),
    response_time_ms = as.numeric(difftime(Sys.time(), started, units = "secs")) * 1000,
    checked_at = started,
    message = outcome$message
  )
}

# Helpers ---------------------------------------------------------------------

nada_study_url <- function(source, dataset) {
  landing <- source$landing_page
  if (is.null(landing)) {
    return(NA_character_)
  }
  paste0(sub("/home$", "", landing), "/catalog/", json_chr(dataset, "id"))
}

nada_reference_period <- function(dataset) {
  from <- json_chr(dataset, "year_start")
  to <- json_chr(dataset, "year_end")
  if (is.na(from) && is.na(to)) {
    return(NA_character_)
  }
  if (identical(from, to) || is.na(to)) from else paste0(from, " to ", to)
}
