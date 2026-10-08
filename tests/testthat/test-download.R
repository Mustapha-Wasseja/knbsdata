# The download layer is tested without a server: the one function that touches
# the network is mocked, and everything else works on local files.

local_download <- function(body = "%PDF-1.4 pretend document",
                           content_type = "application/pdf",
                           env = parent.frame()) {
  testthat::local_mocked_bindings(
    download_to_temp = function(url, source_id = NULL, call = NULL) {
      tmp <- tempfile("knbs-mock-")
      writeBin(charToRaw(body), tmp)
      list(path = tmp, content_type = content_type, status = 200L)
    },
    .package = "knbsdata",
    .env = env
  )
}

test_that("a download lands with a checksum and a manifest record", {
  dir <- withr::local_tempdir()
  local_download()

  record <- knbs_download_file(
    "https://example.invalid/reports/Economic_Survey_2026.pdf",
    destination = dir,
    resource_id = "ECONOMIC_SURVEY_2026",
    source_id = "test",
    quiet = TRUE
  )

  expect_true(file.exists(file.path(dir, "Economic_Survey_2026.pdf")))
  expect_identical(record$original_name, "Economic_Survey_2026.pdf")
  expect_identical(record$resource_id, "ECONOMIC_SURVEY_2026")
  expect_match(record$sha256, "^[0-9a-f]{64}$")
  expect_gt(record$size_bytes, 0)
  expect_s3_class(record$downloaded_at, "POSIXct")
})

test_that("the checksum is of the file that was written", {
  dir <- withr::local_tempdir()
  local_download(body = "known contents")

  record <- knbs_download_file("https://example.invalid/x.pdf", dir, quiet = TRUE)
  expect_identical(record$sha256, file_sha256(record$local_path))
})

test_that("the official filename is preserved, query strings and all", {
  dir <- withr::local_tempdir()
  local_download()

  record <- knbs_download_file(
    "https://example.invalid/wp-content/uploads/2026/05/Economic-Survey-2026.pdf?ver=3",
    destination = dir, quiet = TRUE
  )
  expect_identical(record$original_name, "Economic-Survey-2026.pdf")
})

test_that("a web page arriving in place of a document is refused", {
  # The failure this check exists for: a login or error page served with status
  # 200 where a document was requested.
  dir <- withr::local_tempdir()
  local_download(body = "<html>Please sign in</html>", content_type = "text/html")

  expect_error(
    knbs_download_file("https://example.invalid/report.pdf", dir, quiet = TRUE),
    class = "knbs_error_download_failed"
  )
  expect_error(
    knbs_download_file("https://example.invalid/report.pdf", dir, quiet = TRUE),
    regexp = "access gate"
  )
  # Nothing is left behind.
  expect_identical(list.files(dir), character(0))
})

test_that("an HTML file is allowed to be HTML", {
  dir <- withr::local_tempdir()
  local_download(body = "<html>a page</html>", content_type = "text/html")

  expect_no_error(
    knbs_download_file("https://example.invalid/page.html", dir, quiet = TRUE)
  )
})

test_that("verification can be turned off", {
  dir <- withr::local_tempdir()
  local_download(body = "<html>x</html>", content_type = "text/html")

  expect_no_error(
    knbs_download_file("https://example.invalid/report.pdf", dir,
                       verify = FALSE, quiet = TRUE)
  )
})

test_that("an existing file is not silently replaced", {
  dir <- withr::local_tempdir()
  local_download()
  knbs_download_file("https://example.invalid/report.pdf", dir, quiet = TRUE)

  expect_error(
    knbs_download_file("https://example.invalid/report.pdf", dir, quiet = TRUE),
    class = "knbs_error_download_failed"
  )
  expect_no_error(
    knbs_download_file("https://example.invalid/report.pdf", dir,
                       overwrite = TRUE, quiet = TRUE)
  )
})

test_that("a missing destination directory is created", {
  dir <- withr::local_tempdir()
  nested <- file.path(dir, "data", "publications")
  local_download()

  record <- knbs_download_file("https://example.invalid/report.pdf", nested, quiet = TRUE)
  expect_true(file.exists(record$local_path))
})

