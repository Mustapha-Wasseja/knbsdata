# Census indicators adapter ---------------------------------------------------
#
# Talks to the KNBS Census Data API behind data.knbs.or.ke, verified 2026-08-08
# (audit section 1b). Four behaviours of that API shape the code:
#
#   F-17  An unknown dataset id answers 200 with the six-byte body "errore".
#         That is a missing resource wearing a success status.
#   F-18  JSON arrives with Content-Type text/html, so responses are verified
#         by shape, never by type.
#   F-19  getDatasetList requires a lang parameter and ignores its value.
#
#   And, found in live testing on 2026-10-05: every table's JSON-stat label
#   reads "Census 2019 - Population by sex and marital status", whatever the
#   table holds. Tables are named from the dataset list instead, keeping the
#   source's label in the notes (census_table_name()).

#' A census API request
#'
#' The single network entry point for this adapter, mocked wholesale in tests.
#'
#' @return Parsed JSON.
#' @noRd
indicators_get <- function(source, path, query = list(), call = rlang::caller_env()) {
  req <- knbs_request(paste0(sub("/+$", "", source$base_url), "/", path), throttle = 2)
  if (length(query) > 0L) {
    req <- httr2::req_url_query(req, !!!query)
  }
  # expect is deliberately NULL: the server misdeclares JSON as text/html.
  resp <- knbs_perform(req, source_id = source$source_id, call = call)

  body <- httr2::resp_body_string(resp)
  if (identical(trimws(body), "errore")) {
    knbs_abort(
      c(
        "The source has no dataset with that identifier.",
        "i" = "List what exists with {.fn knbs_indicators}."
      ),
      class = "knbs_error_resource_not_found",
      call = call
    )
  }
  parse_json(body, source_id = source$source_id, call = call)
}

