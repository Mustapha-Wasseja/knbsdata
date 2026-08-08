# Indicator standardisation ---------------------------------------------------
#
# Translates the census API's JSON-stat output into the package's observation
# schema (plan section 9.2, strategy: stable core columns plus the source's own
# dimensions, documented rather than guessed at).

knbs_indicator_list_columns <- function() {
  c("indicator_id", "indicator_name", "topic", "frequency", "unit", "source_id")
}

#' Core observation columns; source dimensions follow them
#' @noRd
knbs_observation_core_columns <- function() {
  c("indicator_id", "indicator_name", "period", "value")
}

#' Standardise the themed dataset list into the indicator catalogue schema
#'
#' @param themes Parsed getDatasetList payload: a list of themes, each with
#'   `desc` and `datasets`.
#' @noRd
standardise_census_catalogue <- function(themes, source_id) {
  rows <- list()
  for (theme in themes) {
    topic <- json_chr(theme, "desc")
    for (dataset in theme$datasets) {
      rows[[length(rows) + 1L]] <- tibble::tibble(
        indicator_id = json_chr(dataset, "id"),
        indicator_name = json_chr(dataset, "desc"),
        topic = topic,
        # A census table is not a recurring series; claiming a frequency or a
        # unit for it would be invention (plan section 29.5).
        frequency = NA_character_,
        unit = NA_character_,
        source_id = source_id
      )
    }
  }
  if (length(rows) == 0L) {
    return(empty_tibble(knbs_indicator_list_columns()))
  }
  do.call(rbind, rows)
}

#' Standardise a parsed JSON-stat census table into observations
#'
#' The Territory dimension becomes `geo_code`, `geo_name` and `geo_level`; a
#' dimension labelled Sex becomes `sex`; every other dimension keeps its source
#' id as a pair of columns, `<dim_id>` (code) and `<dim_id>_label`.
#'
#' @param parsed The result of [parse_jsonstat()].
#' @param indicator_id Dataset id the observations belong to.
#' @param source_id Source id.
#' @noRd
standardise_census_obs <- function(parsed, indicator_id, source_id,
                                   call = rlang::caller_env()) {
  table <- parsed$table
  meta <- parsed$meta
  dim_ids <- names(meta$dimension_labels)

  # The reference year is read from the source statement ("KNBS Population
  # Census 2019"), not assumed.
  year <- regmatches(meta$source %||% "", regexpr("(19|20)[0-9]{2}", meta$source %||% ""))
  period <- if (length(year) == 1L) as.integer(year) else NA_integer_

  out <- tibble::tibble(
    indicator_id = rep(indicator_id, nrow(table)),
    indicator_name = rep(meta$label %||% NA_character_, nrow(table)),
    period = rep(period, nrow(table)),
    value = table$value
  )

  geo_dim <- dim_ids[tolower(meta$dimension_labels) %in% c("territory", "geography", "area")]
  sex_dim <- dim_ids[tolower(meta$dimension_labels) == "sex"]

  if (length(geo_dim) == 1L) {
    codes <- as.character(table[[geo_dim]])
    out$geo_code <- codes
    out$geo_name <- table[[paste0(geo_dim, "_label")]]
    out$geo_level <- census_geo_level(codes)
  }
  if (length(sex_dim) == 1L) {
    out$sex <- tolower(table[[paste0(sex_dim, "_label")]])
  }

  for (d in setdiff(dim_ids, c(geo_dim, sex_dim))) {
    out[[d]] <- table[[d]]
    out[[paste0(d, "_label")]] <- table[[paste0(d, "_label")]]
  }

  if ("status" %in% names(table)) {
    out$observation_status <- table$status
  }
  out$release_date <- rep(meta$updated %||% as.Date(NA), nrow(out))
  out$source_id <- rep(source_id, nrow(out))

  validate_census_observations(out, dim_ids, geo_dim, sex_dim, call = call)
  out
}

#' Geographic level from the census territory code
#'
#' Observed coding (audit F-20): `00` is Kenya, two digits are counties,
#' four digits are sub-counties. Anything else is reported as `NA` rather
#' than guessed.
#'
#' @noRd
census_geo_level <- function(codes) {
  level <- rep(NA_character_, length(codes))
  level[codes == "00"] <- "national"
  level[nchar(codes) == 2L & codes != "00"] <- "county"
  level[nchar(codes) == 4L] <- "subcounty"
  level
}

#' Refuse observations that violate the schema's own promises
#' @noRd
validate_census_observations <- function(out, dim_ids, geo_dim, sex_dim,
                                         call = rlang::caller_env()) {
  if (!is.numeric(out$value)) {
    knbs_abort("Observation values are not numeric.",
               class = "knbs_error_validation_failed", call = call)
  }
  if ("geo_code" %in% names(out) && !is.character(out$geo_code)) {
    knbs_abort("Geographic codes must be character.",
               class = "knbs_error_validation_failed", call = call)
  }

  key_columns <- c(
    if (length(geo_dim) == 1L) "geo_code",
    if (length(sex_dim) == 1L) "sex",
    setdiff(dim_ids, c(geo_dim, sex_dim))
  )
  key_columns <- intersect(key_columns, names(out))
  if (length(key_columns) > 0L) {
    keys <- do.call(paste, c(out[key_columns], sep = "\r"))
    if (anyDuplicated(keys) > 0L) {
      knbs_abort(
        c(
          "The standardised observations contain duplicate keys.",
          "x" = "Key columns: {.field {key_columns}}.",
          "i" = "This means the source's dimensions changed shape; please report it."
        ),
        class = "knbs_error_validation_failed",
        call = call
      )
    }
  }
  invisible(out)
}
