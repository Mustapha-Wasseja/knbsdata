# Survey standardisation ------------------------------------------------------
#
# Source-specific field names are translated into the canonical schemas here, so
# that adapters stay thin and the schemas have one definition (plan section 17).

#' Canonical access types
#'
#' The vocabulary is deliberately about *how* data may be obtained, not whether
#' this package can obtain it. `public_use` means public-use files exist; it does
#' not mean they can be downloaded without an account. At KeNADA they cannot
#' (source audit F-03).
#'
#' @noRd
knbs_access_types <- function() {
  c(
    "open", "direct", "public_use", "licensed", "remote", "enclave",
    "external", "not_available", "unknown"
  )
}

#' Translate a NADA access model into the canonical vocabulary
#'
#' An unrecognised value becomes `"unknown"` rather than being guessed at or
#' dropped: the user can then see that the source said something the package did
#' not understand.
#'
#' @noRd
nada_access_type <- function(x) {
  map <- c(
    open = "open",
    direct = "direct",
    public = "public_use",
    licensed = "licensed",
    remote = "remote",
    enclave = "enclave",
    data_enclave = "enclave",
    external = "external",
    data_external = "external",
    data_na = "not_available"
  )
  out <- unname(map[tolower(as.character(x))])
  out[is.na(out)] <- "unknown"
  out
}

# Canonical column sets -------------------------------------------------------

knbs_survey_columns <- function() {
  c(
    "survey_id", "title", "acronym", "reference_years", "country", "producer",
    "geographic_coverage", "unit_of_analysis", "access_type", "catalogue_url",
    "metadata_updated", "source_id"
  )
}

knbs_variable_columns <- function() {
  c(
    "survey_id", "file_id", "file_name", "variable_id", "variable_name",
    "variable_label", "question_text", "universe", "concept", "value_labels",
    "variable_type", "source_url"
  )
}

knbs_file_columns <- function() {
  c(
    "survey_id", "file_id", "file_name", "file_type", "format", "size",
    "case_count", "var_count", "access_type", "downloadable", "download_url",
    "checksum", "source_id"
  )
}

#' A NADA year field, with the archive's "no year" placeholder made explicit
#'
#' KeNADA stores `year_start` and `year_end` as `"0"` for studies catalogued
#' without a reference year (53 of 131 studies, observed 2026-10-05). Zero is a
#' placeholder, not a year, so it becomes `NA`. The year is never inferred from
#' the title or identifier, even where one appears to carry it.
#'
#' @noRd
nada_year <- function(x, field) {
  year <- json_chr(x, field)
  if (!is.na(year) && grepl("^0+$", year)) NA_character_ else year
}

#' A study's reference years as one string
#'
#' One year when the study starts and ends in the same year or only one end is
#' recorded, both joined by `sep` otherwise, and `NA` when neither is recorded.
#'
#' @noRd
nada_year_span <- function(x, sep) {
  from <- nada_year(x, "year_start")
  to <- nada_year(x, "year_end")
  if (is.na(from) || is.na(to) || identical(from, to)) {
    return(if (is.na(from)) to else from)
  }
  paste0(from, sep, to)
}

#' Standardise NADA search rows into the survey catalogue schema
#'
#' Several catalogue fields (acronym, geographic coverage, unit of analysis) are
#' not present in search results and are returned as `NA`; they come from the
#' study record instead. Filling them here would mean one extra request per row.
#'
#' @noRd
standardise_nada_surveys <- function(rows, source_id) {
  n <- length(rows)
  years <- vapply(rows, nada_year_span, character(1), sep = "-")

  tibble::tibble(
    survey_id = vapply(rows, json_chr, character(1), "idno"),
    title = vapply(rows, json_chr, character(1), "title"),
    acronym = rep(NA_character_, n),
    reference_years = years,
    country = vapply(rows, json_chr, character(1), "nation"),
    producer = vapply(rows, json_chr, character(1), "authoring_entity"),
    geographic_coverage = rep(NA_character_, n),
    unit_of_analysis = rep(NA_character_, n),
    access_type = nada_access_type(vapply(rows, json_chr, character(1), "form_model")),
    catalogue_url = vapply(rows, json_chr, character(1), "url"),
    metadata_updated = do.call(c, c(list(as.Date(character(0))),
                                    lapply(rows, json_date, "changed"))),
    source_id = rep(source_id, n)
  )
}

