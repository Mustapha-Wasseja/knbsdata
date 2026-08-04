# Safe downloading ------------------------------------------------------------
#
# Source-independent machinery for retrieving a file and proving what was
# retrieved (plan sections 15.6, 11.9, 11.11 and 16.6). No adapter uses it yet:
# KeNADA gates its microdata, and the publications source could not be audited.
# It is written and tested separately so that when a source does permit a
# download, the download itself is not the risky part.
#
# The rules, in order:
#
#   1. Stream to a temporary file, never straight to the destination, so a
#      failed transfer cannot leave a half-written file that looks complete.
#   2. Check what came back before believing it. An HTML page arriving where a
#      PDF was expected is an access gate or an error page, not a document.
#   3. Checksum it.
#   4. Move it into place only then.
#   5. Record where it came from, next to the file.

#' Fetch a URL to a temporary file
#'
#' The only part of the download path that touches the network, kept separate so
#' that everything around it can be tested without one.
#'
#' @return A list with `path`, `content_type` and `status`.
#' @noRd
download_to_temp <- function(url, source_id = NULL, call = rlang::caller_env()) {
  tmp <- tempfile("knbs-download-")
  req <- knbs_request(url)
  resp <- knbs_perform(req, source_id = source_id, call = call)
  writeBin(httr2::resp_body_raw(resp), tmp)
  list(
    path = tmp,
    content_type = httr2::resp_content_type(resp) %||% NA_character_,
    status = httr2::resp_status(resp)
  )
}

#' Refuse a response that is not the kind of file that was asked for
#'
#' The failure this exists to catch: a server answering a request for a document
#' with an HTML login or error page, status 200. Without this the package would
#' write that page to disk under a `.pdf` name and report success.
#'
#' @noRd
check_download_type <- function(content_type,
                                file_name,
                                url,
                                call = rlang::caller_env()) {
  if (is.na(content_type)) {
    return(invisible(TRUE))
  }
  extension <- tolower(tools::file_ext(file_name))
  looks_html <- grepl("text/html|application/xhtml", content_type, fixed = FALSE)
  wants_html <- extension %in% c("html", "htm", "")

  if (looks_html && !wants_html) {
    knbs_abort(
      c(
        "The source returned a web page instead of a file.",
        "x" = "Asked for {.file {file_name}}, got {.val {content_type}}.",
        "i" = "This usually means an access gate, a login page or an error page.",
        "i" = "Open {.url {url}} in a browser to see what the source is serving."
      ),
      class = "knbs_error_download_failed",
      call = call
    )
  }
  invisible(TRUE)
}

#' SHA-256 of a file
#' @noRd
file_sha256 <- function(path) {
  digest::digest(path, algo = "sha256", file = TRUE)
}

#' Move a completed download into place
#'
#' `file.rename()` is atomic within a filesystem but fails across them, which is
#' the common case here because the temporary directory is often on another
#' volume. The copy-then-delete fallback is not atomic, so it writes to a
#' neighbouring temporary name first and renames within the destination.
#'
#' @noRd
move_into_place <- function(from, to, overwrite = FALSE, call = rlang::caller_env()) {
  if (file.exists(to) && !overwrite) {
    knbs_abort(
      c(
        "{.file {basename(to)}} already exists.",
        "i" = "Use {.code overwrite = TRUE} to replace it.",
        "i" = "Location: {.path {dirname(to)}}."
      ),
      class = "knbs_error_download_failed",
      call = call
    )
  }

  dir <- dirname(to)
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }

  if (suppressWarnings(file.rename(from, to))) {
    return(invisible(to))
  }

  staging <- tempfile(pattern = ".knbs-", tmpdir = dir)
  if (!file.copy(from, staging, overwrite = TRUE)) {
    knbs_abort(
      c("Could not write the download to {.path {dir}}.",
        "i" = "Check that the directory is writable."),
      class = "knbs_error_download_failed",
      call = call
    )
  }
  unlink(from)
  if (!suppressWarnings(file.rename(staging, to))) {
    unlink(staging)
    knbs_abort(
      c("Could not put {.file {basename(to)}} into place."),
      class = "knbs_error_download_failed",
      call = call
    )
  }
  invisible(to)
}