#' The dataset list as the indicator-catalogue schema
#' @noRd
census_catalogue <- function(source, call = rlang::caller_env()) {
  payload <- indicators_get(source, "getDatasetList", list(lang = "en"), call = call)
  # A theme with no datasets omits the key entirely rather than sending an
  # empty array (observed live: the Household Assets/Amenities theme), so a
  # theme is acceptable if it carries datasets OR is at least identifiably a
  # theme (id and desc).
  theme_ok <- function(t) {
    is.list(t) && ("datasets" %in% names(t) || all(c("id", "desc") %in% names(t)))
  }
  if (!is.list(payload) || length(payload) == 0L ||
      !all(vapply(payload, theme_ok, logical(1)))) {
    knbs_abort(
      c(
        "The source returned an unexpected payload for {.field list_indicators}.",
        "i" = "Expected a list of themes carrying {.field datasets}.",
        "i" = "The endpoint has probably changed; please report it."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  standardise_census_catalogue(payload, source$source_id)
}

#' The dataset list's name for one census table
#'
#' Used when no caller passed the name on (a direct adapter call); the public
#' path resolves the id against the catalogue first and hands its name over.
#' The name only labels the table, so a dataset list that cannot be read is
#' reported and leaves it `NA` rather than losing the observations.
#'
#' @noRd
census_catalogue_name <- function(source, resource_id) {
  catalogue <- tryCatch(
    census_catalogue(source),
    knbs_error = function(cnd) {
      knbs_warn(
        c(
          "Could not read the dataset list, so the table keeps the source's own label.",
          "i" = "The census API repeats one label across tables; rely on {.field indicator_id}.",
          "i" = "{conditionMessage(cnd)}"
        ),
        class = "knbs_warning_missing_metadata"
      )
      NULL
    }
  )
  name <- catalogue$indicator_name[catalogue$indicator_id == resource_id]
  if (length(name) == 1L) name else NA_character_
}

#' @export
source_search.knbs_source_indicators <- function(source, query, ...) {
  check_operation(source, "list_indicators")
  check_source_verified(source)
  check_supported_filters(query, c("search", "topic"))

  out <- census_catalogue(source)

  filters <- query$filters
  if (!is.null(filters$topic)) {
    out <- out[tolower(out$topic) %in% tolower(as.character(filters$topic)), ]
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
      licence = "CC BY 4.0 (stated on the portal)",
      access = "open"
    )
  )
}

# `catalogue_name` is the dataset list's name for the table when the caller
# already has it; otherwise it is looked up. See census_table_name().
#' @export
source_fetch.knbs_source_indicators <- function(source, query, ..., catalogue_name = NULL) {
  check_operation(source, "get_indicator")
  check_source_verified(source)
  check_supported_filters(query, c("geo_level", "geo_code"))

  resource_id <- query$resource_id
  if (is.null(resource_id)) {
    knbs_abort(
      c("A dataset id is required.", "i" = "Find one with {.fn knbs_indicators}."),
      class = "knbs_error_invalid_query"
    )
  }

  payload <- indicators_get(
    source, "getDataset",
    list(id = resource_id, type = "jsonstat")
  )
  parsed <- parse_jsonstat(payload, source_id = source$source_id)
  table_name <- census_table_name(
    parsed$meta$label,
    catalogue_name %||% census_catalogue_name(source, resource_id)
  )
  out <- standardise_census_obs(parsed, resource_id, source$source_id,
                                indicator_name = table_name$name)

  filters <- query$filters
  if (!is.null(filters$geo_level) && "geo_level" %in% names(out)) {
    out <- out[out$geo_level %in% as.character(filters$geo_level), ]
  }
  if (!is.null(filters$geo_code) && "geo_code" %in% names(out)) {
    out <- out[out$geo_code %in% as.character(filters$geo_code), ]
  }

  new_knbs_data(
    out,
    new_knbs_metadata(
      title = table_name$name,
      resource_id = resource_id,
      resource_type = "indicator",
      source_id = source$source_id,
      source_name = source$source_name,
      source_url = source$landing_page %||% source$base_url,
      producer = source$owner,
      release_date = parsed$meta$updated,
      reference_period = parsed$meta$source,
      geographic_level = "national, county and sub-county",
      licence = "CC BY 4.0 (stated on the portal)",
      access = "open",
      notes = c(
        paste0(
          "Dimensions: ",
          paste(parsed$meta$dimension_labels, collapse = ", "), "."
        ),
        table_name$note
      ),
      raw = parsed$meta
    ),
    class = "knbs_indicator"
  )
}

#' @export
source_metadata.knbs_source_indicators <- function(source, resource_id, ...) {
  check_operation(source, "indicator_metadata")
  check_source_verified(source)
  check_string(resource_id, "resource_id")

  payload <- indicators_get(
    source, "getDataset",
    list(id = resource_id, type = "jsonstat")
  )
  parsed <- parse_jsonstat(payload, source_id = source$source_id)
  table_name <- census_table_name(
    parsed$meta$label,
    census_catalogue_name(source, resource_id)
  )

  new_knbs_metadata(
    title = table_name$name,
    resource_id = resource_id,
    resource_type = "indicator",
    source_id = source$source_id,
    source_name = source$source_name,
    source_url = source$landing_page %||% source$base_url,
    producer = source$owner,
    release_date = parsed$meta$updated,
    reference_period = parsed$meta$source,
    licence = "CC BY 4.0 (stated on the portal)",
    access = "open",
    notes = c(
      paste0(
        "Dimensions: ", paste(parsed$meta$dimension_labels, collapse = ", "), "."
      ),
      table_name$note
    ),
    raw = parsed$meta
  )
}

#' @export
source_health.knbs_source_indicators <- function(source, ...) {
  started <- Sys.time()
  outcome <- tryCatch(
    {
      payload <- indicators_get(source, "getDatasetList", list(lang = "en"))
      list(
        status = if (is.list(payload) && length(payload) > 0L) "ok" else "unavailable",
        message = "Dataset list answered."
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
