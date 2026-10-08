# DHS Program adapter --------------------------------------------------------------
#
# Talks to the DHS Program's Indicator Data API, which publishes the Kenya
# Demographic and Health Surveys (1989-2022) and the Kenya Malaria Indicator
# Surveys as aggregate indicators. KNBS implements the KDHS; the DHS Program
# (ICF) computes and publishes the indicators. Traced 2026-10-08 (audit F-42).
#
# Behaviours that shape this adapter:
#
#   - robots.txt disallows /rest/dhs/ to every user agent, while the API's own
#     documentation offers it to "all users" for building applications and
#     asks only for a citation. The rule is read as addressed to crawlers: the
#     adapter requests only what a user asks for, one indicator at a time,
#     under the package's own User-Agent, throttled and cached. It never walks
#     the API.
#   - An unknown indicator id answers 200 with zero records, not a 404.
#   - The indicator listing repeats 27 ids, each under two different labels.
#   - Region rows nest the 47 counties under the former provinces, marked by a
#     ".." prefix. A survey's deepest LevelRank is its county level, which is
#     how Nairobi, both a province and a county, is placed.
#   - Values for alternative reference periods share a survey and group; the
#     API marks one of them preferred.

#' The country every request is for
#' @noRd
dhs_country <- function() "KE"

#' The citation the API's terms of use ask for
#'
#' Read from the terms page and the `info` endpoint, 2026-10-08. The access
#' date the terms append is the retrieval date every knbsdata citation ends
#' with.
#'
#' @noRd
dhs_citation <- function() {
  paste(
    "The DHS Program Indicator Data API, The Demographic and Health Surveys",
    "(DHS) Program. ICF. Originally funded by the United States Agency for",
    "International Development (USAID). Available from api.dhsprogram.com."
  )
}

