# DHS Program standardisation --------------------------------------------------------
#
# One row per value the API serves: per survey, per group of a background
# characteristic (Total, Region, Residence, Wealth quintile, ...), per
# reference period where an indicator has several. Geography is read from the
# Region rows (audit F-42): the former provinces (or, in the malaria indicator
# surveys, malaria zones) are geo_level "region"; the counties, from 2014 on,
# are geo_level "county" and carry census county codes.

#' Standardise data records into observations
#'
#' @param records Parsed records from the `data` endpoint.
#' @return A list: `table`, the observations; `notes`, for the metadata.
#' @noRd
standardise_dhs_obs <- function(records, indicator_id, indicator_name, source_id,
                                call = rlang::caller_env()) {
  if (length(records) == 0L) {
    return(list(table = dhs_empty_table(), notes = "The DHS Program serves no values for this indicator."))
  }

  f <- function(field) dhs_field(records, field)
  survey_code <- f("SurveyId")
  year <- suppressWarnings(as.integer(f("SurveyYear")))
  year_label <- f("SurveyYearLabel")
  survey_type <- f("SurveyType")
  category <- f("CharacteristicCategory")
  label <- f("CharacteristicLabel")
  value <- suppressWarnings(as.numeric(f("Value")))

  required <- list(SurveyId = survey_code, SurveyYear = year,
                   CharacteristicCategory = category, CharacteristicLabel = label)
  missing <- names(required)[vapply(required, anyNA, logical(1))]
  if (length(missing) > 0L) {
    knbs_abort(
      c(
        "The DHS Program's data records changed shape; please report it.",
        "x" = "Missing or empty: {.field {missing}}."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }

  level <- dhs_geo_level(survey_code, category, label, f("LevelRank"))
  name <- sub("^\\.+", "", label)
  geo_name <- ifelse(level == "national", "Kenya", name)
  geo_code <- rep(NA_character_, length(records))
  geo_code[level == "national"] <- "00"
  county <- level == "county"
  if (any(county)) {
    geo_code[county] <- dhs_county_codes(name[county])
  }

  out <- tibble::tibble(
    indicator_id = rep(indicator_id, length(records)),
    indicator_name = rep(indicator_name, length(records)),
    period = year,
    period_label = ifelse(is.na(year_label), as.character(year), year_label),
    value = value,
    geo_code = geo_code,
    geo_name = geo_name,
    geo_level = level,
    survey = paste(ifelse(is.na(year_label), year, year_label), survey_type),
    survey_code = survey_code,
    characteristic_type = category,
    characteristic = name,
    characteristic_code = f("CharacteristicId")
  )

  by_variable <- f("ByVariableLabel")
  if (any(!is.na(by_variable))) {
    out$by_variable <- by_variable
    out$by_variable_code <- f("ByVariableId")
  }
  # A record without the flag has no alternative to be preferred over.
  flag <- f("IsPreferred")
  out$preferred <- is.na(flag) | flag == "1"
  for (field in c("DenominatorWeighted", "DenominatorUnweighted", "CILow", "CIHigh")) {
    numbers <- suppressWarnings(as.numeric(f(field)))
    if (any(!is.na(numbers))) {
      out[[dhs_column_name(field)]] <- numbers
    }
  }
  out$source_id <- rep(source_id, nrow(out))

  key_cols <- c("survey_code", "geo_level", "characteristic_type", "characteristic_code",
                if ("by_variable_code" %in% names(out)) "by_variable_code")
  keys <- do.call(paste, c(out[key_cols], sep = "\r"))
  # A record served twice, value and all, is one record. Two values for one
  # survey and group are not: the API reuses some ids for two indicators
  # (audit F-42), and nothing in a record says which it belongs to.
  repeated <- duplicated(paste(keys, out$value, sep = "\r"))
  out <- out[!repeated, ]
  keys <- keys[!repeated]
  if (anyDuplicated(keys) > 0L) {
    clash <- out[keys == keys[duplicated(keys)][[1]], ]
    example <- paste0(clash$survey[[1]], ", ", clash$characteristic[[1]], ": ",
                      paste(format(clash$value, big.mark = ",", trim = TRUE), collapse = " and "))
    conflicts <- sum(duplicated(keys))
    knbs_abort(
      c(
        "The DHS Program serves conflicting values for {.val {indicator_id}}.",
        "x" = paste("{conflicts} survey-and-group combination{?s} {?has/have} more than one",
                    "value, such as {example}."),
        "i" = "The API reuses some indicator ids for two indicators, and nothing says which value is which.",
        "i" = "knbsdata does not choose between them, so returns none."
      ),
      class = "knbs_error_validation_failed",
      call = call,
      conflicts = conflicts,
      example = example
    )
  }

  out <- out[order(out$period, out$survey_code, match(out$geo_level, c("national", "region", "county")),
                   seq_len(nrow(out))), ]
  list(
    table = out,
    notes = c(
      dhs_notes(out),
      if (any(repeated)) {
        paste0(sum(repeated), " record(s) the API served twice, identically, are kept once.")
      }
    )
  )
}

#' The geographic level of each record
#'
#' Total and background-characteristic rows describe Kenya as a whole. Region
#' rows are the former provinces, or malaria zones, unless they sit at the
#' survey's county level. That is the level of its ".."-prefixed rows; with
#' none, the deeper of two levels the region rows occupy. Nairobi, a
#' province and a county at once, has an unprefixed row at the county level
#' even for an indicator published only by province (audit F-42), and this is
#' how that row is recognised.
#'
#' @noRd
dhs_geo_level <- function(survey_code, category, label, rank) {
  level <- rep("national", length(survey_code))
  region <- category %in% "Region"
  level[region] <- "region"
  prefixed <- region & startsWith(label, "..")
  for (s in unique(survey_code[region])) {
    in_survey <- region & survey_code == s
    county_rank <- if (any(prefixed & in_survey)) {
      ranks <- unique(rank[prefixed & in_survey])
      if (length(ranks) == 1L) ranks else NA_character_
    } else {
      known <- unique(rank[in_survey & !is.na(rank)])
      if (length(known) >= 2L) as.character(max(suppressWarnings(as.integer(known)))) else NA_character_
    }
    county <- if (!is.na(county_rank)) in_survey & rank %in% county_rank else prefixed & in_survey
    level[county] <- "county"
  }
  level
}

#' Census codes for county names, matched as knbs_county_code() matches them
#' @noRd
dhs_county_codes <- function(names) {
  distinct <- unique(names)
  codes <- knbs_county_code(distinct)
  unname(codes[match(names, distinct)])
}

#' Snake-case column names for the API's numeric extras
#' @noRd
dhs_column_name <- function(field) {
  c(DenominatorWeighted = "denominator_weighted",
    DenominatorUnweighted = "denominator_unweighted",
    CILow = "ci_low", CIHigh = "ci_high")[[field]]
}

#' What a reader of the table needs told
#' @noRd
dhs_notes <- function(out) {
  c(
    if (any(out$geo_level == "county")) {
      paste0(
        "County rows (2014 on) carry 2019 census county codes and join ",
        "knbs_geographies(); region rows are the former provinces, or malaria ",
        "zones in the malaria indicator surveys, and carry no code."
      )
    } else if (any(out$geo_level == "region")) {
      paste0(
        "Region rows are the former provinces, or malaria zones in the malaria ",
        "indicator surveys, and carry no code."
      )
    },
    if (!all(out$preferred)) {
      paste0(
        sum(!out$preferred), " value(s) are alternatives, for another reference ",
        "period, that the DHS Program does not mark as preferred; keep rows ",
        "where preferred is TRUE for one value per survey and group."
      )
    },
    "Background characteristics (residence, wealth, education and others) describe Kenya as a whole."
  )
}

#' The observation table with no rows
#' @noRd
dhs_empty_table <- function() {
  tibble::tibble(
    indicator_id = character(0), indicator_name = character(0),
    period = integer(0), period_label = character(0), value = numeric(0),
    geo_code = character(0), geo_name = character(0), geo_level = character(0),
    survey = character(0), survey_code = character(0),
    characteristic_type = character(0), characteristic = character(0),
    characteristic_code = character(0), preferred = logical(0),
    source_id = character(0)
  )
}
