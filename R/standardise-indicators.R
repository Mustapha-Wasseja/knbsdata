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

#' Column names no source dimension may take
#' @noRd
knbs_reserved_columns <- function() {
  c(knbs_observation_core_columns(), "period_label", "geo_code", "geo_name",
    "geo_level", "sex", "observation_status", "release_date", "unit", "scale",
    "source_id")
}

#' Column names for an indicator's dimensions
#'
#' Every source dimension becomes a pair of columns: `<name>` holding each
#' category's label and `<name>_code` holding the source's own code - the
#' pattern `geo_name`/`geo_code` already follows. Names are snake_case. One
#' that would take a core column's name is prefixed `dim_`, and repeats are
#' numbered, rather than anything being overwritten.
#'
#' @param names Candidate names, one per dimension.
#' @return Safe names, in the same order.
#' @noRd
dimension_column_names <- function(names) {
  out <- tolower(gsub("[^A-Za-z0-9]+", "_", as.character(names)))
  out <- gsub("^_+|_+$", "", out)
  out[!nzchar(out)] <- "dimension"
  reserved <- knbs_reserved_columns()
  clash <- out %in% reserved | paste0(out, "_code") %in% reserved
  out[clash] <- paste0("dim_", out[clash])
  make.unique(out, sep = "_")
}

#' The code column of each named dimension; none for none
#'
#' `paste0()` would turn zero names into one stray `"_code"`.
#' @noRd
dimension_code_columns <- function(names) {
  if (length(names) == 0L) {
    return(character(0))
  }
  paste0(names, "_code")
}

#' Short, readable column names for the census dimensions
#'
#' The census API names its dimensions by questionnaire variable (`p18_vs1`)
#' and labels them in long prose, sometimes misspelt ("If has Aalbinism",
#' "Bougth or ordered goods or services online in the last 3 months").
#' Neither makes a usable column name, so each dimension the 2019 tables
#' carry has a curated one (inventory of 2026-10-05). A dimension missing from
#' this list keeps its source id as its name, never a guess.
#'
#' Territory and Sex are handled before this list is consulted.
#'
#' @noRd
census_dimension_names <- function() {
  c(
    p10_vs3 = "relationship_to_head",
    p12_vs3 = "age",
    p17_vs1 = "religion",
    p18_vs1 = "marital_status",
    p42_1_vs3 = "difficulty_seeing",
    p42_2_vs3 = "difficulty_hearing",
    p42_3_vs3 = "difficulty_mobility",
    p42_4_vs3 = "difficulty_cognition",
    p42_5_vs3 = "difficulty_selfcare",
    p42_6_vs3 = "difficulty_communication",
    p43_vs2 = "albinism",
    p44_vs1 = "disability_limits_economic_activity",
    p45_vs1 = "schooling_status",
    p46_vs12 = "highest_level_reached",
    p47_vs16 = "highest_level_completed",
    p49_vs2 = "activity_last_7_days",
    p49_vs5 = "labour_force_status",
    p54_vs1 = "working_in_field_of_training",
    p57_vs1 = "internet_use",
    p58_vs1 = "computer_use",
    p59_vs2 = "online_shopping",
    h19_1_vs1 = "crop_farming",
    h19_2_vs1 = "livestock_rearing",
    h19_3_vs1 = "aquaculture",
    h20_vs1 = "agricultural_production_purpose",
    h22_vs1 = "irrigation",
    h24_14_vs1 = "onion_farming",
    sex_hh_head_vs1 = "household_head_sex",
    educ_comp_hh_head_vs1 = "household_head_education"
  )
}

#' The census dimension that mixes single years with age groups
#' @noRd
census_age_dimension <- function() "p12_vs3"

