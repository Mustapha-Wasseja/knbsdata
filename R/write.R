# Export ----------------------------------------------------------------------

#' Write KNBS data to a file, with its provenance
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Saves a table for colleagues who work in Excel, Stata, SPSS or anything
#' that reads CSV, without losing where it came from. The format follows the
#' file extension:
#'
#' * `.xlsx` - an Excel workbook with the data on a `data` sheet and an
#'   `about` sheet carrying the title, source, licence, release date,
#'   retrieval time and a ready-made citation.
#' * `.csv` - UTF-8 CSV, with missing values as empty cells.
#' * `.dta` - Stata, with the title as the dataset label.
#' * `.sav` - SPSS, likewise.
#' * `.rds` - R, keeping the object whole, metadata included.
#'
#' CSV, Stata and SPSS files get a `<file>.metadata.json` provenance sidecar
#' beside them, the same sidecar [knbs_download_publication()] writes.
#'
#' @details
#' Codes stay text: `"01"` is written as text in every format, never as the
#' number 1. In CSV that means a quoted string, which Excel may still turn
#' into a number when it opens the file; for Excel, write `.xlsx`.
#'
#' List columns (the value labels of a survey's variables, for example) have
#' no equivalent in these formats; each cell is written as JSON text, and
#' the provenance says which columns were converted.
#'
#' Stata limits variable names to 32 characters. Longer names are shortened
#' - keeping a `_code` or `_type` ending, and staying unique - and the full
#' name becomes the variable's label; the provenance lists every rename.
#'
#' A table derived with `summarise()` or a pivot is plain data and carries no
#' provenance of its own. Pass the source's with `metadata =
#' knbs_metadata(original)`; without it the file is still written, with a
#' warning, and the `about` sheet or sidecar says no provenance was attached.
#'
#' Excel output needs the writexl package and Stata or SPSS output the
#' haven package; you are asked to install them if they are missing.
#'
#' @param x A data frame: a result of this package, or any table.
#' @param path Where to write. The extension chooses the format.
#' @param format One of `"xlsx"`, `"csv"`, `"dta"`, `"sav"` or `"rds"`, to
#'   override the extension.
#' @param metadata The provenance to record. Defaults to `x`'s own.
#' @param overwrite Whether to replace an existing file.
#' @param quiet Whether to suppress the confirmation message.
#'
#' @return The path written, invisibly.
#'
#' @seealso [knbs_metadata()], [knbs_cite()]
#'
#' @examples
#' \dontrun{
#' gdp <- knbs_abstract_table("2.2")
#' knbs_write(gdp, "gdp-by-activity.xlsx")   # data + about sheet
#' knbs_write(gdp, "gdp-by-activity.dta")    # + gdp-by-activity.dta.metadata.json
#'
#' # A derived table keeps the source's provenance when you pass it on
#' totals <- dplyr::summarise(gdp, value = sum(value), .by = period)
#' knbs_write(totals, "totals.csv", metadata = knbs_metadata(gdp))
#' }
#' @export
knbs_write <- function(x,
                       path,
                       format = NULL,
                       metadata = NULL,
                       overwrite = FALSE,
                       quiet = knbs_option("quiet")) {
  if (!is.data.frame(x)) {
    knbs_abort(
      c("{.arg x} must be a data frame.", "x" = "Got {.obj_type_friendly {x}}."),
      class = "knbs_error_invalid_argument"
    )
  }
  check_string(path, "path")
  format <- tolower(format %||% tools::file_ext(path))
  if (!nzchar(format)) {
    knbs_abort(
      c("{.arg path} has no extension to choose a format from.",
        "i" = "End it in .xlsx, .csv, .dta, .sav or .rds, or give {.arg format}."),
      class = "knbs_error_invalid_argument"
    )
  }
  check_values(format, "format", c("xlsx", "csv", "dta", "sav", "rds"))
  check_bool(overwrite, "overwrite")
  if (!is.null(metadata) && !is_knbs_metadata(metadata)) {
    knbs_abort(
      c("{.arg metadata} must be a {.cls knbs_metadata} object.",
        "i" = "Take it from the original result with {.fn knbs_metadata}."),
      class = "knbs_error_invalid_argument"
    )
  }
  meta <- metadata %||% if (is_knbs_data(x)) knbs_metadata(x) else NULL
  if (is.null(meta)) {
    knbs_warn(
      c(
        "{.arg x} carries no provenance, so none is recorded.",
        "i" = "For a derived table, pass the source's: {.code metadata = knbs_metadata(original)}."
      ),
      class = "knbs_warning_missing_metadata"
    )
  }
  if (file.exists(path) && !overwrite) {
    knbs_abort(
      c("{.file {path}} already exists.", "i" = "Use {.code overwrite = TRUE} to replace it."),
      class = "knbs_error_invalid_argument"
    )
  }
  if (format == "xlsx") rlang::check_installed("writexl", "to write Excel files.")
  if (format %in% c("dta", "sav")) rlang::check_installed("haven", "to write Stata or SPSS files.")

  dir <- dirname(path)
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }

  prepared <- export_prepare(x, format)
  record <- export_record(meta, prepared, path, format)

  switch(format,
    xlsx = writexl::write_xlsx(
      list(data = prepared$data, about = export_about_sheet(record)),
      path
    ),
    csv = utils::write.csv(prepared$data, path, row.names = FALSE,
                           na = "", fileEncoding = "UTF-8"),
    dta = haven::write_dta(prepared$data, path,
                           label = export_dataset_label(meta, max = 80L)),
    sav = haven::write_sav(prepared$data, path),
    rds = saveRDS(if (is.null(metadata)) x else export_attach(x, metadata), path)
  )
  sidecar <- if (format %in% c("csv", "dta", "sav")) write_sidecar(path, record)

  if (!quiet) {
    cli::cli_alert_success(paste0(
      "Wrote {.file {path}} ({pretty_number(nrow(x))} {cli::qty(nrow(x))}row{?s})",
      if (format == "xlsx") " with an {.field about} sheet." else "",
      if (!is.null(sidecar)) ", provenance in {.file {basename(sidecar)}}." else "",
      if (format == "rds") ", metadata inside." else ""
    ))
  }
  invisible(path)
}