#' Standardise a NADA variable list
#' @noRd
standardise_nada_variables <- function(variables, survey_id, source_id, file_names = NULL) {
  n <- length(variables)
  file_ids <- vapply(variables, json_chr, character(1), "fid")

  tibble::tibble(
    survey_id = rep(survey_id, n),
    file_id = file_ids,
    file_name = if (is.null(file_names)) rep(NA_character_, n) else unname(file_names[file_ids]),
    variable_id = vapply(variables, json_chr, character(1), "vid"),
    variable_name = vapply(variables, json_chr, character(1), "name"),
    variable_label = vapply(variables, json_chr, character(1), "labl"),
    # These four need one request per variable, so they stay empty unless the
    # caller asks for details.
    question_text = rep(NA_character_, n),
    universe = rep(NA_character_, n),
    concept = rep(NA_character_, n),
    value_labels = vector("list", n),
    variable_type = rep(NA_character_, n),
    source_url = rep(NA_character_, n)
  )
}

#' Merge a NADA variable detail payload into a standardised row
#' @noRd
standardise_nada_var_detail <- function(row, detail) {
  variable <- detail$variable
  meta <- variable$metadata

  # Question text lives in one of two places depending on how the study was
  # documented: the summary `qstn` field, or the DDI question literal.
  question <- json_chr(variable, "qstn")
  if (is.na(question)) {
    question <- json_chr(meta, "var_qstn_qstnlit")
  }
  row$question_text <- question
  row$universe <- json_chr(meta, "var_universe")
  row$concept <- json_chr(meta, "var_concept")
  row$variable_type <- json_chr(meta, "var_intrvl")

  categories <- variable$catgry
  row$value_labels <- list(
    if (is.null(categories) || length(categories) == 0L) {
      NULL
    } else {
      tibble::tibble(
        value = vapply(categories, json_chr, character(1), "value"),
        label = vapply(categories, json_chr, character(1), "labl")
      )
    }
  )
  row
}

#' Standardise a NADA data-file listing
#'
#' NADA describes data files but does not publish a size, format, checksum or
#' download URL for them, and at KeNADA the files are gated anyway, so
#' `downloadable` is `FALSE` throughout.
#'
#' @noRd
standardise_nada_files <- function(files, survey_id, source_id, access_type) {
  n <- length(files)
  tibble::tibble(
    survey_id = rep(survey_id, n),
    file_id = vapply(files, json_chr, character(1), "file_id"),
    file_name = vapply(files, json_chr, character(1), "file_name"),
    file_type = rep("microdata", n),
    format = rep(NA_character_, n),
    size = rep(NA_integer_, n),
    case_count = vapply(files, json_int, integer(1), "case_count"),
    var_count = vapply(files, json_int, integer(1), "var_count"),
    access_type = rep(access_type, n),
    downloadable = rep(FALSE, n),
    download_url = rep(NA_character_, n),
    checksum = rep(NA_character_, n),
    source_id = rep(source_id, n)
  )
}

empty_tibble <- function(columns) {
  out <- lapply(columns, function(nm) {
    switch(nm,
      size = integer(0),
      case_count = integer(0),
      var_count = integer(0),
      year = integer(0),
      file_size = numeric(0),
      downloadable = logical(0),
      value_labels = list(),
      metadata_updated = as.Date(character(0)),
      release_date = as.Date(character(0)),
      modified = as.Date(character(0)),
      character(0)
    )
  })
  names(out) <- columns
  tibble::as_tibble(out)
}
