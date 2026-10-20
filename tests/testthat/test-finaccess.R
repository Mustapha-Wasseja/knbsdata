# The catalogue ---------------------------------------------------------------

test_that("the shipped catalogue is valid and pins every open file", {
  expect_true(finaccess_registry_valid(finaccess_registry()))

  files <- knbs_finaccess_files()
  expect_s3_class(files, "knbs_catalogue")
  expect_named(files, c("file_id", "title", "survey", "year", "wave", "content",
                        "format", "file_name", "size_bytes", "sha256", "archive",
                        "access", "url", "notes"))
  open <- files[files$access == "open", ]
  expect_true(all(grepl("^[0-9a-f]{64}$", open$sha256)))
  expect_true(all(open$size_bytes > 0))
  expect_true(all(startsWith(open$url, "https://drive.google.com/file/d/")))
  expect_setequal(unique(files$year[files$content == "data"]),
                  c(2006L, 2009L, 2013L, 2016L, 2021L, 2022L, 2023L, 2024L))
  expect_identical(
    knbs_metadata(files)$producer,
    "Central Bank of Kenya, Kenya National Bureau of Statistics and FSD Kenya"
  )
})

test_that("the catalogue records what each link serves, not what it is labelled", {
  mse <- knbs_finaccess_files(survey = "mse_tracker", content = "data")
  # The portal swaps the Wave II formats and has no Wave I Stata file.
  expect_match(mse$file_name[mse$file_id == "mse2023-stata"], "\\.dta$")
  expect_match(mse$file_name[mse$file_id == "mse2023-spss"], "\\.sav$")
  expect_false("mse2022-stata" %in% mse$file_id)
  expect_identical(mse$wave[mse$file_id == "mse2022-spss"], "Wave I")

  # The "Questionnaire" archives of 2006 and 2009 hold the data.
  early <- knbs_finaccess_files(year = c(2006, 2009))
  expect_identical(early$content, c("data", "data"))
  expect_true(all(early$archive))
})

test_that("filters narrow the catalogue and refuse what it does not hold", {
  expect_identical(knbs_finaccess_files(year = 2024, content = "data")$format,
                   c("stata", "spss", "excel"))
  expect_identical(unique(knbs_finaccess_files(format = "pdf")$content),
                   c("questionnaire", "manual", "report"))

  expect_error(knbs_finaccess_files(year = 2019), "2019 heading",
               class = "knbs_error_resource_not_found")
  expect_error(knbs_finaccess_files(year = "2024"), class = "knbs_error_invalid_argument")
  expect_error(knbs_finaccess_files(format = "csv"), class = "knbs_error_invalid_argument")
  expect_error(knbs_finaccess_files(survey = "enterprise"),
               class = "knbs_error_invalid_argument")
})

test_that("a damaged catalogue is caught", {
  registry <- finaccess_registry()
  unpinned <- registry
  unpinned$files[[1]]$sha256 <- "not a checksum"
  expect_false(finaccess_registry_valid(unpinned))

  doubled <- registry
  doubled$files[[2]]$file_id <- doubled$files[[1]]$file_id
  expect_false(finaccess_registry_valid(doubled))

  unreachable <- registry
  unreachable$files[[1]]$drive_id <- NULL
  expect_false(finaccess_registry_valid(unreachable))

  local_mocked_bindings(finaccess_registry_valid = function(...) FALSE)
  expect_error(knbs_finaccess_files(), "catalogue is invalid")
})

# Downloads -------------------------------------------------------------------

test_that("a download is checked before and after, and keeps its official name", {
  dir <- withr::local_tempdir()
  calls <- local_finaccess_drive()

  record <- knbs_download_finaccess("hh2024-stata", dir, quiet = TRUE)

  expect_named(record, c("resource_id", "file_id", "original_name", "local_path",
                         "download_url", "downloaded_at", "size_bytes", "sha256",
                         "content_type", "package_version", "source_id"))
  expect_identical(record$resource_id, "hh2024")
  expect_identical(record$original_name, "FinAccess_2024.dta")
  expect_true(file.exists(file.path(dir, "FinAccess_2024.dta")))
  expect_identical(calls$probe, "driveStata0000000000000")
  expect_identical(calls$download, "driveStata0000000000000")
  expect_match(record$download_url, "^https://drive\\.usercontent\\.google\\.com/")

  sidecar <- jsonlite::read_json(file.path(dir, "FinAccess_2024.dta.metadata.json"))
  expect_identical(sidecar$sha256, record$sha256)
  expect_identical(sidecar$producer, finaccess_test_registry()$producer)
  expect_identical(sidecar$terms, "Pretend terms.")
  expect_identical(sidecar$title, "FinAccess Household Survey 2024: microdata (Stata)")
  expect_true(sidecar$verified)
})