#' An API GET
#'
#' The adapter's single network entry point, mocked in tests.
#' @noRd
dhs_get <- function(source, path, query = list(), call = rlang::caller_env()) {
  req <- knbs_request(paste0(sub("/+$", "", source$base_url), "/", path), throttle = 2)
  req <- httr2::req_url_query(req, !!!c(query, list(f = "json")))
  resp <- knbs_perform(req, source_id = source$source_id, expect = "json", call = call)
  payload <- parse_json_response(resp, source_id = source$source_id, call = call)
  if (!is.list(payload) || !is.list(payload$Data) || is.null(payload$TotalPages)) {
    knbs_abort(
      c(
        "The DHS Program API changed the shape of its answers; please report it.",
        "i" = "Expected an object carrying {.field Data} and {.field TotalPages}."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  payload
}

#' Every record of a listing, page by page
#' @noRd
dhs_all <- function(source, path, query = list(), call = rlang::caller_env()) {
  records <- list()
  page <- 1L
  repeat {
    payload <- dhs_get(source, path, c(query, list(perpage = 5000L, page = page)),
                       call = call)
    records <- c(records, payload$Data)
    total <- suppressWarnings(as.integer(payload$TotalPages))
    if (is.na(total) || page >= total) {
      return(records)
    }
    page <- page + 1L
    if (page > 20L) {
      knbs_abort(
        c(
          "The DHS Program API did not finish paging within 20 pages; please report it.",
          "i" = "Returning part of a result silently is not an option."
        ),
        class = "knbs_error_schema_changed",
        call = call
      )
    }
  }
}

#' One character field from every record
#' @noRd
dhs_field <- function(records, field) {
  vapply(records, json_chr, character(1), field = field)
}

#' The indicator listing as the catalogue schema
#'
#' The listing repeats some ids under a second label (audit F-42); the first
#' listed is kept, and the indicator's metadata names both.
#'
#' @noRd
dhs_catalogue <- function(source, call = rlang::caller_env()) {
  records <- dhs_all(
    source, "indicators",
    list(countryIds = dhs_country(),
         returnFields = "IndicatorId,Label,Level1,MeasurementType"),
    call = call
  )
  ids <- dhs_field(records, "IndicatorId")
  if (length(records) == 0L || anyNA(ids)) {
    knbs_abort(
      c(
        "The DHS Program's indicator listing changed shape; please report it.",
        "i" = "Expected records carrying {.field IndicatorId} and {.field Label}."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  first <- !duplicated(ids)
  records <- records[first]
  tibble::tibble(
    indicator_id = ids[first],
    indicator_name = dhs_field(records, "Label"),
    topic = dhs_field(records, "Level1"),
    frequency = NA_character_,
    unit = tolower(dhs_field(records, "MeasurementType")),
    source_id = source$source_id
  )
}

#' One indicator's own records in the listing
#' @noRd
dhs_indicator <- function(source, indicator_id, call = rlang::caller_env()) {
  records <- dhs_all(
    source, "indicators",
    list(countryIds = dhs_country(), indicatorIds = indicator_id),
    call = call
  )
  if (length(records) == 0L) {
    knbs_abort(
      c(
        "The DHS Program lists no indicator {.val {indicator_id}} for Kenya.",
        "i" = "List what exists with {.code knbs_indicators(source = \"{source$source_id}\")}."
      ),
      class = "knbs_error_resource_not_found",
      call = call
    )
  }
  records
}

#' Kenya's surveys, for who implemented each
#' @noRd
dhs_surveys <- function(source, call = rlang::caller_env()) {
  records <- dhs_all(source, "surveys", list(countryIds = dhs_country()), call = call)
  tibble::tibble(
    survey_code = dhs_field(records, "SurveyId"),
    implementer = trimws(dhs_field(records, "ImplementingOrg")),
    release_date = as.Date(substr(dhs_field(records, "ReleaseDate"), 1L, 10L))
  )
}

#' Notes describing an indicator: definition, denominator, and any second label
#' @noRd
dhs_indicator_notes <- function(meta) {
  labels <- unique(dhs_field(meta, "Label"))
  definition <- json_chr(meta[[1]], "Definition")
  denominator <- json_chr(meta[[1]], "Denominator")
  c(
    if (!is.na(definition)) paste0("Definition: ", definition, "."),
    if (!is.na(denominator)) paste0("Denominator: ", denominator, "."),
    if (length(labels) > 1L) {
      paste0(
        "The DHS Program lists this indicator id under ", length(labels),
        " labels: ", paste(labels, collapse = "; "),
        ". Its values are reported here as the API serves them."
      )
    }
  )
}

#' @export
source_search.knbs_source_dhs <- function(source, query, ...) {
  check_operation(source, "list_indicators")
  check_source_verified(source)
  check_supported_filters(query, c("search", "topic"))

  out <- dhs_catalogue(source)
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
      title = "DHS Program indicators for Kenya",
      resource_type = "indicator",
      source_id = source$source_id,
      source_name = source$source_name,
      source_url = source$landing_page %||% source$base_url,
      producer = source$owner,
      licence = "Not stated by the source; its terms ask that the API be cited",
      access = "open",
      citation = dhs_citation()
    )
  )
}

#' @export
source_fetch.knbs_source_dhs <- function(source, query, ...) {
  check_operation(source, "get_indicator")
  check_source_verified(source)
  check_supported_filters(query, c("geo_level", "geo_code"))

  indicator_id <- query$resource_id %||% ""
  meta <- dhs_indicator(source, indicator_id)
  records <- dhs_all(
    source, "data",
    list(countryIds = dhs_country(), indicatorIds = indicator_id, breakdown = "all")
  )
  surveys <- dhs_surveys(source)
  indicator_name <- json_chr(meta[[1]], "Label")
  out <- standardise_dhs_obs(records, indicator_id, indicator_name, source$source_id)

  filters <- query$filters
  if (!is.null(filters$geo_level)) {
    out$table <- out$table[out$table$geo_level %in% as.character(filters$geo_level), ]
  }
  if (!is.null(filters$geo_code)) {
    out$table <- out$table[!is.na(out$table$geo_code) &
                             out$table$geo_code %in% as.character(filters$geo_code), ]
  }

  table <- out$table
  used <- surveys[surveys$survey_code %in% unique(table$survey_code), ]
  new_knbs_data(
    table,
    new_knbs_metadata(
      title = indicator_name,
      resource_id = indicator_id,
      resource_type = "indicator",
      source_id = source$source_id,
      source_name = source$source_name,
      source_url = source$landing_page %||% source$base_url,
      producer = source$owner,
      release_date = if (nrow(used) > 0L) max(used$release_date, na.rm = TRUE) else NULL,
      reference_period = if (nrow(table) > 0L) {
        paste(table$period_label[which.min(table$period)], "to",
              table$period_label[which.max(table$period)])
      } else {
        NULL
      },
      unit = tolower(json_chr(meta[[1]], "MeasurementType")),
      licence = "Not stated by the source; its terms ask that the API be cited",
      access = "open",
      citation = dhs_citation(),
      notes = c(
        dhs_indicator_notes(meta),
        if (nrow(used) > 0L) {
          paste0("Surveys implemented by: ",
                 paste0(used$survey_code, " - ", used$implementer, collapse = "; "), ".")
        },
        out$notes
      )
    ),
    class = "knbs_indicator"
  )
}

#' @export
source_metadata.knbs_source_dhs <- function(source, resource_id, ...) {
  check_operation(source, "indicator_metadata")
  check_source_verified(source)
  check_string(resource_id, "resource_id")

  meta <- dhs_indicator(source, resource_id)
  levels <- c(json_chr(meta[[1]], "Level1"), json_chr(meta[[1]], "Level2"),
              json_chr(meta[[1]], "Level3"))
  new_knbs_metadata(
    title = json_chr(meta[[1]], "Label"),
    resource_id = resource_id,
    resource_type = "indicator",
    source_id = source$source_id,
    source_name = source$source_name,
    source_url = source$landing_page %||% source$base_url,
    producer = source$owner,
    unit = tolower(json_chr(meta[[1]], "MeasurementType")),
    licence = "Not stated by the source; its terms ask that the API be cited",
    access = "open",
    citation = dhs_citation(),
    notes = c(
      dhs_indicator_notes(meta),
      paste0("Topic: ", paste(levels[!is.na(levels)], collapse = " > "), ".")
    )
  )
}

#' @export
source_health.knbs_source_dhs <- function(source, ...) {
  started <- Sys.time()
  outcome <- tryCatch(
    {
      payload <- dhs_get(source, "info", list(infoType = "version"))
      version <- if (length(payload$Data) > 0L) json_chr(payload$Data[[1]], "Value") else NA
      list(status = "ok",
           message = paste0("API answered; version ",
                            if (is.na(version)) "unknown" else version, "."))
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