# Internals --------------------------------------------------------------------

#' A plain data frame each format can hold, and what was changed to get it
#' @noRd
export_prepare <- function(x, format) {
  data <- as.data.frame(tibble::as_tibble(x), stringsAsFactors = FALSE)
  converted <- character(0)
  for (col in names(data)) {
    if (is.list(data[[col]])) {
      data[[col]] <- vapply(data[[col]], function(v) {
        if (is.null(v)) NA_character_ else as.character(jsonlite::toJSON(v, auto_unbox = TRUE))
      }, character(1))
      converted <- c(converted, col)
    }
  }
  renamed <- stats::setNames(character(0), character(0))
  if (format == "dta") {
    short <- stata_names(names(data))
    changed <- short != names(data)
    for (i in which(changed)) {
      attr(data[[i]], "label") <- names(data)[[i]]
    }
    renamed <- stats::setNames(short[changed], names(data)[changed])
    names(data) <- short
  }
  if (format %in% c("dta", "sav")) {
    data <- tibble::as_tibble(data)
  }
  list(data = data, converted = converted, renamed = renamed)
}

#' Stata-safe variable names
#'
#' At most 32 characters, letters, digits and underscores, starting with a
#' letter or underscore, and unique. A shortened name keeps its `_code`,
#' `_type` or `_name` ending, so a dimension's label and code columns stay
#' recognisable as a pair.
#'
#' @noRd
stata_names <- function(names) {
  out <- gsub("[^A-Za-z0-9_]", "_", names)
  out[!grepl("^[A-Za-z_]", out)] <- paste0("v_", out[!grepl("^[A-Za-z_]", out)])
  long <- nchar(out) > 32L
  for (i in which(long)) {
    ending <- regmatches(out[[i]], regexpr("_(code|type|name)$", out[[i]]))
    ending <- if (length(ending) == 1L) ending else ""
    stem <- substr(out[[i]], 1L, nchar(out[[i]]) - nchar(ending))
    stem <- sub("_+$", "", substr(stem, 1L, 32L - nchar(ending)))
    out[[i]] <- paste0(stem, ending)
  }
  # Shortening can collide; number the later ones, still within 32.
  while (anyDuplicated(out) > 0L) {
    i <- anyDuplicated(out)
    k <- 2L
    repeat {
      suffix <- paste0("_", k)
      candidate <- paste0(substr(out[[i]], 1L, 32L - nchar(suffix)), suffix)
      if (!candidate %in% out) break
      k <- k + 1L
    }
    out[[i]] <- candidate
  }
  out
}