test_that("several files, or the catalogue itself, can be downloaded at once", {
  dir <- withr::local_tempdir()
  calls <- local_finaccess_drive()

  record <- knbs_download_finaccess(knbs_finaccess_files(year = 2024), dir, quiet = TRUE)
  expect_identical(record$file_id, c("hh2024-stata", "hh2024-questionnaire"))
  expect_setequal(calls$download, c("driveStata0000000000000", "drivePdf00000000000000"))

  expect_error(knbs_download_finaccess(data.frame(x = 1), dir),
               class = "knbs_error_invalid_argument")
  expect_error(knbs_download_finaccess(2024, dir), class = "knbs_error_invalid_argument")
})

test_that("a file that has changed is refused before it is downloaded", {
  dir <- withr::local_tempdir()
  served <- finaccess_test_served()
  served$driveStata0000000000000$name <- "FinAccess_2024_revised.dta"
  calls <- local_finaccess_drive(served)

  expect_error(knbs_download_finaccess("hh2024-stata", dir, quiet = TRUE),
               "has changed", class = "knbs_error_validation_failed")
  expect_length(calls$download, 0L)
  expect_length(list.files(dir), 0L)
})

test_that("a download whose checksum differs is not kept", {
  dir <- withr::local_tempdir()
  served <- finaccess_test_served()
  # Same name, same size, different bytes: only the checksum can tell.
  served$driveStata0000000000000$bytes <- charToRaw("pretend stata filX")
  local_finaccess_drive(served)

  expect_error(knbs_download_finaccess("hh2024-stata", dir, quiet = TRUE),
               "checksum", class = "knbs_error_validation_failed")
  expect_length(list.files(dir), 0L)
})

test_that("a web page where a file should be is refused", {
  dir <- withr::local_tempdir()
  served <- finaccess_test_served()
  served$driveStata0000000000000 <- list(name = NA_character_, type = "text/html",
                                         bytes = charToRaw("<html>quota</html>"))
  calls <- local_finaccess_drive(served)

  expect_error(knbs_download_finaccess("hh2024-stata", dir, quiet = TRUE),
               "did not serve", class = "knbs_error_download_failed")
  expect_length(calls$download, 0L)

  # Without verification the page is still caught, after the transfer.
  expect_error(knbs_download_finaccess("hh2024-stata", dir, verify = FALSE, quiet = TRUE),
               class = "knbs_error_download_failed")
  expect_length(list.files(dir), 0L)
})

test_that("verify = FALSE keeps what the link serves now, under its served name", {
  dir <- withr::local_tempdir()
  served <- finaccess_test_served()
  served$driveStata0000000000000 <- list(name = "FinAccess_2024_revised.dta",
                                         bytes = charToRaw("a revised file"))
  calls <- local_finaccess_drive(served)

  record <- knbs_download_finaccess("hh2024-stata", dir, verify = FALSE, quiet = TRUE)
  expect_identical(record$original_name, "FinAccess_2024_revised.dta")
  expect_length(calls$probe, 0L)
  sidecar <- jsonlite::read_json(file.path(dir, "FinAccess_2024_revised.dta.metadata.json"))
  expect_false(sidecar$verified)
})

test_that("an identical copy already downloaded is reused without a request", {
  dir <- withr::local_tempdir()
  calls <- local_finaccess_drive()

  first <- knbs_download_finaccess("hh2024-stata", dir, quiet = TRUE)
  expect_message(second <- knbs_download_finaccess("hh2024-stata", dir, quiet = FALSE),
                 "already downloaded")
  expect_identical(calls$download, "driveStata0000000000000")
  expect_identical(second$sha256, first$sha256)
  expect_lt(abs(as.numeric(second$downloaded_at) - as.numeric(first$downloaded_at)), 1)

  # A copy put there by hand, with the catalogued bytes, gets a sidecar.
  unlink(file.path(dir, "FinAccess_2024.dta.metadata.json"))
  knbs_download_finaccess("hh2024-stata", dir, quiet = TRUE)
  sidecar <- jsonlite::read_json(file.path(dir, "FinAccess_2024.dta.metadata.json"))
  expect_match(unlist(sidecar$notes), "not downloaded")
  expect_identical(calls$download, "driveStata0000000000000")
})

