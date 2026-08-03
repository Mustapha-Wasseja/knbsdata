test_that("metadata objects have every documented field", {
  meta <- new_knbs_metadata(title = "Something")

  expect_s3_class(meta, "knbs_metadata")
  expect_true(all(names(knbs_metadata_fields()) %in% names(meta)))
  expect_identical(meta$producer, "Kenya National Bureau of Statistics")
  expect_false(is.null(meta$retrieved_at))
  expect_false(is.null(meta$package_version))
})

test_that("unknown metadata fields are rejected", {
  expect_error(new_knbs_metadata(colour = "blue"), class = "knbs_error_invalid_argument")
  expect_error(new_knbs_metadata("unnamed"), class = "knbs_error_invalid_argument")
})

test_that("knbs_metadata() is the accessor for knbsdata objects", {
  meta <- new_knbs_metadata(title = "Something", resource_id = "X1")
  data <- new_knbs_data(tibble::tibble(a = 1), meta)

  expect_identical(knbs_metadata(data), meta)
  expect_identical(knbs_metadata(meta), meta)
  expect_error(knbs_metadata(tibble::tibble(a = 1)), class = "knbs_error_invalid_argument")
  expect_error(knbs_metadata(42), class = "knbs_error_invalid_argument")
})

test_that("an object stripped of its metadata says so plainly", {
  data <- new_knbs_data(tibble::tibble(a = 1), new_knbs_metadata(title = "X"))
  attr(data, "knbs_metadata") <- NULL

  expect_error(knbs_metadata(data), class = "knbs_error_validation_failed")
  expect_error(knbs_metadata(data), regexp = "lost its metadata")
})

test_that("metadata print without showing empty fields", {
  meta <- new_knbs_metadata(
    title = "Fake index",
    resource_id = "FAKE-CPI",
    release_date = as.Date("2020-04-10"),
    unit = "index"
  )

  out <- capture.output(print(meta))
  expect_true(any(grepl("Fake index", out)))
  expect_true(any(grepl("2020-04-10", out)))
  expect_false(any(grepl("revision_status", out)))
})

test_that("new_knbs_data insists on real metadata", {
  expect_error(
    new_knbs_data(tibble::tibble(a = 1), list(title = "not metadata")),
    class = "knbs_error_invalid_argument"
  )
})

test_that("knbs_data prints a provenance header before the data", {
  data <- new_knbs_data(
    tibble::tibble(period = "2020-01", value = 104.2),
    new_knbs_metadata(title = "Fake index", release_date = as.Date("2020-04-10")),
    class = "knbs_indicator"
  )

  out <- capture.output(print(data))
  expect_true(any(grepl("knbs_indicator", out)))
  expect_true(any(grepl("Fake index", out)))
  expect_true(any(grepl("Rows: 1", out)))
})

test_that("as_tibble strips the knbsdata classes and metadata", {
  data <- new_knbs_data(tibble::tibble(a = 1:2), new_knbs_metadata(title = "X"))
  plain <- tibble::as_tibble(data)

  expect_s3_class(plain, "tbl_df")
  expect_false(inherits(plain, "knbs_data"))
  expect_null(attr(plain, "knbs_metadata"))
})

test_that("summary reports shape and provenance together", {
  data <- new_knbs_data(tibble::tibble(a = 1:3, b = 4:6), new_knbs_metadata(title = "X"))
  s <- summary(data)

  expect_identical(s$rows, 3L)
  expect_identical(s$cols, 2L)
  expect_output(print(s), "3 rows")
})

test_that("metadata survive row subsetting", {
  data <- new_knbs_data(
    tibble::tibble(period = c("2020-01", "2020-02"), value = c(1, 2)),
    new_knbs_metadata(title = "Fake index"),
    class = "knbs_indicator"
  )

  subset <- data[1, ]
  expect_s3_class(subset, "knbs_indicator")
  expect_identical(knbs_metadata(subset)$title, "Fake index")
})
