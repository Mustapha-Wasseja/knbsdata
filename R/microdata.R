# Reading microdata ---------------------------------------------------------------

#' Read a microdata file into R
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reads a Stata (`.dta`), SPSS (`.sav`, `.zsav`, `.por`) or Excel (`.xlsx`,
#' `.xls`) file, or the data file inside a `.zip` archive, keeping its
#' variable and value labels. Pass it a path or what
#' [knbs_download_finaccess()] returns. When the file has a knbsdata
#' provenance sidecar beside it, the result carries that provenance:
#' [knbs_metadata()] says where it came from and [knbs_cite()] cites it.
#'
#' @details
#' Stata and SPSS files are read with \pkg{haven}, which must be installed.
#' Value labels arrive as [haven::labelled()] columns: `haven::as_factor()`
#' turns them into factors and `haven::zap_labels()` drops them. Each
#' column's question text is in its `"label"` attribute.
#'
#' An archive is unpacked to a temporary directory, which is removed once the
#' file is read. If it holds more than one data file, name the one to read
#' with `file`.
#'
#' A first variable name that begins with the remnant of a byte-order mark,
#' an encoding slip that puts a stray character or two in front of a name
#' such as `interview__key`, is repaired, and the repair is noted in the
#' metadata.
#'
#' @param x A path, or a download record from [knbs_download_finaccess()]
#'   holding one data file.
#' @param file For an archive, the entry to read. Needed only when it holds
#'   more than one data file.
#' @param ... Passed to the reader: [haven::read_dta()], [haven::read_sav()],
#'   [haven::read_por()] or [readxl::read_excel()]. `col_select` reads only
#'   some variables of a large Stata or SPSS file, and `n_max` only its first
#'   rows.
#'
#' @return A tibble. With a provenance sidecar, a `knbs_microdata` tibble
#'   whose metadata records the source, the producers, the file's checksum
#'   and its terms.
#'
#' @seealso [knbs_download_finaccess()], [knbs_cite()]
#'
#' @examples
#' \dontrun{
#' fa <- knbs_read_microdata(knbs_download_finaccess("hh2024-stata", "data"))
#' knbs_cite(fa)
#'
#' # Only some variables of a large file
#' knbs_read_microdata("data/2024_Finaccess_Publicdata.dta",
#'                     col_select = c(1:5))
#' }
#' @export
knbs_read_microdata <- function(x, file = NULL, ...) {
  path <- microdata_path(x)
  if (!is.null(file)) {
    check_string(file, "file")
  }
  if (!file.exists(path)) {
    knbs_abort(
      c("{.file {path}} does not exist."),
      class = "knbs_error_resource_not_found"
    )
  }

  entry <- NULL
  if (identical(tolower(tools::file_ext(path)), "zip")) {
    entry <- microdata_entry(path, file)
    unpacked <- tempfile("knbs-unzip-")
    dir.create(unpacked)
    on.exit(unlink(unpacked, recursive = TRUE), add = TRUE)
    data <- microdata_read_file(unzip_safely(path, unpacked, files = entry), ...)
  } else {
    if (!is.null(file)) {
      knbs_abort(
        c(
          "{.arg file} names an entry inside an archive.",
          "x" = "{.file {basename(path)}} is not a {.file .zip} archive."
        ),
        class = "knbs_error_invalid_argument"
      )
    }
    data <- microdata_read_file(path, ...)
  }

  repaired <- microdata_repair_names(names(data))
  changed <- which(repaired != names(data))
  notes <- if (length(changed) > 0L) {
    paste0("The variable ", repaired[changed], " is stored as \"", names(data)[changed],
           "\": its name began with the remnant of a byte-order mark, removed here.")
  }
  names(data) <- repaired

  sidecar <- read_sidecar(path)
  if (is.null(sidecar)) {
    return(tibble::as_tibble(data))
  }
  new_knbs_data(data, microdata_metadata(sidecar, path, entry, notes),
                class = "knbs_microdata")
}

# Internals ---------------------------------------------------------------------

microdata_extensions <- function() c("dta", "sav", "zsav", "por", "xlsx", "xls")

#' The path to read, from a path or a download record
#' @noRd
microdata_path <- function(x, call = rlang::caller_env()) {
  if (is.data.frame(x)) {
    if (!"local_path" %in% names(x)) {
      knbs_abort(
        c("{.arg x} must be a path or a download record with a {.field local_path} column."),
        class = "knbs_error_invalid_argument",
        call = call
      )
    }
    paths <- as.character(x$local_path)
    readable <- paths[tolower(tools::file_ext(paths)) %in% c(microdata_extensions(), "zip")]
    if (length(readable) != 1L) {
      knbs_abort(
        c(
          "{.arg x} must hold exactly one data file.",
          "x" = "It holds {length(readable)}: {.file {basename(readable)}}.",
          "i" = "Pass one row, or the path of the file to read."
        ),
        class = "knbs_error_invalid_argument",
        call = call
      )
    }
    return(readable)
  }
  check_string(x, "x", call = call)
  x
}

#' Pick the data file to read inside an archive
#' @noRd
microdata_entry <- function(path, file, call = rlang::caller_env()) {
  entries <- archive_entries(path)
  check_archive_entries(entries, call = call)
  if (!is.null(file)) {
    if (!file %in% entries) {
      knbs_abort(
        c(
          "{.file {basename(path)}} has no entry {.file {file}}.",
          "i" = "It holds {.file {entries}}."
        ),
        class = "knbs_error_resource_not_found",
        call = call
      )
    }
    return(file)
  }
  data_entries <- entries[tolower(tools::file_ext(entries)) %in% microdata_extensions()]
  if (length(data_entries) == 1L) {
    return(data_entries)
  }
  knbs_abort(
    c(
      if (length(data_entries) == 0L) {
        "{.file {basename(path)}} holds no Stata, SPSS or Excel file."
      } else {
        "{.file {basename(path)}} holds {length(data_entries)} data files."
      },
      "i" = "It holds {.file {entries}}.",
      if (length(data_entries) > 1L) c("i" = "Name the one to read with {.arg file}.")
    ),
    class = if (length(data_entries) == 0L) "knbs_error_resource_not_found" else "knbs_error_ambiguous_resource",
    call = call
  )
}

#' Read one data file by its extension
#' @noRd
microdata_read_file <- function(path, ..., call = rlang::caller_env()) {
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("dta", "sav", "zsav", "por")) {
    rlang::check_installed("haven", "to read Stata and SPSS files.")
  }
  switch(ext,
    dta = haven::read_dta(path, ...),
    sav = ,
    zsav = haven::read_sav(path, ...),
    por = haven::read_por(path, ...),
    xlsx = ,
    xls = readxl::read_excel(path, ...),
    knbs_abort(
      c(
        "{.fn knbs_read_microdata} reads Stata, SPSS and Excel files.",
        "x" = "Got {.file {basename(path)}}."
      ),
      class = "knbs_error_invalid_argument",
      call = call
    )
  )
}