#' Download one file, verify it, and record where it came from
#'
#' @param url Absolute URL.
#' @param destination Directory to write into.
#' @param file_name Name to save as. Defaults to the URL's own basename, so the
#'   official filename is preserved.
#' @param resource_id Resource the file belongs to, recorded in the manifest.
#' @param file_id File identifier, recorded in the manifest.
#' @param source_id Source id.
#' @param overwrite Whether to replace an existing file.
#' @param verify Whether to check the response type before keeping the file.
#' @param sidecar Whether to write `<file>.metadata.json` beside the download.
#' @param quiet Whether to suppress progress messages.
#'
#' @return A one-row tibble in the manifest schema.
#' @noRd
knbs_download_file <- function(url,
                               destination,
                               file_name = NULL,
                               resource_id = NA_character_,
                               file_id = NA_character_,
                               source_id = NA_character_,
                               overwrite = FALSE,
                               verify = TRUE,
                               sidecar = TRUE,
                               quiet = knbs_option("quiet")) {
  check_string(url, "url")
  check_string(destination, "destination")
  check_bool(overwrite, "overwrite")
  check_bool(verify, "verify")

  file_name <- file_name %||% basename(sub("[?#].*$", "", url))
  if (!nzchar(file_name)) {
    knbs_abort(
      c("Could not work out a filename from {.url {url}}.",
        "i" = "Pass {.arg file_name} explicitly."),
      class = "knbs_error_download_failed"
    )
  }

  fetched <- download_to_temp(url, source_id = source_id)
  on.exit(unlink(fetched$path), add = TRUE)

  if (verify) {
    check_download_type(fetched$content_type, file_name, url)
  }

  checksum <- file_sha256(fetched$path)
  size <- file.size(fetched$path)
  target <- file.path(destination, file_name)
  move_into_place(fetched$path, target, overwrite = overwrite)

  record <- tibble::tibble(
    resource_id = resource_id,
    file_id = file_id,
    original_name = file_name,
    local_path = target,
    download_url = url,
    downloaded_at = Sys.time(),
    size_bytes = as.numeric(size),
    sha256 = checksum,
    content_type = fetched$content_type,
    package_version = as.character(utils::packageVersion("knbsdata")),
    source_id = source_id
  )

  if (sidecar) {
    write_sidecar(target, record)
  }
  if (!quiet) {
    cli::cli_alert_success("Downloaded {.file {file_name}} ({pretty_number(size)} bytes).")
  }
  record
}

pretty_number <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)

#' Write the provenance sidecar next to a downloaded file
#'
#' `Economic_Survey_2026.pdf` gets `Economic_Survey_2026.metadata.json`, so the
#' file's origin survives being moved out of an R session (plan section 11.11).
#'
#' @noRd
write_sidecar <- function(path, record) {
  sidecar_path <- paste0(tools::file_path_sans_ext(path), ".metadata.json")
  jsonlite::write_json(
    lapply(as.list(record), function(v) if (inherits(v, "POSIXt")) format(v, "%Y-%m-%dT%H:%M:%S%z") else v),
    sidecar_path,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )
  invisible(sidecar_path)
}

#' Write a manifest describing a set of downloads
#'
#' @param records A tibble of download records.
#' @param destination Directory to write the manifest into.
#' @param name Manifest filename.
#' @noRd
write_manifest <- function(records, destination, name = "knbsdata-manifest.csv") {
  path <- file.path(destination, name)
  if (!dir.exists(destination)) {
    dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  }
  out <- records
  out$downloaded_at <- format(out$downloaded_at, "%Y-%m-%dT%H:%M:%S%z")
  utils::write.csv(as.data.frame(out), path, row.names = FALSE, fileEncoding = "UTF-8")
  invisible(path)
}

# Archive safety --------------------------------------------------------------

#' Reject archive entries that would escape the destination
#'
#' A ZIP entry named `../../etc/passwd` or `C:/Windows/system32/x` would write
#' outside the directory the user asked for. Entries are checked before anything
#' is extracted, and a bad archive is refused whole rather than partially
#' unpacked (plan section 16.6).
#'
#' @param entries Character vector of entry names.
#' @noRd
check_archive_entries <- function(entries, call = rlang::caller_env()) {
  normalised <- gsub("\\\\", "/", entries)
  unsafe <- normalised[
    grepl("^/", normalised) |                 # absolute, unix
      grepl("^[A-Za-z]:", normalised) |       # absolute, windows
      grepl("(^|/)\\.\\.(/|$)", normalised)   # traversal
  ]

  if (length(unsafe) > 0L) {
    knbs_abort(
      c(
        "The archive contains {cli::qty(length(unsafe))}entr{?y/ies} that would write outside the destination.",
        "x" = "{.file {utils::head(unsafe, 5)}}",
        "i" = "Nothing has been extracted."
      ),
      class = "knbs_error_download_failed",
      call = call
    )
  }
  invisible(entries)
}

#' List an archive's entries
#'
#' Separated so that the refusal path can be tested without depending on a zip
#' tool that may normalise away the very entry under test.
#'
#' @noRd
archive_entries <- function(path) {
  utils::unzip(path, list = TRUE)$Name
}

#' Extract an archive, refusing unsafe entries
#'
#' @param path Path to a zip file.
#' @param destination Directory to extract into.
#' @param files Optional entries to extract; defaults to all.
#' @noRd
unzip_safely <- function(path, destination, files = NULL) {
  entries <- archive_entries(path)
  check_archive_entries(entries)

  if (!is.null(files)) {
    unknown <- setdiff(files, entries)
    if (length(unknown) > 0L) {
      knbs_abort(
        c("The archive has no such {cli::qty(length(unknown))}entr{?y/ies}: {.file {unknown}}."),
        class = "knbs_error_resource_not_found"
      )
    }
  }
  utils::unzip(path, files = files, exdir = destination, overwrite = TRUE)
  invisible(file.path(destination, files %||% entries))
}
