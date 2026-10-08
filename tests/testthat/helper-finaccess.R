# A small FinAccess catalogue and a pretend Google Drive behind it. The
# catalogue pins checksums of the bytes the pretend Drive serves, so the whole
# verify-download-checksum path runs without the network.

finaccess_test_bytes <- function() {
  list(
    stata = charToRaw("pretend stata file"),
    pdf = charToRaw("%PDF-1.7 pretend questionnaire")
  )
}

finaccess_test_registry <- function() {
  bytes <- finaccess_test_bytes()
  sha <- function(x) digest::digest(x, algo = "sha256", serialize = FALSE)
  list(
    schema_version = 1L,
    source_id = "finaccess",
    portal = "https://finaccess.knbs.or.ke/reports-and-datasets",
    checked = "2026-10-08",
    producer = "Central Bank of Kenya, Kenya National Bureau of Statistics and FSD Kenya",
    licence = "Not stated by the source",
    terms = "Pretend terms.",
    surveys = list(household = "FinAccess Household Survey",
                   mse_tracker = "FinAccess MSE Tracker Survey"),
    files = list(
      list(file_id = "hh2024-stata", survey = "household", year = 2024L,
           content = "data", format = "stata", file_name = "FinAccess_2024.dta",
           size_bytes = length(bytes$stata), sha256 = sha(bytes$stata),
           drive_id = "driveStata0000000000000"),
      list(file_id = "hh2024-questionnaire", survey = "household", year = 2024L,
           content = "questionnaire", format = "pdf",
           file_name = "2024 Questionnaire.pdf",
           size_bytes = length(bytes$pdf), sha256 = sha(bytes$pdf),
           drive_id = "drivePdf00000000000000"),
      list(file_id = "hh2013-stata", survey = "household", year = 2013L,
           content = "data", format = "stata", file_name = "FinAccess_2013.dta",
           access = "registration",
           access_url = "https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/JSPE9W")
    )
  )
}

# What the pretend Drive serves, by Drive id. Tests change an entry to stage
# a revised file, a web page or a damaged transfer.
finaccess_test_served <- function() {
  bytes <- finaccess_test_bytes()
  list(
    driveStata0000000000000 = list(name = "FinAccess_2024.dta", bytes = bytes$stata),
    drivePdf00000000000000 = list(name = "2024 Questionnaire.pdf", bytes = bytes$pdf)
  )
}

# Serve `served` in place of Google Drive and return an environment that
# records which ids were probed and downloaded.
local_finaccess_drive <- function(served = finaccess_test_served(), env = parent.frame()) {
  calls <- new.env()
  calls$probe <- character(0)
  calls$download <- character(0)
  id_of <- function(url) sub("^.*[?&]id=([^&]+).*$", "\\1", url)

  testthat::local_mocked_bindings(
    finaccess_registry = function(...) finaccess_test_registry(),
    probe_download = function(url, source_id = NULL, call = NULL) {
      file <- served[[id_of(url)]]
      calls$probe <- c(calls$probe, id_of(url))
      list(file_name = file$name, size_bytes = as.numeric(length(file$bytes)),
           content_type = file$type %||% "application/octet-stream", status = 206L)
    },
    download_to_temp = function(url, source_id = NULL, progress = FALSE, call = NULL) {
      file <- served[[id_of(url)]]
      calls$download <- c(calls$download, id_of(url))
      tmp <- tempfile("knbs-mock-")
      writeBin(file$bytes, tmp)
      list(path = tmp, content_type = file$type %||% "application/octet-stream",
           status = 200L, file_name = file$name)
    },
    .package = "knbsdata",
    .env = env
  )
  calls
}

# Forget, for one test, that the terms notice has been shown this session.
local_terms_unshown <- function(env = parent.frame()) {
  old <- the$finaccess_terms_shown
  the$finaccess_terms_shown <- NULL
  withr::defer(the$finaccess_terms_shown <- old, envir = env)
}

finaccess_fixture <- function(name) {
  testthat::test_path("fixtures", "finaccess", name)
}
