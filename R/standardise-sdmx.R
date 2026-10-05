# SDMX observation standardisation --------------------------------------------
#
# Turns a parsed JSON-stat dataflow from the SDMX hub into the observation
# schema. The payload's own `role` field names the time and geography
# dimensions, so neither is guessed from labels. Where a role is empty the
# SDMX cross-domain concepts stand in - TIME_PERIOD for time, REF_AREA for the
# reference area - because their meaning is fixed by the standard, not
# inferred (audit F-37: by 2026-10-05 the hub had stopped declaring the geo
# role it declared in August).
#
# Every other varying dimension becomes `<id>` (its labels) and `<id>_code`,
# named by the dimension's SDMX id in lower case (`na_indic`, `commodity`).
# The ids, not the labels, because the hub labels ten different
# dimensions just "Indicator", and some labels are wrong outright. A Sex
# dimension becomes `sex`, lower-cased like the census tables'.

#' Classify SDMX time codes into the package's period convention
#'
#' Annual codes become integer years; monthly and quarterly codes become
#' first-of-period Dates (open decision 8's convention). A mixed or
#' unrecognised set keeps `NA` periods with the raw codes in `period_label`,
#' which is honest and still filterable by eye.
#'
#' @return list(period = vector, frequency = string or NA)
#' @noRd
sdmx_periods <- function(codes) {
  if (all(grepl("^[0-9]{4}$", codes))) {
    return(list(period = as.integer(codes), frequency = "annual"))
  }
  if (all(grepl("^[0-9]{4}-(0[1-9]|1[0-2])$", codes))) {
    return(list(period = as.Date(paste0(codes, "-01")), frequency = "monthly"))
  }
  if (all(grepl("^[0-9]{4}-Q[1-4]$", codes))) {
    quarter <- as.integer(substr(codes, 7, 7))
    return(list(
      period = as.Date(paste0(substr(codes, 1, 4), "-",
                              sprintf("%02d", (quarter - 1L) * 3L + 1L), "-01")),
      frequency = "quarterly"
    ))
  }
  list(period = rep(NA_integer_, length(codes)), frequency = NA_character_)
}

#' Standardise a parsed hub dataflow into observations
#'
#' @param parsed The result of `parse_jsonstat()`.
#' @param indicator_id The dataflow id.
#' @param source_id Source id.
#' @param roles The payload's `role` entry: time and geo dimension ids.
#' @return list(table, unit, frequency, fixed) — `fixed` describes
#'   single-category dimensions that were folded into metadata rather than
#'   emitted as constant columns.
#' @noRd
standardise_sdmx_obs <- function(parsed, indicator_id, source_id, roles,
                                 call = rlang::caller_env()) {
  table <- parsed$table
  meta <- parsed$meta
  dim_ids <- names(meta$dimension_labels)

  time_dim <- intersect(roles$time, dim_ids)
  if (length(time_dim) != 1L) {
    time_dim <- intersect("TIME_PERIOD", dim_ids)
  }
  if (length(time_dim) != 1L) {
    knbs_abort(
      c("The dataflow declares no time dimension; please report it."),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  geo_dim <- intersect(roles$geo, dim_ids)
  if (length(geo_dim) != 1L) {
    geo_dim <- intersect("REF_AREA", dim_ids)
  }

  time_codes <- as.character(table[[time_dim]])
  periods <- sdmx_periods(unique(time_codes))
  period_for <- stats::setNames(periods$period, unique(time_codes))

  out <- tibble::tibble(
    indicator_id = rep(indicator_id, nrow(table)),
    indicator_name = rep(meta$label %||% NA_character_, nrow(table)),
    period = unname(period_for[time_codes]),
    period_label = time_codes,
    value = table$value
  )

  if (length(geo_dim) == 1L) {
    out$geo_code <- as.character(table[[geo_dim]])
    out$geo_name <- table[[paste0(geo_dim, "_label")]]
    # SDMX area codes, not census territories: the level is not knowable from
    # the code, and is not guessed.
    out$geo_level <- NA_character_
  }

  # Dimensions with a single category are facts about the whole dataflow, not
  # per-row information; they go to metadata rather than constant columns.
  sizes <- vapply(dim_ids, function(d) length(unique(table[[d]])), integer(1))
  fixed_dims <- setdiff(dim_ids[sizes == 1L], c(time_dim, geo_dim))
  varying <- setdiff(dim_ids[sizes > 1L], c(time_dim, geo_dim))

  sex_dim <- intersect("SEX", varying)
  if (length(sex_dim) == 1L) {
    out$sex <- tolower(table[[paste0(sex_dim, "_label")]])
  }
  varying <- setdiff(varying, sex_dim)
  dim_names <- dimension_column_names(tolower(varying))
  for (i in seq_along(varying)) {
    out[[dim_names[[i]]]] <- table[[paste0(varying[[i]], "_label")]]
    out[[paste0(dim_names[[i]], "_code")]] <- as.character(table[[varying[[i]]]])
  }
  if ("status" %in% names(table)) {
    out$observation_status <- table$status
  }
  out$source_id <- rep(source_id, nrow(out))

  fixed <- vapply(fixed_dims, function(d) {
    paste0(meta$dimension_labels[[d]], " = ", table[[paste0(d, "_label")]][[1]])
  }, character(1))

  unit_dim <- dim_ids[toupper(dim_ids) == "UNIT_MEASURE"]
  unit <- if (length(unit_dim) == 1L && sizes[[unit_dim]] == 1L) {
    as.character(table[[paste0(unit_dim, "_label")]][[1]])
  } else {
    NA_character_
  }

  key_cols <- c("period_label", if (length(geo_dim) == 1L) "geo_code",
                if (length(sex_dim) == 1L) "sex", dimension_code_columns(dim_names))
  keys <- do.call(paste, c(out[key_cols], sep = "\r"))
  if (anyDuplicated(keys) > 0L) {
    knbs_abort(
      c("The standardised observations contain duplicate keys.",
        "x" = "Key columns: {.field {key_cols}}.",
        "i" = "This means the dataflow changed shape; please report it."),
      class = "knbs_error_validation_failed",
      call = call
    )
  }

  ord <- do.call(order, out[c(setdiff(key_cols, "period_label"), "period_label")])
  list(
    table = out[ord, ],
    unit = unit,
    frequency = periods$frequency,
    fixed = unname(fixed)
  )
}
