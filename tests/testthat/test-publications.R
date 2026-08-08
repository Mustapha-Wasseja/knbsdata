# Adapter ---------------------------------------------------------------------

test_that("the wordpress adapter implements what knbs_publications declares", {
  implemented <- adapter_methods("wordpress")

  expect_true(implemented[["source_search"]])
  expect_true(implemented[["source_metadata"]])
  expect_true(implemented[["source_health"]])
  # A media library has no variables, files-within-studies or indicators.
  expect_false(implemented[["source_fetch"]])
  expect_false(implemented[["source_variables"]])
})

test_that("search standardises media records into the publication schema", {
  local_wp_api()
  results <- source_search(wp_source(), new_knbs_query("publication"))

  expect_s3_class(results, "knbs_catalogue")
  expect_named(results, knbs_publication_columns())
  expect_identical(nrow(results), 3L)
  expect_identical(results$publication_id[[1]], "16624")
  expect_identical(results$format[[2]], "pdf")
  expect_s3_class(results$release_date, "Date")
  expect_true(all(results$access == "open"))
  expect_match(results$download_url[[1]], "^https://www\\.knbs\\.or\\.ke/wp-content/uploads/")
})

test_that("HTML entities in titles are decoded", {
  local_wp_api()
  results <- source_search(wp_source(), new_knbs_query("publication"))

  # The fixture holds "2026 Economic Survey &#8211; Popular version".
  expect_true(any(grepl("Economic Survey - Popular version", results$title, fixed = TRUE)))
  expect_false(any(grepl("&#8211;", results$title, fixed = TRUE)))
})

test_that("the reference year comes from the title, not the upload date", {
  # Audit F-13: the upload date says when a file reached the site, and an old
  # report re-uploaded yesterday would carry yesterday's date.
  expect_identical(title_year("2026 Economic Survey"), 2026L)
  expect_identical(title_year("Kenya Census 1999 Volume II"), 1999L)
  expect_identical(title_year(c("2025 report", "no year here")), c(2025L, NA_integer_))
  expect_identical(title_year(NA_character_), NA_integer_)

  local_wp_api()
  results <- source_search(wp_source(), new_knbs_query("publication"))
  expect_identical(results$year[[1]], 2026L)
})

test_that("an empty listing returns zero rows with the full schema", {
  local_wp_api(list("^media$" = wp_fixture("media-empty.json")))
  results <- source_search(wp_source(), new_knbs_query("publication"))

  expect_identical(nrow(results), 0L)
  expect_named(results, knbs_publication_columns())
})

test_that("a payload that is not media records is a schema change", {
  local_wp_api(list("^media$" = list(list(unexpected = "shape"))))
  expect_error(
    source_search(wp_source(), new_knbs_query("publication")),
    class = "knbs_error_schema_changed"
  )
})

test_that("publication metadata become a metadata object with the raw record", {
  local_wp_api()
  meta <- source_metadata(wp_source(), "16624")

  expect_s3_class(meta, "knbs_metadata")
  expect_identical(meta$resource_id, "16624")
  expect_identical(meta$title, "2026 Economic Survey")
  expect_identical(meta$reference_period, "2026")
  expect_identical(json_chr(meta$raw, "source_url"),
                   "https://www.knbs.or.ke/wp-content/uploads/2026/04/2026-Economic-Survey.pdf")
})

test_that("non-numeric and unknown identifiers are rejected distinctly", {
  local_wp_api()
  expect_error(source_metadata(wp_source(), "economic-survey"),
               class = "knbs_error_invalid_argument")

  # WordPress's own not-found body becomes a not-found condition.
  resp <- fake_response(
    404L,
    headers = list(`Content-Type` = "application/json"),
    body = '{"code":"rest_post_invalid_id","message":"Invalid post ID.","data":{"status":404}}'
  )
  expect_error(wp_body_check(resp, "knbs_publications"),
               class = "knbs_error_resource_not_found")

  forbidden <- fake_response(
    403L,
    headers = list(`Content-Type` = "application/json"),
    body = '{"code":"rest_forbidden","message":"Authentication failed","data":{"status":403}}'
  )
  expect_error(wp_body_check(forbidden, "knbs_publications"),
               class = "knbs_error_access_restricted")
})

test_that("health checks report without erroring", {
  local_wp_api()
  health <- source_health(wp_source())
  expect_identical(health$status, "ok")

  local_wp_api(list("^media$" = function(path, query) {
    knbs_abort("Down.", class = "knbs_error_source_unavailable")
  }))
  expect_identical(source_health(wp_source())$status, "unavailable")
})

# Public functions -------------------------------------------------------------

