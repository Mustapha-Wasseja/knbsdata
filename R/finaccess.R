# FinAccess survey files --------------------------------------------------------
#
# The FinAccess household survey is Kenya's survey of financial inclusion, run
# by the Central Bank of Kenya, KNBS and FSD Kenya. Its anonymised, weighted
# microdata are published openly on the FinAccess portal as Google Drive
# files (audit F-40). The portal is a web page, not a catalogue, so the files
# are catalogued by hand in inst/extdata/finaccess-registry.yml, and every
# download is held to that record: served name and size before the transfer,
# size and SHA-256 after it.

#' List the FinAccess survey files
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The FinAccess household survey, Kenya's survey of financial inclusion run
#' by the Central Bank of Kenya, KNBS and FSD Kenya, publishes its anonymised,
#' weighted microdata openly, with no account needed: six rounds from 2006 to
#' 2024, and two waves of the FinAccess MSE Tracker Survey of micro and small
#' enterprises (2022 and 2023). This lists every file, with the
#' questionnaires, manuals and reports, from a catalogue kept with the
#' package; nothing is contacted.
#'
#' Download files with [knbs_download_finaccess()] and read them with
#' [knbs_read_microdata()].
#'
#' @details
#' The catalogue records what each link on the portal actually serves, which
#' is not always what its label says: the MSE Tracker Wave II "SPSS" link
#' serves the Stata file and the reverse, the Wave I "Stata" link serves the
#' SPSS file, and the 2006 and 2009 "Questionnaire" archives hold the survey
#' data too. The `notes` column says where a label was corrected. The
#' portal's 2019 heading lists no files.
#'
#' The 2013 survey's Stata copy is held on Harvard Dataverse behind a
#' registration form; it is listed with `access = "registration"` and never
#' downloaded. Its SPSS copy is open.
#'
#' @param year Survey years to keep.
#' @param survey `"household"` or `"mse_tracker"`.
#' @param content Any of `"data"`, `"questionnaire"`, `"manual"` and
#'   `"report"`.
#' @param format Any of `"stata"`, `"spss"`, `"excel"` and `"pdf"`. For an
#'   archive, the format of the data inside it.
#'
#' @return A `knbs_catalogue` tibble with one row per file: `file_id`,
#'   `title`, `survey`, `year`, `wave`, `content`, `format`, `file_name`,
#'   `size_bytes`, `sha256`, `archive`, `access`, `url` and `notes`.
#'
#' @seealso [knbs_download_finaccess()], [knbs_read_microdata()]
#'
#' @examples
#' knbs_finaccess_files()
#' knbs_finaccess_files(year = 2024, content = "data")
#' knbs_finaccess_files(survey = "mse_tracker")
#' @export
knbs_finaccess_files <- function(year = NULL,
                                 survey = NULL,
                                 content = NULL,
                                 format = NULL) {
  registry <- finaccess_registry()
  out <- finaccess_catalogue(registry)

  if (!is.null(year)) {
    if (!is.numeric(year) || length(year) == 0L || anyNA(year)) {
      knbs_abort(
        c("{.arg year} must be one or more years.", "x" = "Got {.obj_type_friendly {year}}."),
        class = "knbs_error_invalid_argument"
      )
    }
    missing_years <- setdiff(year, out$year)
    if (length(missing_years) > 0L) {
      knbs_abort(
        c(
          "FinAccess has no files for {.val {missing_years}}.",
          "i" = "Years with files: {.val {sort(unique(out$year))}}.",
          if (2019 %in% missing_years) c("i" = "The portal's 2019 heading lists no files.")
        ),
        class = "knbs_error_resource_not_found"
      )
    }
    out <- out[out$year %in% year, ]
  }
  if (!is.null(survey)) {
    check_values(survey, "survey", names(registry$surveys))
    out <- out[out$survey %in% survey, ]
  }
  if (!is.null(content)) {
    check_values(content, "content", finaccess_contents())
    out <- out[out$content %in% content, ]
  }
  if (!is.null(format)) {
    check_values(format, "format", finaccess_formats())
    out <- out[out$format %in% format, ]
  }
  out$drive_id <- NULL

  new_knbs_catalogue(out, finaccess_metadata(registry))
}