#' Remove the remnant of a byte-order mark from the first variable name
#'
#' A file written with a UTF-8 byte-order mark ahead of its first variable
#' name can carry it into the name itself: as U+FEFF, as its three bytes read
#' one character each, or as the "i-diaeresis" alone, which a further round
#' of mis-decoding turns into two characters (the FinAccess MSE Tracker Wave
#' I file arrives as "\\u00c3\\u00afinterview__key"). The pieces are built from
#' code points so that this file stays ASCII.
#'
#' @noRd
microdata_repair_names <- function(x) {
  if (length(x) == 0L) {
    return(x)
  }
  remnants <- c(
    intToUtf8(0xFEFF),
    intToUtf8(c(0xEF, 0xBB, 0xBF)),
    intToUtf8(c(0xC3, 0xAF)),
    intToUtf8(0xEF)
  )
  pattern <- paste0("^(", paste(remnants, collapse = "|"), ")+")
  first <- sub(pattern, "", x[[1]])
  if (!identical(first, x[[1]]) && grepl("^[A-Za-z_]", first) && !first %in% x[-1]) {
    x[[1]] <- first
  }
  x
}

#' Provenance for a file read from disk, from its sidecar
#' @noRd
microdata_metadata <- function(sidecar, path, entry, notes) {
  source_name <- tryCatch(
    knbs_source(sidecar$source_id %||% "")$source_name,
    knbs_error = function(cnd) NULL
  )
  fields <- compact_list(list(
    title = sidecar$title %||% basename(path),
    resource_id = sidecar$file_id,
    resource_type = "microdata",
    source_id = sidecar$source_id,
    source_name = source_name,
    source_url = sidecar$source_url %||% sidecar$download_url,
    producer = sidecar$producer,
    reference_period = if (!is.null(sidecar$year)) as.character(sidecar$year),
    retrieved_at = sidecar_time(sidecar$downloaded_at),
    licence = sidecar$licence,
    access = "open",
    checksum = sidecar$sha256,
    notes = c(
      if (!is.null(entry)) paste0("Read from ", entry, " inside ", basename(path), "."),
      sidecar$notes,
      notes,
      sidecar$terms
    )
  ))
  do.call(new_knbs_metadata, c(fields, list(raw = sidecar)))
}