test_that("knbs_publications returns the documented schema", {
  local_cache()
  local_wp_api()
  pubs <- knbs_publications("economic survey")

  expect_s3_class(pubs, "knbs_catalogue")
  expect_named(pubs, knbs_publication_columns())
  expect_identical(nrow(pubs), 3L)
  expect_identical(knbs_metadata(pubs)$source_id, "knbs_publications")
})

test_that("format and year filters narrow the result", {
  local_cache()
  local_wp_api()

  expect_identical(nrow(knbs_publications(format = "pdf")), 3L)
  expect_identical(nrow(knbs_publications(format = "xlsx")), 0L)
  expect_identical(nrow(knbs_publications(year = 2026)), 2L)
  expect_identical(nrow(knbs_publications(year = c(2025, 2026))), 3L)
  expect_identical(nrow(knbs_publications(year = 1990)), 0L)
  expect_identical(nrow(knbs_publications(limit = 2)), 2L)
})

test_that("arguments are validated", {
  expect_error(knbs_publications(format = "mp3"), class = "knbs_error_invalid_argument")
  expect_error(knbs_publications(limit = 0), class = "knbs_error_invalid_argument")
  expect_error(knbs_publications(limit = 500), class = "knbs_error_invalid_argument")
  expect_error(knbs_publications(year = "recent"), class = "knbs_error_invalid_argument")
})

test_that("publication searches are cached", {
  local_cache()
  calls <- 0L
  local_wp_api(list("^media$" = function(path, query) {
    calls <<- calls + 1L
    wp_fixture("media-listing.json")
  }))

  knbs_publications("economic survey")
  knbs_publications("economic survey")
  expect_identical(calls, 1L)

  knbs_publications("economic survey", refresh = TRUE)
  expect_identical(calls, 2L)
})

test_that("a publication can be cited from its metadata", {
  local_cache()
  local_wp_api()
  citation <- format(knbs_cite(source_metadata(wp_source(), "16624")))

  expect_match(citation, "2026 Economic Survey", fixed = TRUE)
  expect_match(citation, "Kenya National Bureau of Statistics", fixed = TRUE)
})

test_that("downloading fetches the URL from the record and verifies it", {
  local_cache()
  local_wp_api()
  dir <- withr::local_tempdir()
  seen_url <- NULL
  local_mocked_bindings(
    download_to_temp = function(url, source_id = NULL, call = NULL) {
      seen_url <<- url
      tmp <- tempfile()
      writeBin(charToRaw("%PDF-1.7 pretend"), tmp)
      list(path = tmp, content_type = "application/pdf", status = 200L)
    },
    .package = "knbsdata"
  )

  record <- knbs_download_publication("16624", destination = dir, quiet = TRUE)

  expect_identical(seen_url,
                   "https://www.knbs.or.ke/wp-content/uploads/2026/04/2026-Economic-Survey.pdf")
  # The official filename is preserved.
  expect_true(file.exists(file.path(dir, "2026-Economic-Survey.pdf")))
  expect_true(file.exists(file.path(dir, "2026-Economic-Survey.metadata.json")))
  expect_match(record$sha256, "^[0-9a-f]{64}$")
  expect_identical(record$resource_id, "16624")
})

test_that("a download that answers with a web page is refused", {
  local_cache()
  local_wp_api()
  dir <- withr::local_tempdir()
  local_mocked_bindings(
    download_to_temp = function(url, source_id = NULL, call = NULL) {
      tmp <- tempfile()
      writeBin(charToRaw("<html>error page</html>"), tmp)
      list(path = tmp, content_type = "text/html", status = 200L)
    },
    .package = "knbsdata"
  )

  expect_error(
    knbs_download_publication("16624", destination = dir, quiet = TRUE),
    class = "knbs_error_download_failed"
  )
  expect_identical(list.files(dir), character(0))
})

test_that("a record without a download URL fails clearly", {
  local_cache()
  broken <- wp_fixture("media-single.json")
  broken$source_url <- NULL
  local_wp_api(list("^media/[0-9]+$" = broken))

  # The shape check catches the missing field before the download layer would.
  expect_error(
    knbs_download_publication("16624", destination = withr::local_tempdir(), quiet = TRUE),
    class = "knbs_error_schema_changed"
  )
})

# Format-filtered pagination (audit F-22) ------------------------------------
#
# The live server ignores its mime_type parameter, so the format filter is
# client-side — and must page back through older uploads rather than filter
# only the most recent page, where a run of PDFs would hide every workbook.

wp_record <- function(id, mime = "application/pdf") {
  base <- knbsdata:::parse_json_file(
    testthat::test_path("fixtures", "knbs-wp", "media-listing.json")
  )[[1]]
  base$id <- id
  base$mime_type <- mime
  base$title$rendered <- paste0("Document ", id)
  base$filename <- paste0("document-", id, if (mime == "application/pdf") ".pdf" else ".xlsx")
  base$source_url <- paste0("https://www.knbs.or.ke/wp-content/uploads/2026/01/document-", id)
  base
}