#' Classify census age codes
#'
#' The age table carries a total (`T`), single years (`"0"` to `"99"`),
#' age groups (`"0-4"` to `"95-99"`, and `"100-120"`), and an unreported
#' category. Single years and groups overlap, so summing across both double
#' counts; `age_type` lets a caller keep one or the other.
#'
#' @noRd
census_age_type <- function(codes) {
  type <- rep("other", length(codes))
  type[codes == "T"] <- "total"
  type[grepl("^[0-9]+$", codes)] <- "single_year"
  type[grepl("^[0-9]+-[0-9]+$", codes)] <- "age_group"
  type
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

#' The name a census table goes by
#'
#' The census API gives every table the same JSON-stat label, "Census 2019 -
#' Population by sex and marital status" (observed 2026-10-05 on POPCEN0002,
#' POPCEN0003 and POPCEN0004), so a payload's label cannot say which table it
#' holds. The dataset list names each table correctly, and its name wins
#' whenever there is one. The source's label is never dropped: where it is not
#' the title, a note records it.
#'
#' @param label The payload's own `label`.
#' @param catalogue_name The dataset list's name for the table, or `NA`.
#' @return A list: `name`, and `note` (`NULL` when there is nothing to add).
#' @noRd
census_table_name <- function(label, catalogue_name) {
  if (is.na(catalogue_name)) {
    return(list(
      name = label,
      note = paste(
        "Titled with the source's own table label, which the census API repeats",
        "across tables; the dataset list gave no name for this one."
      )
    ))
  }
  list(
    name = catalogue_name,
    note = if (!is.na(label) && !identical(label, catalogue_name)) {
      paste0(
        "The source labels this table \"", label, "\"; the title is the name ",
        "its dataset list gives."
      )
    }
  )
}

#' Standardise a parsed JSON-stat census table into observations
#'
#' The Territory dimension becomes `geo_code`, `geo_name` and `geo_level`; a
#' dimension labelled Sex becomes `sex`; every other dimension becomes a pair
#' of columns under its curated name (see `census_dimension_names()`):
#' `<name>` (the label) and `<name>_code`. The age dimension also gets
#' `age_type`, and its groups are checked against its single years and total.
#'
#' @param parsed The result of `parse_jsonstat()`.
#' @param indicator_id Dataset id the observations belong to.
#' @param source_id Source id.
#' @param indicator_name The table's name; see `census_table_name()`. Defaults
#'   to the payload's own label.
#' @noRd
standardise_census_obs <- function(parsed, indicator_id, source_id,
                                   indicator_name = parsed$meta$label,
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
    indicator_name = rep(indicator_name %||% NA_character_, nrow(table)),
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

  other_dims <- setdiff(dim_ids, c(geo_dim, sex_dim))
  curated <- census_dimension_names()
  dim_names <- dimension_column_names(
    ifelse(other_dims %in% names(curated), unname(curated[other_dims]), other_dims)
  )
  age_name <- NULL
  for (i in seq_along(other_dims)) {
    d <- other_dims[[i]]
    name <- dim_names[[i]]
    out[[name]] <- table[[paste0(d, "_label")]]
    out[[paste0(name, "_code")]] <- as.character(table[[d]])
    if (identical(d, census_age_dimension())) {
      age_name <- name
      out[[paste0(name, "_type")]] <- census_age_type(out[[paste0(name, "_code")]])
    }
  }

  if ("status" %in% names(table)) {
    out$observation_status <- table$status
  }
  out$release_date <- rep(meta$updated %||% as.Date(NA), nrow(out))
  out$source_id <- rep(source_id, nrow(out))

  key_columns <- c(
    if (length(geo_dim) == 1L) "geo_code",
    if (length(sex_dim) == 1L) "sex",
    dimension_code_columns(dim_names)
  )
  validate_census_observations(out, key_columns, call = call)
  if (!is.null(age_name)) {
    validate_census_ages(out, age_name, setdiff(key_columns, paste0(age_name, "_code")),
                         call = call)
  }
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
validate_census_observations <- function(out, key_columns,
                                         call = rlang::caller_env()) {
  if (!is.numeric(out$value)) {
    knbs_abort("Observation values are not numeric.",
               class = "knbs_error_validation_failed", call = call)
  }
  if ("geo_code" %in% names(out) && !is.character(out$geo_code)) {
    knbs_abort("Geographic codes must be character.",
               class = "knbs_error_validation_failed", call = call)
  }

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

#' Check that the age groups are what `age_type` says they are
#'
#' Within every cell of the other dimensions (territory, sex, ...), the age
#' groups must add up to the total and each group's single years to the
#' group - verified to hold exactly across the whole 2019 table on
#' 2026-10-05. A cell with a missing figure among those compared is skipped
#' rather than judged. A mismatch means the codes no longer carry the meaning
#' `age_type` assigns them, so the table is refused.
#'
#' @noRd
validate_census_ages <- function(out, age_name, cell_columns,
                                 call = rlang::caller_env()) {
  codes <- out[[paste0(age_name, "_code")]]
  type <- out[[paste0(age_name, "_type")]]
  cell <- if (length(cell_columns) > 0L) {
    do.call(paste, c(out[cell_columns], sep = "\r"))
  } else {
    rep("", nrow(out))
  }

  # Each single year's group, read from the group codes themselves.
  groups <- unique(codes[type == "age_group"])
  lower <- as.integer(sub("-.*$", "", groups))
  upper <- as.integer(sub("^.*-", "", groups))
  years <- suppressWarnings(as.integer(codes))
  group_of <- rep(NA_character_, length(codes))
  for (g in seq_along(groups)) {
    hit <- type == "single_year" & years >= lower[[g]] & years <= upper[[g]]
    group_of[hit] <- groups[[g]]
  }

  # Sums keyed by cell and parent, kept only when every figure is present.
  complete_sum <- function(rows, key) {
    v <- out$value[rows]
    k <- key[rows]
    sums <- tapply(v, k, sum)
    sums[!is.na(sums)]
  }
  value_at <- function(rows, key) {
    stats::setNames(out$value[rows], key[rows])
  }
  compare <- function(parts, totals) {
    common <- intersect(names(parts), names(totals))
    gap <- totals[common] - parts[common]
    sum(!is.na(gap) & abs(gap) > 0.5)
  }

  bad_groups <- compare(
    complete_sum(type == "age_group", cell),
    value_at(type == "total", cell)
  )
  group_key <- paste(cell, ifelse(type == "age_group", codes, group_of), sep = "\r")
  bad_years <- compare(
    complete_sum(type == "single_year" & !is.na(group_of), group_key),
    value_at(type == "age_group", group_key)
  )

  if (bad_groups + bad_years > 0L) {
    knbs_abort(
      c(
        "The census age groups no longer add up as their codes say.",
        "x" = "Totals not matching their groups: {bad_groups}. Groups not matching their single years: {bad_years}.",
        "i" = "The source's age coding has changed; please report it."
      ),
      class = "knbs_error_validation_failed",
      call = call
    )
  }
  invisible(out)
}