#' Download FinAccess survey files
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Downloads files listed by [knbs_finaccess_files()] from the FinAccess
#' portal, under their official names, and proves they are the files the
#' package catalogued. Before a transfer, a sixteen-byte request confirms the
#' file's served name and size, so a file that has changed is refused before
#' anything large moves. After it, the size is checked again and the SHA-256
#' must equal the catalogued one. A `<file>.metadata.json` sidecar beside each
#' file records where it came from, the producers and their terms, so that
#' [knbs_read_microdata()] and [knbs_cite()] can say so later.
#'
#' @details
#' **Terms.** The portal states no licence. FSD Kenya's terms for the 2013
#' survey on Harvard Dataverse restrict the data to statistical and
#' scientific research, forbid redistributing it without FSD Kenya's written
#' agreement, rule out investigating specific individuals or organisations,
#' and ask publications to cite the source. Do not assume wider reuse is
#' allowed: ask the producers first. The package never bundles these files.
#' The first download in a session says so.
#'
#' **Already downloaded.** A file already in `destination` is not downloaded
#' again if it is byte-identical to the catalogued one; its record is
#' returned instead. That makes
#' `knbs_read_microdata(knbs_download_finaccess("hh2024-stata", "data"))` safe to
#' re-run. A file there that differs is left alone, and the call stops unless
#' `overwrite = TRUE`.
#'
#' **Large files.** The 2024 files are 160 to 290 MB. Downloads stream to
#' disk and show progress unless `quiet`. They are not held to the package's
#' request timeout; a transfer is abandoned only once it has stalled for that
#' long. Google Drive serves a file too large for its virus scan after a
#' notice saying it could not be scanned; the package requests the file
#' directly, as the notice's own download button does, and relies on the
#' checks above.
#'
#' **Registration.** Asking for the 2013 survey's Stata copy, which Harvard
#' Dataverse holds behind a registration form, raises
#' `knbs_error_authentication_required` with the page to visit. knbsdata
#' does not automate sign-in, licence acceptance or approval workflows.
#'
#' @param file File ids from [knbs_finaccess_files()], such as
#'   `"hh2024-stata"`, or that function's result.
#' @param destination Directory to write into; created if needed. There is
#'   no default: nothing is written anywhere you have not named.
#' @param overwrite Whether to replace a file already in `destination`.
#' @param verify Whether to hold each file to the catalogue. `FALSE`
#'   downloads whatever the link serves now, under the name it is served
#'   with: for when the producers have revised a file since the catalogue
#'   was made. A web page is refused either way.
#' @param quiet Whether to suppress messages and the progress bar.
#'
#' @return Invisibly, a tibble with one row per file: `resource_id`,
#'   `file_id`, `original_name`, `local_path`, `download_url`,
#'   `downloaded_at`, `size_bytes`, `sha256`, `content_type`,
#'   `package_version` and `source_id`. Pass it to [knbs_read_microdata()].
#'
#' @seealso [knbs_finaccess_files()], [knbs_read_microdata()]
#'
#' @examplesIf interactive()
#' dir <- file.path(tempdir(), "finaccess")
#'
#' # The 2024 household survey, Stata format (160 MB)
#' fa <- knbs_read_microdata(knbs_download_finaccess("hh2024-stata", dir))
#'
#' # The questionnaires and manuals
#' knbs_finaccess_files(content = c("questionnaire", "manual")) |>
#'   knbs_download_finaccess(dir)
#' @export
knbs_download_finaccess <- function(file,
                                    destination,
                                    overwrite = FALSE,
                                    verify = TRUE,
                                    quiet = knbs_option("quiet")) {
  if (is.data.frame(file)) {
    if (!"file_id" %in% names(file)) {
      knbs_abort(
        c(
          "{.arg file} must be file ids or a table with a {.field file_id} column.",
          "i" = "See {.fn knbs_finaccess_files}."
        ),
        class = "knbs_error_invalid_argument"
      )
    }
    file <- as.character(file$file_id)
  }
  check_character(file, "file")
  if (missing(destination)) {
    abort_no_destination()
  }
  check_string(destination, "destination")
  check_bool(overwrite, "overwrite")
  check_bool(verify, "verify")
  check_bool(quiet, "quiet")

  src <- resolve_source("download_public_files", "finaccess")
  registry <- finaccess_registry()
  rows <- finaccess_lookup(finaccess_catalogue(registry), unique(file))
  finaccess_refuse_registration(rows)

  records <- lapply(seq_len(nrow(rows)), function(i) {
    finaccess_fetch(rows[i, ], registry, src,
                    destination = destination, overwrite = overwrite,
                    verify = verify, quiet = quiet)
  })
  invisible(do.call(rbind, records))
}

