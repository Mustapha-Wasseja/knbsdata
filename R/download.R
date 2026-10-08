# Safe downloading ------------------------------------------------------------
#
# Source-independent machinery for retrieving a file and proving what was
# retrieved (plan sections 15.6, 11.9, 11.11 and 16.6). Publications and the
# FinAccess survey files download through it; KeNADA gates its microdata, so
# nothing is fetched from there. It is written and tested separately so that
# when a source permits a download, the download itself is not the risky part.
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
#' that everything around it can be tested without one. The body streams to
#' disk rather than through memory, and a large file is not held to the
#' request timeout, which a 300 MB survey file on a slow line would outlast:
#' the total limit is lifted, and a transfer is abandoned only once it has
#' stalled - moved less than a byte a second - for the timeout's length.
#'
#' @param progress Whether to show a progress bar.
#'
#' @return A list with `path`, `content_type`, `status` and `file_name`, the
#'   name the server gave the file (`NA` if it gave none).
#' @noRd
download_to_temp <- function(url,
                             source_id = NULL,
                             progress = FALSE,
                             call = rlang::caller_env()) {
  tmp <- tempfile("knbs-download-")
  kept <- FALSE
  on.exit(if (!kept) unlink(tmp), add = TRUE)

  stall <- max(1L, as.integer(ceiling(knbs_option("timeout"))))
  req <- httr2::req_options(
    knbs_request(url),
    timeout_ms = 0,
    connecttimeout = stall,
    low_speed_limit = 1L,
    low_speed_time = stall
  )
  if (progress) {
    req <- httr2::req_progress(req, type = "down")
  }
  resp <- knbs_perform(req, source_id = source_id, path = tmp, call = call)

  kept <- TRUE
  list(
    path = tmp,
    content_type = httr2::resp_content_type(resp) %||% NA_character_,
    status = httr2::resp_status(resp),
    file_name = disposition_file_name(httr2::resp_header(resp, "Content-Disposition"))
  )
}

#' Ask a server for a file's name and size without downloading it
#'
#' A request for the first sixteen bytes is answered with the file's served
#' name (Content-Disposition) and its total size (`Content-Range: bytes
#' 0-15/159531918`), so a large download can be held to what was expected
#' before it starts. A server that ignored the range and began sending a
#' large file instead is cut off by curl's size limit at once.
#'
#' @return A list with `file_name`, `size_bytes`, `content_type` and `status`.
#' @noRd
probe_download <- function(url, source_id = NULL, call = rlang::caller_env()) {
  req <- httr2::req_headers(knbs_request(url), Range = "bytes=0-15")
  req <- httr2::req_options(req, maxfilesize = 1048576L)
  resp <- knbs_perform(req, source_id = source_id, call = call)

  status <- httr2::resp_status(resp)
  range <- httr2::resp_header(resp, "Content-Range") %||% ""
  size <- if (grepl("/[0-9]+$", range)) {
    as.numeric(sub("^.*/", "", range))
  } else if (status == 200L) {
    as.numeric(httr2::resp_header(resp, "Content-Length") %||% NA_real_)
  } else {
    NA_real_
  }
  list(
    file_name = disposition_file_name(httr2::resp_header(resp, "Content-Disposition")),
    size_bytes = size,
    content_type = httr2::resp_content_type(resp) %||% NA_character_,
    status = status
  )
}

#' The file name in a Content-Disposition header
#'
#' The percent-encoded UTF-8 form (`filename*=`) wins over the plain one, as
#' RFC 6266 says. Only a bare name is returned: a server-supplied name never
#' decides which directory a file is written to.
#'
#' @return A string, or `NA` if the header names no file.
#' @noRd
disposition_file_name <- function(header) {
  if (is.null(header) || !nzchar(header)) {
    return(NA_character_)
  }
  pick <- function(pattern) {
    hit <- regmatches(header, regexec(pattern, header, ignore.case = TRUE))[[1]]
    if (length(hit) == 2L) trimws(hit[[2]]) else NA_character_
  }
  name <- pick("filename\\*=UTF-8''([^;]+)")
  if (!is.na(name)) {
    name <- utils::URLdecode(name)
    Encoding(name) <- "UTF-8"
  } else {
    name <- pick("filename=\"([^\"]*)\"")
    if (is.na(name)) name <- pick("filename=([^;]+)")
  }
  if (is.na(name)) {
    return(NA_character_)
  }
  name <- basename(gsub("\\\\", "/", name))
  if (!nzchar(name) || name %in% c(".", "..")) NA_character_ else name
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
#' `Economic_Survey_2026.pdf` gets `Economic_Survey_2026.pdf.metadata.json`, so
#' the file's origin survives being moved out of an R session (plan section
#' 11.11). The sidecar is named after the whole file name, extension included:
#' a survey published as `data.dta` and `data.sav` side by side keeps one
#' record per file instead of the second overwriting the first.
#'
#' @noRd
write_sidecar <- function(path, record) {
  path_out <- sidecar_path(path)
  jsonlite::write_json(
    lapply(as.list(record), function(v) if (inherits(v, "POSIXt")) format(v, "%Y-%m-%dT%H:%M:%S%z") else v),
    path_out,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )
  invisible(path_out)
}

#' Where a file's provenance sidecar lives
#' @noRd
sidecar_path <- function(path) {
  paste0(path, ".metadata.json")
}

#' Read the provenance sidecar beside a file
#'
#' Falls back to the stem-named sidecar of earlier versions, but only when it
#' names this very file: a stem-named record may belong to a sibling in
#' another format.
#'
#' @return The sidecar as a list, or `NULL` if there is none that fits.
#' @noRd
read_sidecar <- function(path) {
  read_one <- function(candidate) {
    if (!file.exists(candidate)) {
      return(NULL)
    }
    tryCatch(jsonlite::read_json(candidate, simplifyVector = TRUE),
             error = function(cnd) NULL)
  }
  record <- read_one(sidecar_path(path))
  if (!is.null(record)) {
    return(record)
  }
  legacy <- read_one(paste0(tools::file_path_sans_ext(path), ".metadata.json"))
  if (!is.null(legacy) && identical(legacy$original_name, basename(path))) legacy else NULL
}

#' Parse a sidecar timestamp
#' @noRd
sidecar_time <- function(x) {
  if (!is_string(x)) {
    return(NULL)
  }
  parsed <- as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%S%z", tz = "UTC")
  if (is.na(parsed)) NULL else parsed
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
