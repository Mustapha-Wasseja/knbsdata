# Retail prices from the CPI Explorer (audit F-27). The fixture holds real
# captured records: Petrol 2026-03..06 and Maize Flour 2026-05..06.

test_that("retail prices come back in the documented schema", {
  local_cache()
  local_cpix_api()
  prices <- knbs_retail_prices()

  expect_s3_class(prices, "knbs_prices")
  expect_s3_class(prices, "knbs_data")
  expect_named(prices, c("commodity_code", "commodity", "unit", "quantity",
                         "period", "period_label", "price", "source_id"))
  expect_identical(nrow(prices), 6L)
  expect_s3_class(prices$period, "Date")
  expect_type(prices$price, "double")

  # The commodity register joins the CPI codes on.
  expect_setequal(unique(prices$commodity_code), c("CPI001", "CPI021"))
  petrol_june <- prices[prices$commodity_code == "CPI021" &
                          prices$period_label == "2026-06", ]
  expect_identical(petrol_june$price, 214.95)
  expect_identical(petrol_june$unit, "Litre")
})

test_that("provenance states the currency caveat and licence", {
  local_cache()
  local_cpix_api()
  meta <- knbs_metadata(knbs_retail_prices())

  expect_identical(meta$unit, "KES")
  expect_identical(meta$licence, "Not stated by the source")
  expect_match(paste(meta$notes, collapse = " "), "no regional retail prices")
  expect_match(format(knbs_cite(meta)), "retail prices", fixed = TRUE)
})

test_that("commodities filter by code and by name", {
  local_cache()
  local_cpix_api()

  expect_identical(nrow(knbs_retail_prices(commodity = "CPI021")), 4L)
  expect_identical(nrow(knbs_retail_prices(commodity = "cpi021")), 4L)
  expect_identical(nrow(knbs_retail_prices(commodity = "maize")), 2L)
  expect_identical(nrow(knbs_retail_prices(commodity = c("maize", "petrol"))), 6L)
  expect_identical(nrow(knbs_retail_prices(commodity = "caviar")), 0L)
})

test_that("period bounds filter, and a single month asks the server", {
  local_cache()
  asked <- new.env()
  local_cpix_api(list("^retail-prices/$" = function(path, query) {
    asked$period <- c(asked$period, query$period %||% "<none>")
    cpix_default_handler(NULL, path, query)
  }))

  ranged <- knbs_retail_prices(start = "2026-05", end = "2026-06")
  expect_identical(nrow(ranged), 4L)
  expect_identical(asked$period, "<none>")

  single <- knbs_retail_prices(start = "2026-06", end = "2026-06")
  expect_identical(nrow(single), 2L)
  expect_true("2026-06-01" %in% asked$period)
})

test_that("pagination walks the whole listing", {
  local_cache()
  pages <- new.env()
  pages$asked <- integer(0)
  base <- cpix_fixture("retail-page.json")
  local_cpix_api(list("^retail-prices/$" = function(path, query) {
    page <- as.integer(query$page %||% "1")
    pages$asked <- c(pages$asked, page)
    # Two pages of three records each; count says six.
    chunk <- if (page == 1L) base$results[1:3] else base$results[4:6]
    list(count = 6L, `next` = NULL, previous = NULL, results = chunk)
  }))

  prices <- knbs_retail_prices()
  expect_identical(nrow(prices), 6L)
  expect_identical(pages$asked, c(1L, 2L))
})

test_that("a listing that loses its shape is a schema change", {
  local_cache()
  local_cpix_api(list("^retail-prices/$" = function(path, query) {
    list(rows = list())
  }))
  expect_error(knbs_retail_prices(), class = "knbs_error_schema_changed")

  local_cpix_api(list("^retail-prices/$" = function(path, query) {
    list(count = 1L, results = list(list(surprise = TRUE)))
  }))
  expect_error(knbs_retail_prices(refresh = TRUE),
               class = "knbs_error_schema_changed")
})

test_that("records arriving in any order give the same history", {
  # The live listing stopped arriving sorted by commodity and month (observed
  # 2026-10-15). Interleaving the two commodities is enough to show it.
  local_cache()
  local_cpix_api()
  sorted <- tibble::as_tibble(knbs_retail_prices())

  base <- cpix_fixture("retail-page.json")
  local_cpix_api(list("^retail-prices/$" = function(path, query) {
    list(count = 6L, `next` = NULL, previous = NULL,
         results = base$results[c(1, 5, 2, 6, 3, 4)])
  }))
  interleaved <- knbs_retail_prices(refresh = TRUE)

  expect_identical(tibble::as_tibble(interleaved), sorted)
})

test_that("duplicate commodity-months are refused", {
  local_cache()
  base <- cpix_fixture("retail-page.json")
  local_cpix_api(list("^retail-prices/$" = function(path, query) {
    list(count = 2L, `next` = NULL, previous = NULL,
         results = base$results[c(1, 1)])
  }))
  expect_error(knbs_retail_prices(), class = "knbs_error_validation_failed")
})

test_that("an unknown commodity id keeps its row with an NA code", {
  local_cache()
  base <- cpix_fixture("retail-page.json")
  base$results[[1]]$commodity <- 999L
  local_cpix_api(list("^retail-prices/$" = function(path, query) base))

  prices <- knbs_retail_prices()
  expect_identical(sum(is.na(prices$commodity_code)), 1L)
})

test_that("arguments are validated and the operation is source-checked", {
  expect_error(knbs_retail_prices(commodity = 42),
               class = "knbs_error_invalid_argument")
  expect_error(knbs_retail_prices(start = "sometime"),
               class = "knbs_error_invalid_argument")
  expect_error(
    knbs_retail_prices(source = "kenada"),
    class = "knbs_error_invalid_query"
  )
})

test_that("the range fetch is cached once across different filters", {
  local_cache()
  calls <- new.env()
  calls$n <- 0L
  local_cpix_api(list("^retail-prices/$" = function(path, query) {
    calls$n <- calls$n + 1L
    cpix_default_handler(NULL, path, query)
  }))

  knbs_retail_prices(commodity = "petrol")
  knbs_retail_prices(commodity = "maize", start = 2026)
  expect_identical(calls$n, 1L)
})