# Adapter -----------------------------------------------------------------------

#' @export
source_health.knbs_source_finaccess <- function(source, ...) {
  started <- Sys.time()
  outcome <- tryCatch(
    {
      resp <- knbs_perform(knbs_request(source$landing_page),
                           source_id = source$source_id, expect = "text/html")
      listed <- finaccess_page_ids(httr2::resp_body_string(resp))
      expected <- finaccess_catalogue()$drive_id
      gone <- setdiff(expected[!is.na(expected)], listed)
      list(
        status = if (length(gone) == 0L) "ok" else "unavailable",
        http_status = httr2::resp_status(resp),
        message = if (length(gone) == 0L) {
          paste0("Portal answered and links all ", sum(!is.na(expected)),
                 " catalogued files.")
        } else {
          paste0("Portal answered but no longer links ", length(gone),
                 " catalogued file(s); the catalogue may be out of date.")
        }
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
    operation = "download_public_files",
    status = outcome$status,
    http_status = as.integer(outcome$http_status),
    response_time_ms = as.numeric(difftime(Sys.time(), started, units = "secs")) * 1000,
    checked_at = started,
    message = outcome$message
  )
}

# Internals ---------------------------------------------------------------------

finaccess_contents <- function() c("data", "questionnaire", "manual", "report")

finaccess_formats <- function() c("stata", "spss", "excel", "pdf")

#' Read and validate the FinAccess file catalogue
#' @noRd
finaccess_registry <- function(call = rlang::caller_env()) {
  path <- system.file("extdata", "finaccess-registry.yml", package = "knbsdata")
  if (!nzchar(path)) {
    path <- file.path("inst", "extdata", "finaccess-registry.yml")
  }
  registry <- yaml::read_yaml(path)
  if (!finaccess_registry_valid(registry)) {
    knbs_abort("The FinAccess file catalogue is invalid; please report it.", call = call)
  }
  registry
}

#' @noRd
finaccess_registry_valid <- function(registry) {
  files <- registry$files
  if (!is.list(files) || length(files) == 0L || !is.list(registry$surveys)) {
    return(FALSE)
  }
  ids <- vapply(files, function(f) as.character(f$file_id %||% ""), character(1))
  if (anyDuplicated(ids) > 0L || !all(nzchar(ids))) {
    return(FALSE)
  }
  all(vapply(files, function(f) {
    described <- (f$survey %||% "") %in% names(registry$surveys) &&
      is.numeric(f$year) &&
      (f$content %||% "") %in% finaccess_contents() &&
      (f$format %||% "") %in% finaccess_formats() &&
      is_string(f$file_name %||% NA_character_)
    reachable <- if (identical(f$access %||% "open", "open")) {
      is_string(f$drive_id %||% NA_character_) && is.numeric(f$size_bytes) &&
        grepl("^[0-9a-f]{64}$", f$sha256 %||% "")
    } else {
      identical(f$access, "registration") && is_string(f$access_url %||% NA_character_)
    }
    described && reachable
  }, logical(1)))
}

#' The catalogue as a tibble, with the internal Drive ids
#' @noRd
finaccess_catalogue <- function(registry = finaccess_registry()) {
  files <- registry$files
  chr <- function(field, default = NA_character_) {
    vapply(files, function(f) as.character(f[[field]] %||% default), character(1))
  }
  num <- function(field) {
    vapply(files, function(f) as.numeric(f[[field]] %||% NA_real_), numeric(1))
  }
  drive_id <- chr("drive_id")
  file_name <- chr("file_name")

  tibble::tibble(
    file_id = chr("file_id"),
    title = vapply(files, finaccess_title, character(1), surveys = registry$surveys),
    survey = chr("survey"),
    year = as.integer(num("year")),
    wave = chr("wave"),
    content = chr("content"),
    format = chr("format"),
    file_name = file_name,
    size_bytes = num("size_bytes"),
    sha256 = chr("sha256"),
    archive = grepl("\\.zip$", file_name, ignore.case = TRUE),
    access = chr("access", "open"),
    url = ifelse(is.na(drive_id), chr("access_url"),
                 paste0("https://drive.google.com/file/d/", drive_id, "/view")),
    notes = chr("notes"),
    drive_id = drive_id
  )
}

#' A readable title for one catalogue entry
#' @noRd
finaccess_title <- function(f, surveys) {
  if (!is.null(f$title)) {
    return(as.character(f$title))
  }
  round <- paste0(surveys[[f$survey]], " ", f$year,
                  if (!is.null(f$wave)) paste0(", ", f$wave) else "")
  what <- if (identical(f$content, "data")) {
    paste0("microdata (", finaccess_format_label(f$format), ")")
  } else {
    f$content
  }
  paste0(round, ": ", what)
}

finaccess_format_label <- function(format) {
  c(stata = "Stata", spss = "SPSS", excel = "Excel", pdf = "PDF")[[format]]
}

#' Provenance shared by everything the catalogue lists
#' @noRd
finaccess_metadata <- function(registry) {
  new_knbs_metadata(
    title = "FinAccess survey files",
    resource_type = "microdata",
    source_id = "finaccess",
    source_name = "FinAccess Household and MSE Tracker Surveys (open microdata)",
    source_url = registry$portal,
    producer = registry$producer,
    licence = registry$licence,
    access = "open",
    notes = c(
      paste0("Catalogued by hand from the FinAccess portal; every file checked on ",
             as.character(registry$checked), "."),
      registry$terms,
      "Download with knbs_download_finaccess(); read with knbs_read_microdata()."
    )
  )
}

#' Find catalogue rows by file id, suggesting the intended one on a miss
#' @noRd
finaccess_lookup <- function(catalogue, ids, call = rlang::caller_env()) {
  unknown <- setdiff(ids, catalogue$file_id)
  if (length(unknown) > 0L) {
    first <- unknown[[1]]
    # "hh2024" names a survey round, not a file: offer the round's files.
    round_files <- catalogue$file_id[startsWith(catalogue$file_id, paste0(first, "-"))]
    distance <- utils::adist(first, catalogue$file_id, ignore.case = TRUE)[1, ]
    nearest <- catalogue$file_id[distance == min(distance) & distance <= 3]
    hint <- if (length(round_files) > 0L) {
      c("i" = "{.val {first}} is a survey round; its files are {.val {round_files}}.")
    } else if (length(nearest) > 0L) {
      c("i" = "Did you mean {.val {nearest[[1]]}}?")
    }
    knbs_abort(
      c(
        "{cli::qty(length(unknown))}Unknown FinAccess file{?s}: {.val {unknown}}.",
        hint,
        "i" = "See {.fn knbs_finaccess_files} for every file."
      ),
      class = "knbs_error_resource_not_found",
      call = call
    )
  }
  catalogue[match(ids, catalogue$file_id), ]
}

#' Refuse, before any download, a file held behind a registration step
#' @noRd
finaccess_refuse_registration <- function(rows, call = rlang::caller_env()) {
  gated <- rows[rows$access != "open", ]
  if (nrow(gated) == 0L) {
    return(invisible(rows))
  }
  knbs_abort(
    c(
      "{.val {gated$file_id}} cannot be downloaded programmatically.",
      "x" = "{cli::qty(nrow(gated))}{?It is/They are} held behind a registration form.",
      "i" = "Register and request access at {.url {unique(gated$url)}}.",
      "i" = "knbsdata does not automate sign-in, licence acceptance or approval workflows.",
      "i" = "{.fn knbs_finaccess_files} lists the open copies, such as {.val hh2013-spss}."
    ),
    class = "knbs_error_authentication_required",
    call = call,
    access_url = gated$url[[1]]
  )
}

#' Where Drive serves a file's bytes
#'
#' `confirm=t` is what the download button on Drive's notice for files too
#' large to virus-scan requests; without it such a file answers with that
#' notice instead of the file (audit F-40).
#'
#' @noRd
finaccess_download_url <- function(drive_id) {
  paste0("https://drive.usercontent.google.com/download?id=", drive_id,
         "&export=download&confirm=t")
}

#' Download one catalogued file, or reuse an identical copy
#' @noRd
finaccess_fetch <- function(row, registry, src, destination, overwrite, verify, quiet) {
  existing <- file.path(destination, row$file_name)
  if (verify && !overwrite && file.exists(existing)) {
    return(finaccess_reuse(row, registry, existing, quiet))
  }

  url <- finaccess_download_url(row$drive_id)
  if (verify) {
    probe <- probe_download(url, source_id = src$source_id)
    finaccess_check_served(row, probe$file_name, probe$size_bytes,
                           probe$content_type, transferred = FALSE)
  }
  finaccess_terms_notice(registry, quiet)

  fetched <- download_to_temp(url, source_id = src$source_id, progress = !quiet)
  on.exit(unlink(fetched$path), add = TRUE)
  check_download_type(fetched$content_type, row$file_name, row$url)

  size <- file.size(fetched$path)
  checksum <- file_sha256(fetched$path)
  if (verify) {
    finaccess_check_served(row, fetched$file_name, size, fetched$content_type,
                           transferred = TRUE)
    if (!identical(checksum, row$sha256)) {
      knbs_abort(
        c(
          "The download of {.val {row$file_id}} does not match the catalogued checksum.",
          "x" = "SHA-256 {.val {checksum}}; the catalogue has {.val {row$sha256}}.",
          "i" = "It may have been revised by the producers, or damaged in transit. Nothing was kept.",
          "i" = "Try again, or use {.code verify = FALSE} to keep what the link serves now."
        ),
        class = "knbs_error_validation_failed",
        file_id = row$file_id
      )
    }
  }

  name <- if (verify || is.na(fetched$file_name)) row$file_name else fetched$file_name
  target <- file.path(destination, name)
  move_into_place(fetched$path, target, overwrite = overwrite)

  record <- finaccess_record(row, target, url, Sys.time(), size, checksum,
                             fetched$content_type)
  write_sidecar(target, finaccess_sidecar(record, row, registry, verified = verify))
  if (!quiet) {
    cli::cli_alert_success("Downloaded {.file {name}} ({pretty_number(size)} bytes).")
  }
  record
}

#' Hold a served file to its catalogue entry
#' @noRd
finaccess_check_served <- function(row, file_name, size, content_type,
                                   transferred, call = rlang::caller_env()) {
  kept <- if (transferred) c("i" = "Nothing was kept.") else c("i" = "Nothing was downloaded.")
  if (is.na(file_name)) {
    knbs_abort(
      c(
        "Google Drive did not serve {.val {row$file_id}} as a file.",
        "x" = "It answered with {.val {content_type}} and no file name.",
        "i" = "Drive pauses downloads of a much-requested file for a while; try again later.",
        "i" = "If it persists, the file may have been withdrawn: see {.url {row$url}}.",
        kept
      ),
      class = "knbs_error_download_failed",
      call = call,
      file_id = row$file_id
    )
  }
  if (!identical(file_name, row$file_name) || !isTRUE(size == row$size_bytes)) {
    knbs_abort(
      c(
        "The file behind {.val {row$file_id}} has changed since knbsdata catalogued it.",
        "x" = "Catalogued: {.file {row$file_name}}, {pretty_number(row$size_bytes)} bytes.",
        "x" = "Served now: {.file {file_name}}, {pretty_number(size)} bytes.",
        "i" = "The producers may have revised it; please report the change.",
        "i" = "{.code verify = FALSE} downloads what the link serves now.",
        kept
      ),
      class = "knbs_error_validation_failed",
      call = call,
      file_id = row$file_id
    )
  }
  invisible(TRUE)
}

#' Return the record of a copy already in the destination
#'
#' The copy is reused only if it is byte-identical to the catalogued file. Its
#' own sidecar is kept when it vouches for these bytes, and written when it
#' does not, since the checksum now does.
#'
#' @noRd
finaccess_reuse <- function(row, registry, path, quiet, call = rlang::caller_env()) {
  size <- file.size(path)
  checksum <- if (isTRUE(size == row$size_bytes)) file_sha256(path) else NA_character_
  if (!identical(checksum, row$sha256)) {
    knbs_abort(
      c(
        "{.file {row$file_name}} is already in {.path {dirname(path)}}, but it is not the catalogued file.",
        "x" = "Its size or checksum differs from the catalogue's.",
        "i" = "Use {.code overwrite = TRUE} to replace it with a fresh download."
      ),
      class = "knbs_error_download_failed",
      call = call,
      file_id = row$file_id
    )
  }

  recorded <- read_sidecar(path)
  record <- finaccess_record(
    row, path,
    url = recorded$download_url %||% finaccess_download_url(row$drive_id),
    downloaded_at = sidecar_time(recorded$downloaded_at) %||% file.mtime(path),
    size = size,
    checksum = checksum,
    content_type = recorded$content_type %||% NA_character_
  )
  if (!identical(recorded$sha256, checksum)) {
    write_sidecar(path, finaccess_sidecar(
      record, row, registry, verified = TRUE,
      note = "Found in the destination and matched to the catalogued checksum, not downloaded."
    ))
  }
  if (!quiet) {
    cli::cli_alert_info("{.file {row$file_name}} is already downloaded and matches the catalogue.")
  }
  record
}

#' One row of the download manifest
#' @noRd
finaccess_record <- function(row, path, url, downloaded_at, size, checksum, content_type) {
  tibble::tibble(
    resource_id = sub("-.*$", "", row$file_id),
    file_id = row$file_id,
    original_name = basename(path),
    local_path = path,
    download_url = url,
    downloaded_at = downloaded_at,
    size_bytes = as.numeric(size),
    sha256 = checksum,
    content_type = as.character(content_type),
    package_version = as.character(utils::packageVersion("knbsdata")),
    source_id = "finaccess"
  )
}

#' The sidecar: the manifest row plus what a later reader needs to cite it
#' @noRd
finaccess_sidecar <- function(record, row, registry, verified, note = NULL) {
  c(
    as.list(record),
    list(
      title = row$title,
      survey = registry$surveys[[row$survey]],
      year = row$year,
      wave = if (is.na(row$wave)) NULL else row$wave,
      content = row$content,
      format = row$format,
      producer = registry$producer,
      licence = registry$licence,
      terms = registry$terms,
      source_url = registry$portal,
      catalogue_checked = as.character(registry$checked),
      verified = verified,
      notes = c(if (!is.na(row$notes)) row$notes, note)
    )
  )
}

#' Say once a session whose data these are and on what terms
#' @noRd
finaccess_terms_notice <- function(registry, quiet) {
  if (quiet || isTRUE(the$finaccess_terms_shown)) {
    return(invisible(FALSE))
  }
  the$finaccess_terms_shown <- TRUE
  cli::cli_inform(
    c(
      "i" = "FinAccess data are published by the {registry$producer}.",
      "!" = "The portal states no licence; do not assume the files may be redistributed.",
      "i" = "Cite the producers in your work: {.code knbs_cite()} on what {.fn knbs_read_microdata} returns.",
      " " = "This message is shown once per session."
    ),
    class = "knbs_message_terms"
  )
  invisible(TRUE)
}

#' Drive file ids linked from the portal page
#' @noRd
finaccess_page_ids <- function(html) {
  hits <- regmatches(html, gregexpr("/d/[A-Za-z0-9_-]{20,}", html))[[1]]
  unique(sub("^/d/", "", hits))
}
