test_that("queries validate their arguments", {
  expect_error(new_knbs_query("nonsense"), class = "knbs_error_invalid_argument")
  expect_error(new_knbs_query("indicator", filters = "start"), class = "knbs_error_invalid_argument")
  expect_error(new_knbs_query("indicator", filters = list("2020")), class = "knbs_error_invalid_argument")
  expect_error(new_knbs_query("indicator", release = 2020), class = "knbs_error_invalid_argument")
})

test_that("queries drop empty filters and sort what remains", {
  q <- new_knbs_query(
    "indicator",
    resource_id = "FAKE-CPI",
    filters = list(start = "2020-01", geo_code = NULL, end = "2020-03")
  )

  expect_s3_class(q, "knbs_query")
  expect_named(q$filters, c("end", "start"))
  expect_identical(q$release, "latest")
})

test_that("the canonical form is stable across equivalent queries", {
  a <- new_knbs_query("indicator", filters = list(year = c(2020, 2019)))
  b <- new_knbs_query("indicator", filters = list(year = c("2019", "2020")))
  expect_identical(query_canonical(a), query_canonical(b))
})

test_that("unsupported filters are rejected rather than ignored", {
  q <- new_knbs_query("indicator", filters = list(start = "2020-01", colour = "blue"))

  expect_error(
    check_supported_filters(q, c("start", "end")),
    class = "knbs_error_invalid_query"
  )
  expect_error(
    check_supported_filters(q, c("start", "end")),
    regexp = "colour"
  )
  expect_silent(check_supported_filters(q, c("start", "end", "colour")))
})

test_that("queries print their contents", {
  q <- new_knbs_query("survey", resource_id = "FAKE-SURVEY-001",
                      source = "fake_source", filters = list(search = "household"))
  expect_output(print(q), "survey")
  expect_output(print(q), "FAKE-SURVEY-001")
  expect_output(print(q), "household")
})