#' The provenance record written beside, or inside, the file
#' @noRd
export_record <- function(meta, prepared, path, format) {
  fields <- if (is.null(meta)) list() else unclass(meta)
  fields$raw <- NULL
  fields$sections <- NULL
  record <- c(
    list(file = basename(path), format = format,
         written_at = Sys.time(),
         rows = nrow(prepared$data), columns = names(prepared$data)),
    fields,
    list(
      citation = if (is.null(meta)) NULL else format(knbs_cite(meta)),
      provenance = if (is.null(meta)) "No provenance was attached to this table." else NULL,
      list_columns_as_json = if (length(prepared$converted)) prepared$converted else NULL,
      renamed_columns = if (length(prepared$renamed)) as.list(prepared$renamed) else NULL
    )
  )
  record[!vapply(record, is.null, logical(1))]
}

#' The about sheet: one row per fact, in reading order
#' @noRd
export_about_sheet <- function(record) {
  label <- c(
    title = "Title", producer = "Producer", source_name = "Source",
    source_url = "Source URL", resource_id = "Resource id",
    release_date = "Release date", reference_period = "Reference period",
    unit = "Unit", frequency = "Frequency", geographic_level = "Geography",
    licence = "Licence", access = "Access", retrieved_at = "Retrieved",
    package_version = "knbsdata version", citation = "Citation",
    provenance = "Provenance", written_at = "Written", rows = "Rows"
  )
  as_text <- function(v) {
    if (inherits(v, "POSIXt")) return(format(v, "%Y-%m-%d %H:%M:%S %Z"))
    if (inherits(v, "Date")) return(format(v, "%Y-%m-%d"))
    as.character(v)
  }
  rows <- list()
  for (field in names(label)) {
    if (!is.null(record[[field]])) {
      rows[[length(rows) + 1L]] <- data.frame(
        field = label[[field]], value = paste(as_text(record[[field]]), collapse = "; "),
        stringsAsFactors = FALSE
      )
    }
  }
  for (note in as.character(record$notes %||% character(0))) {
    rows[[length(rows) + 1L]] <- data.frame(field = "Note", value = note,
                                            stringsAsFactors = FALSE)
  }
  if (length(record$list_columns_as_json)) {
    rows[[length(rows) + 1L]] <- data.frame(
      field = "Written as JSON text",
      value = paste(record$list_columns_as_json, collapse = ", "),
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

#' A dataset label within a format's limit
#' @noRd
export_dataset_label <- function(meta, max) {
  title <- as.character(meta$title %||% "")
  if (!nzchar(title)) return(NULL)
  if (nchar(title) > max) paste0(substr(title, 1L, max - 3L), "...") else title
}

#' Give a plain table the provenance passed for it, for an .rds file
#' @noRd
export_attach <- function(x, metadata) {
  if (is_knbs_data(x)) {
    attr(x, "knbs_metadata") <- metadata
    return(x)
  }
  new_knbs_data(x, metadata)
}
