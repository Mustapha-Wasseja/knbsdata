test_that("knbs_status() returns the documented schema", {
  status <- knbs_status(live = FALSE)

  expect_s3_class(status, "tbl_df")
  expect_named(status, knbs_status_columns())
  expect_identical(nrow(status), nrow(knbs_sources()))
  expect_true(all(status$status %in% knbs_status_values()))
  expect_type(status$http_status, "integer")
  expect_type(status$response_time_ms, "double")
  expect_s3_class(status$checked_at, "POSIXct")
})

test_that("knbs_status(live = FALSE) does not access the network", {
  # Plan section 21.4 lists this as a core test case, and it is the reason the
  # default follows interactive(): package checks must never need a live source.
  local_mocked_bindings(
    nada_get = function(...) stop("knbs_status(live = FALSE) made a request"),
    .package = "knbsdata"
  )

  expect_no_error(knbs_status(live = FALSE))
  expect_false(any(knbs_status(live = FALSE)$status == "ok"))
})

test_that("unverified sources are reported as such and never contacted", {
  status <- knbs_status(live = TRUE, source = c("knbs_publications", "knbs_indicators"))

  # Their endpoints are placeholders, so there is nothing to contact even when
  # a live check is explicitly requested.
  expect_true(all(status$status == "unverified"))
  expect_true(all(is.na(status$http_status)))
  expect_match(status$message[[1]], "nothing to contact")
})

test_that("a verified source is reported as not checked when live is FALSE", {
  status <- knbs_status(source = "kenada", live = FALSE)

  expect_identical(nrow(status), 1L)
  expect_identical(status$status, "not_checked")
  expect_match(status$message, "live = TRUE", fixed = TRUE)
})

test_that("a live check reports a source that answers", {
  local_kenada_api()
  status <- knbs_status(source = "kenada", live = TRUE)

  expect_identical(status$status, "ok")
  expect_identical(status$source_id, "kenada")
  expect_identical(status$operation, "search_surveys")
  expect_false(is.na(status$response_time_ms))
})

test_that("a live check reports a source that fails, without erroring", {
  local_kenada_api(list("catalog/search" = function(path) {
    knbs_abort("The source failed to answer.", class = "knbs_error_source_unavailable")
  }))
  status <- knbs_status(source = "kenada", live = TRUE)

  expect_identical(status$status, "unavailable")
  expect_match(status$message, "failed to answer")
})

test_that("an HTTP failure carries its status through to the report", {
  local_kenada_api(list("catalog/search" = function(path) {
    knbs_abort("Rate limited.", class = "knbs_error_rate_limited", http_status = 429L)
  }))
  status <- knbs_status(source = "kenada", live = TRUE)

  expect_identical(status$status, "unavailable")
  expect_identical(status$http_status, 429L)
})

test_that("an adapter returning nothing useful is reported, not trusted", {
  local_mocked_bindings(
    source_health = function(source, ...) tibble::tibble(),
    .package = "knbsdata"
  )
  status <- knbs_status(source = "kenada", live = TRUE)

  expect_identical(status$status, "unavailable")
  expect_match(status$message, "no health information")
})

test_that("an unrecognised status from an adapter is not passed through", {
  local_mocked_bindings(
    source_health = function(source, ...) {
      tibble::tibble(status = "probably fine", operation = "search_surveys")
    },
    .package = "knbsdata"
  )
  expect_identical(knbs_status(source = "kenada", live = TRUE)$status, "unavailable")
})

test_that("sources can be selected and unknown ids are rejected", {
  expect_identical(nrow(knbs_status(source = "kenada", live = FALSE)), 1L)
  expect_identical(nrow(knbs_status(source = c("kenada", "fake_source"), live = FALSE)), 2L)
  expect_error(knbs_status(source = "no_such_source"), class = "knbs_error_resource_not_found")
})

test_that("arguments are validated", {
  expect_error(knbs_status(live = "yes"), class = "knbs_error_invalid_argument")
  expect_error(knbs_status(timeout = -1), class = "knbs_error_invalid_argument")
  expect_error(knbs_status(source = 42), class = "knbs_error_invalid_argument")
})

test_that("the timeout applies only to the call", {
  withr::local_options(list(knbsdata.timeout = 30))
  local_kenada_api()

  knbs_status(source = "kenada", live = TRUE, timeout = 2)
  expect_identical(knbs_option("timeout"), 30)
})