test_that("a sidecar records where the file came from", {
  dir <- withr::local_tempdir()
  local_download()
  record <- knbs_download_file("https://example.invalid/Economic_Survey_2026.pdf",
                               dir, source_id = "test", quiet = TRUE)

  sidecar <- file.path(dir, "Economic_Survey_2026.pdf.metadata.json")
  expect_true(file.exists(sidecar))

  written <- jsonlite::fromJSON(sidecar, simplifyVector = TRUE)
  expect_identical(written$download_url, record$download_url)
  expect_identical(written$sha256, record$sha256)
  expect_identical(written$source_id, "test")
  expect_false(is.null(written$downloaded_at))
})

test_that("the sidecar can be switched off", {
  dir <- withr::local_tempdir()
  local_download()
  knbs_download_file("https://example.invalid/report.pdf", dir,
                     sidecar = FALSE, quiet = TRUE)

  expect_identical(list.files(dir), "report.pdf")
})

test_that("a manifest is written in the documented schema", {
  dir <- withr::local_tempdir()
  local_download()
  records <- rbind(
    knbs_download_file("https://example.invalid/a.pdf", dir, file_id = "F1", quiet = TRUE),
    knbs_download_file("https://example.invalid/b.pdf", dir, file_id = "F2", quiet = TRUE)
  )

  path <- write_manifest(records, dir)
  expect_true(file.exists(path))

  manifest <- utils::read.csv(path, stringsAsFactors = FALSE)
  expect_identical(nrow(manifest), 2L)
  expect_true(all(c("original_name", "local_path", "download_url", "downloaded_at",
                    "size_bytes", "sha256", "package_version", "source_id") %in%
                    names(manifest)))
  expect_identical(manifest$file_id, c("F1", "F2"))
})

test_that("download failures are classed", {
  dir <- withr::local_tempdir()
  # Mocked so that a mistake here can never become a real request.
  local_download()

  expect_error(knbs_download_file(42, dir), class = "knbs_error_invalid_argument")
  expect_error(knbs_download_file("https://example.invalid/x.pdf", 42),
               class = "knbs_error_invalid_argument")

  # No filename can be derived, and none was supplied.
  expect_error(
    knbs_download_file("https://example.invalid/x.pdf", dir, file_name = ""),
    class = "knbs_error_download_failed"
  )
})

# Archive safety --------------------------------------------------------------

test_that("archive entries that escape the destination are refused", {
  expect_error(check_archive_entries("../../etc/passwd"), class = "knbs_error_download_failed")
  expect_error(check_archive_entries("data/../../escape.csv"), class = "knbs_error_download_failed")
  expect_error(check_archive_entries("/absolute/path.csv"), class = "knbs_error_download_failed")
  expect_error(check_archive_entries("C:/Windows/system32/x.dll"), class = "knbs_error_download_failed")
  expect_error(check_archive_entries("..\\..\\windows\\x"), class = "knbs_error_download_failed")
})

test_that("ordinary archive entries are allowed", {
  expect_no_error(check_archive_entries(c("household.csv", "docs/questionnaire.pdf")))
  # A name that merely contains dots is not traversal.
  expect_no_error(check_archive_entries("my..file.csv"))
})

test_that("a malicious archive is refused whole, not partly extracted", {
  out <- withr::local_tempdir()
  # The listing is mocked rather than built with a zip tool, because the tool
  # may normalise away the traversing entry this test exists to reject.
  local_mocked_bindings(
    archive_entries = function(path) c("household.csv", "../../escape.csv"),
    .package = "knbsdata"
  )

  expect_error(unzip_safely("irrelevant.zip", out), class = "knbs_error_download_failed")
  expect_error(unzip_safely("irrelevant.zip", out), regexp = "Nothing has been extracted")
  expect_identical(list.files(out), character(0))
})

test_that("a safe archive extracts", {
  dir <- withr::local_tempdir()
  out <- withr::local_tempdir()
  writeLines("a,b\n1,2", file.path(dir, "household.csv"))
  zip_path <- file.path(dir, "safe.zip")
  withr::with_dir(dir, suppressWarnings(utils::zip(zip_path, "household.csv", flags = "-q")))
  skip_if(!file.exists(zip_path) || file.size(zip_path) == 0, "zip tool unavailable")

  unzip_safely(zip_path, out)
  expect_true(file.exists(file.path(out, "household.csv")))
})
