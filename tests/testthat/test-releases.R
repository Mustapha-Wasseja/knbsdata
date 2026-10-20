# Release tracking. The classifier is tested on titles exactly as they appear
# in the KNBS publications library (2026-10-06); the public function on a
# mocked library of such titles.

library_of <- function(titles, dates) {
  base <- wp_fixture("media-listing.json")[[1]] # nolint: object_usage_linter. Defined in helper-wordpress.R.
  out <- lapply(seq_along(titles), function(i) {
    record <- base
    record$id <- 1000L + i
    record$title$rendered <- titles[[i]]
    record$date <- paste0(dates[[i]], "T09:00:00")
    record
  })
  attr(out, "wp_total") <- length(out)
  attr(out, "wp_total_pages") <- 1L
  out
}

local_library <- function(env = parent.frame()) {
  titles <- c(
    "Kenya-Consumer-Price-Indices-and-Inflation-Rates-September-2026",
    "Kenya-Leading-Economic-Indicators-July-2026",
    "KNBS 2026 Career Advertisement",
    "Kenya-Consumer-Price-Indices-and-Inflation-Rates-August-2026",
    "Producer Price Indices Second Quarter-2026",
    "TENDER NO-KNBS-ONT-21-2025-26 FOR SUPPLY AND DELIVERY OF 2TB LAPTOPS",
    "2026 Economic Survey",
    "2025 Informal Cross Border Trade Survey Report",
    "Kenya Highlights of Consumer Price Indices October 2023"
  )
  dates <- c("2026-09-30", "2026-09-22", "2026-09-08", "2026-08-31", "2026-07-20",
             "2026-04-29", "2026-04-29", "2026-08-17", "2023-07-11")
  local_cache(env = env) # nolint: object_usage_linter. Defined in helper-cache.R.
  local_wp_api( # nolint: object_usage_linter. Defined in helper-wordpress.R.
    list("^media$" = library_of(titles, dates)),
    env = env
  )
}

test_that("real KNBS titles fall into their series, notices apart", {
  classified <- release_classify(c(
    "Kenya-Consumer-Price-Indices-and-Inflation-Rates-September-2026",
    "Kenya Highlights of Consumer Price Indices October 2023",
    "Leading Economic Indicators- March 2026",
    "Kenya Residential Proprety Price Index -2026",
    "Kenya-Quarterly-Balance-of-Payment-and-International-Trade-Report-First-Quarter-2026",
    "2024 Statistical Abstract - Garissa County",
    "NA Statistical Abstract_2025 (1)",
    "2026 Economic Survey - Popular version",
    "Speech PS SDEP- 2025 Economic Survey Report Launch",
    "ADVANCE RELEASE CALENDAR FY 2026-2027",
    "TENDER NO-KNBS-ONT-21-2025-26 FOR SUPPLY AND DELIVERY OF 2TB LAPTOPS",
    "February 2026 OPEN ADVERT",
    "2025 National Census for Street Families Report"
  ))
  expect_identical(classified$series_id, c(
    "cpi", "cpi", "lei", "rppi", "qbop", "county_abstract", "abstract",
    "economic_survey", NA, "release_calendar", NA, NA, NA
  ))
  expect_identical(classified$notice, c(rep(FALSE, 10), TRUE, TRUE, FALSE))
})

test_that("a title's month or quarter becomes its period", {
  text <- trimws(gsub("[^a-z0-9]+", " ", tolower(c(
    "Kenya-Consumer-Price-Indices-and-Inflation-Rates-September-2026",
    "Producer Price Indices Second Quarter-2026",
    "Construction-Input-Price-Indices-for-First-Quarter-2026",
    "2026 Economic Survey",
    "ADVANCE RELEASE CALENDAR FY 2026-2027"
  ))))
  expect_identical(release_period(text),
                   c("2026-09", "2026-Q2", "2026-Q1", NA, NA))
})

test_that("the default is the last 30 days, newest first, notices left out", {
  local_library()
  local_mocked_bindings(release_today = function() as.Date("2026-10-06"))
  recent <- knbs_releases()

  expect_s3_class(recent, "knbs_catalogue")
  expect_named(recent, c("release_date", "series", "period", "title", "format",
                         "publication_id", "landing_page", "get"))
  expect_identical(recent$release_date, as.Date(c("2026-09-30", "2026-09-22")))
  expect_identical(recent$period, c("2026-09", "2026-07"))
  expect_match(recent$get, '^knbs_download_publication\\("[0-9]+", destination = "\\."\\)$')
})

test_that("a series returns its history; notices come on request", {
  local_library()

  cpi <- knbs_releases(series = "cpi")
  expect_identical(cpi$period, c("2026-09", "2026-08", "2023-10"))
  expect_identical(nrow(knbs_releases(series = c("CPI", "Economic Survey"))), 4L)

  window <- knbs_releases(since = "2026-08-01", until = as.Date("2026-09-25"))
  expect_true(all(window$release_date >= as.Date("2026-08-01") &
                    window$release_date <= as.Date("2026-09-25")))
  expect_false(any(grepl("Advertisement", window$title)))
  with_notices <- knbs_releases(since = "2026-04-01", notices = TRUE)
  expect_true(any(grepl("Advertisement", with_notices$title)))
  expect_true(any(grepl("^TENDER", with_notices$title)))
  # A one-off report has no series but is still a release.
  expect_true("2025 Informal Cross Border Trade Survey Report" %in% window$title)
})

test_that("bad arguments are refused", {
  local_library()
  expect_error(knbs_releases(series = "nonsense"), class = "knbs_error_invalid_argument")
  expect_error(knbs_releases(since = "last week"), class = "knbs_error_invalid_argument")
  expect_error(knbs_releases(since = "2026-09-01", until = "2026-08-01"),
               class = "knbs_error_invalid_argument")
  expect_error(knbs_releases(notices = "yes"), class = "knbs_error_invalid_argument")
})

test_that("the series list is the classifier's", {
  series <- knbs_release_series()
  expect_named(series, c("series_id", "series", "frequency"))
  expect_true(all(c("cpi", "lei", "qgdp", "economic_survey") %in% series$series_id))
  expect_false(anyDuplicated(series$series_id) > 0L)
})
