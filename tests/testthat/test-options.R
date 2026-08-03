test_that("defaults are returned when nothing is set", {
  withr::local_options(list(
    knbsdata.cache = NULL,
    knbsdata.timeout = NULL,
    knbsdata.retries = NULL,
    knbsdata.quiet = NULL
  ))

  expect_true(knbs_option("cache"))
  expect_identical(knbs_option("timeout"), 30)
  expect_identical(knbs_option("retries"), 3)
  expect_false(knbs_option("quiet"))
  expect_null(knbs_option("cache_dir"))
  expect_null(knbs_option("user_agent"))
})

test_that("options are read from R options", {
  withr::local_options(list(knbsdata.timeout = 90))
  expect_identical(knbs_option("timeout"), 90)
})

test_that("unknown option names are rejected", {
  expect_error(knbs_option("nonsense"), class = "knbs_error_invalid_argument")
  expect_error(knbs_option(c("cache", "timeout")), class = "knbs_error_invalid_argument")
  expect_error(knbs_option(1), class = "knbs_error_invalid_argument")
})

test_that("knbs_options() with no arguments reports current values", {
  withr::local_options(list(knbsdata.timeout = 5))
  current <- knbs_options()

  expect_type(current, "list")
  expect_named(
    current,
    c("cache", "cache_dir", "timeout", "retries", "user_agent", "quiet")
  )
  expect_identical(current$timeout, 5)
})

test_that("knbs_options() sets options and returns the previous values", {
  withr::local_options(list(knbsdata.timeout = 30, knbsdata.quiet = FALSE))

  old <- knbs_options(timeout = 120, quiet = TRUE)

  expect_named(old, c("timeout", "quiet"))
  expect_identical(old$timeout, 30)
  expect_false(old$quiet)
  expect_identical(getOption("knbsdata.timeout"), 120)
  expect_true(getOption("knbsdata.quiet"))
})

test_that("knbs_options() leaves unsupplied options untouched", {
  withr::local_options(list(knbsdata.timeout = 30, knbsdata.retries = 3))

  knbs_options(timeout = 45)

  expect_identical(knbs_option("timeout"), 45)
  expect_identical(knbs_option("retries"), 3)
})

test_that("knbs_options() validates argument types", {
  expect_error(knbs_options(cache = "yes"), class = "knbs_error_invalid_argument")
  expect_error(knbs_options(timeout = -1), class = "knbs_error_invalid_argument")
  expect_error(knbs_options(retries = "three"), class = "knbs_error_invalid_argument")
  expect_error(knbs_options(quiet = NA), class = "knbs_error_invalid_argument")
  expect_error(knbs_options(user_agent = 42), class = "knbs_error_invalid_argument")
})