wp_page <- function(ids, mimes, total_pages = NA_integer_) {
  page <- Map(wp_record, ids, mimes)
  names(page) <- NULL
  attr(page, "wp_total") <- length(page)
  attr(page, "wp_total_pages") <- as.integer(total_pages)
  page
}

test_that("a format filter pages past a first page with no matches", {
  local_cache()
  served <- new.env(); served$pages <- integer(0)
  # Page 1: 100 PDFs. Page 2: two xlsx among PDFs, and the listing ends.
  local_wp_api(list("^media$" = function(path, query) {
    page <- as.integer(query$page %||% "1")
    served$pages <- c(served$pages, page)
    if (page == 1L) {
      wp_page(1:100, rep("application/pdf", 100), total_pages = 2L)
    } else {
      wp_page(101:150, c(
        rep("application/pdf", 20),
        rep("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", 2),
        rep("application/pdf", 28)
      ), total_pages = 2L)
    }
  }))

  hits <- knbs_publications(format = "xlsx", limit = 10)

  expect_identical(nrow(hits), 2L)
  expect_true(all(hits$format == "xlsx"))
  expect_identical(served$pages, c(1L, 2L))
})

test_that("a short page mid-listing does not end the scan", {
  # The exact shape the live server produced: page 1 came back with 99 rows
  # for per_page=100 while fifteen more pages existed, and the first fix
  # wrongly read the short page as the end. The page count is authoritative.
  local_cache()
  xlsx <- "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  local_wp_api(list("^media$" = function(path, query) {
    page <- as.integer(query$page %||% "1")
    if (page == 1L) {
      wp_page(1:99, rep("application/pdf", 99), total_pages = 2L)
    } else {
      wp_page(100:120, c(xlsx, rep("application/pdf", 20)), total_pages = 2L)
    }
  }))

  hits <- knbs_publications(format = "xlsx", limit = 10)
  expect_identical(nrow(hits), 1L)
})

test_that("pagination stops as soon as the limit is filled", {
  local_cache()
  served <- new.env(); served$pages <- integer(0)
  xlsx <- "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  local_wp_api(list("^media$" = function(path, query) {
    page <- as.integer(query$page %||% "1")
    served$pages <- c(served$pages, page)
    wp_page((page - 1) * 100 + 1:100, rep(xlsx, 100), total_pages = 10L)
  }))

  hits <- knbs_publications(format = "xlsx", limit = 5)

  expect_identical(nrow(hits), 5L)
  expect_identical(served$pages, 1L)
})

test_that("running one page past the end is the end, not an error", {
  local_cache()
  # Exactly one full page exists; page 2 answers the live API's 400.
  local_wp_api(list("^media$" = function(path, query) {
    page <- as.integer(query$page %||% "1")
    if (page > 1L) {
      knbs_abort("Invalid page.", class = "knbs_error_invalid_query")
    }
    wp_page(1:100, rep("application/pdf", 100))
  }))

  expect_no_error(hits <- knbs_publications(format = "xlsx", limit = 10))
  expect_identical(nrow(hits), 0L)
})

test_that("a boundary record repeated across pages is kept once", {
  local_cache()
  xlsx <- "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  local_wp_api(list("^media$" = function(path, query) {
    page <- as.integer(query$page %||% "1")
    if (page == 1L) {
      # Record 100 is xlsx and reappears at the top of page 2 after a shift.
      wp_page(1:100, c(rep("application/pdf", 99), xlsx), total_pages = 2L)
    } else {
      wp_page(c(100, 101:120), c(xlsx, rep("application/pdf", 20)), total_pages = 2L)
    }
  }))

  hits <- knbs_publications(format = "xlsx", limit = 10)
  expect_identical(nrow(hits), 1L)
})

test_that("the scan cap warns rather than trailing off silently", {
  local_cache()
  local_wp_api(list("^media$" = function(path, query) {
    # Endless listing, no matches: 100 declared pages, none carrying xlsx.
    wp_page(1:100, rep("application/pdf", 100), total_pages = 100L)
  }))

  expect_warning(
    hits <- knbs_publications(format = "xlsx", limit = 10),
    class = "knbs_warning_partial_failure"
  )
  expect_identical(nrow(hits), 0L)
})

test_that("an unfiltered search still makes exactly one request", {
  local_cache()
  served <- new.env(); served$pages <- integer(0)
  local_wp_api(list("^media$" = function(path, query) {
    served$pages <- c(served$pages, as.integer(query$page %||% "1"))
    wp_page(1:20, rep("application/pdf", 20))
  }))

  hits <- knbs_publications("anything", limit = 20)
  expect_identical(nrow(hits), 20L)
  expect_identical(served$pages, 1L)
})
