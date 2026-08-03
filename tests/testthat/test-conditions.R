test_that("errors carry both the specific and the generic class", {
  expect_error(
    knbs_abort("Nope.", class = "knbs_error_resource_not_found"),
    class = "knbs_error_resource_not_found"
  )
  expect_error(
    knbs_abort("Nope.", class = "knbs_error_resource_not_found"),
    class = "knbs_error"
  )
  expect_error(knbs_abort("Nope."), class = "knbs_error")
})

test_that("warnings carry both the specific and the generic class", {
  expect_warning(
    knbs_warn("Careful.", class = "knbs_warning_provisional_data"),
    class = "knbs_warning_provisional_data"
  )
  expect_warning(knbs_warn("Careful."), class = "knbs_warning")
})

test_that("condition classes must be declared", {
  expect_error(
    knbs_abort("Nope.", class = "knbs_error_made_up"),
    class = "knbs_error_internal"
  )
  expect_error(
    knbs_warn("Careful.", class = "knbs_warning_made_up"),
    class = "knbs_error_internal"
  )
  # An error class is not a valid warning class and vice versa.
  expect_error(
    knbs_warn("Careful.", class = "knbs_error_parse_failed"),
    class = "knbs_error_internal"
  )
})

test_that("messages interpolate from the calling frame", {
  helper <- function() {
    indicator <- "CPI_ALL_ITEMS"
    knbs_abort(
      "Indicator {.val {indicator}} was not found.",
      class = "knbs_error_resource_not_found"
    )
  }
  expect_error(helper(), regexp = "CPI_ALL_ITEMS")
})

test_that("every declared class is unique and namespaced", {
  errors <- knbs_error_classes()
  warnings <- knbs_warning_classes()

  expect_identical(anyDuplicated(c(errors, warnings)), 0L)
  expect_true(all(startsWith(errors, "knbs_error_")))
  expect_true(all(startsWith(warnings, "knbs_warning_")))
})