test_that("a different file in the way is left alone unless overwrite = TRUE", {
  dir <- withr::local_tempdir()
  calls <- local_finaccess_drive()
  path <- file.path(dir, "FinAccess_2024.dta")
  writeBin(charToRaw("something else entirely"), path)

  expect_error(knbs_download_finaccess("hh2024-stata", dir, quiet = TRUE),
               "not the catalogued file", class = "knbs_error_download_failed")
  expect_identical(readBin(path, "raw", 100), charToRaw("something else entirely"))
  expect_length(calls$download, 0L)

  record <- knbs_download_finaccess("hh2024-stata", dir, overwrite = TRUE, quiet = TRUE)
  expect_identical(record$sha256, finaccess_test_registry()$files[[1]]$sha256)
})

test_that("a file behind a registration form is refused before anything is fetched", {
  dir <- withr::local_tempdir()
  calls <- local_finaccess_drive()

  expect_error(knbs_download_finaccess(c("hh2024-stata", "hh2013-stata"), dir, quiet = TRUE),
               class = "knbs_error_authentication_required")
  expect_length(calls$probe, 0L)
  expect_length(calls$download, 0L)

  cnd <- rlang::catch_cnd(knbs_download_finaccess("hh2013-stata", dir, quiet = TRUE))
  expect_match(cnd$access_url, "^https://dataverse\\.harvard\\.edu/")
})

test_that("a download must name its destination; nothing goes to the working directory", {
  calls <- local_finaccess_drive()
  expect_error(knbs_download_finaccess("hh2024-stata", quiet = TRUE),
               "destination", class = "knbs_error_invalid_argument")
  expect_error(knbs_download_publication("16624"), "destination",
               class = "knbs_error_invalid_argument")
  expect_length(calls$download, 0L)
})

test_that("an unknown id is refused with the intended file suggested", {
  local_finaccess_drive()
  expect_error(knbs_download_finaccess("hh2024", tempdir(), quiet = TRUE), "survey round",
               class = "knbs_error_resource_not_found")
  expect_error(knbs_download_finaccess("hh2024-stat", tempdir(), quiet = TRUE), "hh2024-stata",
               class = "knbs_error_resource_not_found")
})

test_that("the producers and their terms are named once a session", {
  dir <- withr::local_tempdir()
  local_finaccess_drive()
  local_terms_unshown()
  # Count the terms notices among everything a download says.
  notices <- function(expr) {
    n <- 0L
    withCallingHandlers(expr, message = function(m) {
      if (inherits(m, "knbs_message_terms")) n <<- n + 1L
      invokeRestart("muffleMessage")
    })
    n
  }

  expect_identical(notices(knbs_download_finaccess("hh2024-stata", dir, quiet = TRUE)), 0L)
  again <- function() {
    knbs_download_finaccess("hh2024-stata", dir, overwrite = TRUE, quiet = FALSE)
  }
  expect_identical(notices(again()), 1L)
  expect_identical(notices(again()), 0L)
})

# The source ------------------------------------------------------------------

test_that("the registry routes open downloads here and nothing else", {
  implemented <- adapter_methods("finaccess")
  expect_true(implemented[["source_health"]])
  expect_false(any(implemented[names(implemented) != "source_health"]))

  expect_identical(knbs_sources(operation = "download_public_files")$source_id, "finaccess")
  # The survey catalogue stays with the national data archive.
  expect_identical(resolve_source("files")$source_id, "kenada")
})

test_that("the health check confirms the portal still links every catalogued file", {
  ids <- finaccess_catalogue()$drive_id
  ids <- ids[!is.na(ids)]
  page <- paste0('<a href="https://drive.google.com/file/d/', ids,
                 '/view?usp=sharing">file</a>', collapse = "\n")
  local_mocked_bindings(
    knbs_perform = function(req, ...) {
      httr2::response(status_code = 200L, url = req$url,
                      headers = list(`Content-Type` = "text/html; charset=utf-8"),
                      body = charToRaw(page))
    }
  )

  health <- source_health(knbs_source("finaccess"))
  expect_identical(health$status, "ok")
  expect_match(health$message, paste0("all ", length(ids)))

  page <- sub(ids[[1]], "aDifferentFile000000000", page, fixed = TRUE)
  health <- source_health(knbs_source("finaccess"))
  expect_identical(health$status, "unavailable")
  expect_match(health$message, "no longer links 1")
})

test_that("Drive ids are found in both file and spreadsheet links", {
  html <- paste(
    '<a href="https://drive.google.com/file/d/1FVLHMXH7kbl0hqKVc-ZfluQYN-pp0UZ_/view?usp=sharing">',
    '<a href="https://docs.google.com/spreadsheets/d/1kBfKMxkdPoYKvh9-SgLOaMNhBedn411l/edit">'
  )
  expect_identical(finaccess_page_ids(html),
                   c("1FVLHMXH7kbl0hqKVc-ZfluQYN-pp0UZ_", "1kBfKMxkdPoYKvh9-SgLOaMNhBedn411l"))
})
