# Retail prices from the KNBS Data Portal (audit F-45), and from the CPI
# Explorer (audit F-27) when asked or when the portal does not answer. The
# Explorer fixture holds real captured records: Petrol 2026-03..06 and Maize
# Flour 2026-05..06; the portal fixture is the whole dataflow.

retail_columns <- c("commodity_code", "coicop_code", "commodity", "unit", "quantity",
                    "period", "period_label", "price", "source_id")

test_that("retail prices come back in the documented schema", {
  local_cache()
  local_cpix_api()
  prices <- knbs_retail_prices(source = "knbs_cpi")

  expect_s3_class(prices, "knbs_prices")
  expect_s3_class(prices, "knbs_data")
  expect_named(prices, retail_columns)
  expect_identical(unique(prices$coicop_code[prices$commodity_code == "CPI021"]), "CP07222100")
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
  meta <- knbs_metadata(knbs_retail_prices(source = "knbs_cpi"))

  expect_identical(meta$unit, "KES")
  expect_identical(meta$licence, "Not stated by the source")
  expect_match(paste(meta$notes, collapse = " "), "no regional retail prices")
  expect_match(format(knbs_cite(meta)), "retail prices", fixed = TRUE)
})

test_that("commodities filter by code and by name", {
  local_cache()
  local_cpix_api()

  expect_identical(nrow(knbs_retail_prices(source = "knbs_cpi", commodity = "CPI021")), 4L)
  expect_identical(nrow(knbs_retail_prices(source = "knbs_cpi", commodity = "cpi021")), 4L)
  expect_identical(nrow(knbs_retail_prices(source = "knbs_cpi", commodity = "maize")), 2L)
  expect_identical(nrow(knbs_retail_prices(source = "knbs_cpi", commodity = c("maize", "petrol"))), 6L)
  expect_identical(nrow(knbs_retail_prices(source = "knbs_cpi", commodity = "caviar")), 0L)
})

test_that("period bounds filter, and a single month asks the server", {
  local_cache()
  asked <- new.env()
  local_cpix_api(list("^retail-prices/$" = function(path, query) {
    asked$period <- c(asked$period, query$period %||% "<none>")
    cpix_default_handler(NULL, path, query)
  }))

  ranged <- knbs_retail_prices(source = "knbs_cpi", start = "2026-05", end = "2026-06")
  expect_identical(nrow(ranged), 4L)
  expect_identical(asked$period, "<none>")

  single <- knbs_retail_prices(source = "knbs_cpi", start = "2026-06", end = "2026-06")
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

  prices <- knbs_retail_prices(source = "knbs_cpi")
  expect_identical(nrow(prices), 6L)
  expect_identical(pages$asked, c(1L, 2L))
})

test_that("a listing that loses its shape is a schema change", {
  local_cache()
  local_cpix_api(list("^retail-prices/$" = function(path, query) {
    list(rows = list())
  }))
  expect_error(knbs_retail_prices(source = "knbs_cpi"), class = "knbs_error_schema_changed")

  local_cpix_api(list("^retail-prices/$" = function(path, query) {
    list(count = 1L, results = list(list(surprise = TRUE)))
  }))
  expect_error(knbs_retail_prices(source = "knbs_cpi", refresh = TRUE),
               class = "knbs_error_schema_changed")
})

test_that("records arriving in any order give the same history", {
  # The live listing stopped arriving sorted by commodity and month (observed
  # 2026-10-15). Interleaving the two commodities is enough to show it.
  local_cache()
  local_cpix_api()
  sorted <- tibble::as_tibble(knbs_retail_prices(source = "knbs_cpi"))

  base <- cpix_fixture("retail-page.json")
  local_cpix_api(list("^retail-prices/$" = function(path, query) {
    list(count = 6L, `next` = NULL, previous = NULL,
         results = base$results[c(1, 5, 2, 6, 3, 4)])
  }))
  interleaved <- knbs_retail_prices(source = "knbs_cpi", refresh = TRUE)

  expect_identical(tibble::as_tibble(interleaved), sorted)
})

test_that("duplicate commodity-months are refused", {
  local_cache()
  base <- cpix_fixture("retail-page.json")
  local_cpix_api(list("^retail-prices/$" = function(path, query) {
    list(count = 2L, `next` = NULL, previous = NULL,
         results = base$results[c(1, 1)])
  }))
  expect_error(knbs_retail_prices(source = "knbs_cpi"), class = "knbs_error_validation_failed")
})

test_that("an unknown commodity id keeps its row with an NA code", {
  local_cache()
  base <- cpix_fixture("retail-page.json")
  base$results[[1]]$commodity <- 999L
  local_cpix_api(list("^retail-prices/$" = function(path, query) base))

  prices <- knbs_retail_prices(source = "knbs_cpi")
  expect_identical(sum(is.na(prices$commodity_code)), 1L)
})

test_that("arguments are validated and the operation is source-checked", {
  expect_error(knbs_retail_prices(source = "knbs_cpi", commodity = 42),
               class = "knbs_error_invalid_argument")
  expect_error(knbs_retail_prices(source = "knbs_cpi", start = "sometime"),
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

  knbs_retail_prices(source = "knbs_cpi", commodity = "petrol")
  knbs_retail_prices(source = "knbs_cpi", commodity = "maize", start = 2026)
  expect_identical(calls$n, 1L)
})

# The Data Portal ---------------------------------------------------------------

test_that("the Data Portal answers first, with every commodity in the Explorer's terms", {
  local_cache()
  local_retail_portal()
  prices <- knbs_retail_prices()

  expect_s3_class(prices, "knbs_prices")
  expect_named(prices, retail_columns)
  expect_true(all(prices$source_id == "knbs_opendata"))
  # The cube's empty item x pack cells are gone: 22 commodities x 90 months.
  expect_identical(nrow(prices), 22L * 90L)
  expect_setequal(unique(prices$commodity_code), sprintf("CPI%03d", 1:22))
  expect_identical(format(range(prices$period)), c("2019-02-01", "2026-07-01"))
  expect_identical(knbs_metadata(prices)$source_id, "knbs_opendata")
  expect_match(paste(knbs_metadata(prices)$notes, collapse = " "), "DF_CPI_NA", fixed = TRUE)

  # The two packs the portal labels alike are the salad oil and the cooking
  # fat; the June 2026 CPI release prints the oil at 358.63.
  june <- prices[prices$period_label == "2026-06", ]
  oil <- june[june$commodity_code == "CPI010", ]
  expect_identical(c(oil$commodity, oil$unit), c("Cooking Oil (Salad)", "Litre"))
  expect_identical(round(oil$price, 2), 358.63)
  expect_identical(june$unit[june$commodity_code == "CPI009"], "Gram")
})

test_that("the two sources publish the same figures", {
  local_cache()
  local_retail_portal()
  local_cpix_api()
  portal <- knbs_retail_prices(source = "knbs_opendata")
  explorer <- knbs_retail_prices(source = "knbs_cpi")

  key <- function(x) paste(x$commodity_code, x$period_label)
  both <- portal[key(portal) %in% key(explorer), ]
  expect_identical(nrow(both), nrow(explorer))
  matched <- explorer$price[match(key(both), key(explorer))]
  # The Explorer rounds to two decimals; the portal does not.
  expect_identical(round(both$price, 2), matched)
  at <- match(key(both), key(explorer))
  for (column in c("commodity", "coicop_code", "unit", "quantity")) {
    expect_identical(both[[column]], explorer[[column]][at], info = column)
  }
})

test_that("a CPI Explorer that does not answer is not missed", {
  local_cache()
  local_retail_portal()
  local_cpix_api(list("." = function(path, query) stop("The Explorer was asked.")))
  expect_no_error(knbs_retail_prices())
})

test_that("if the Data Portal does not answer, the CPI Explorer does, and a message says so", {
  local_cache()
  local_hub_api(get_overrides = list("^catalog$" = function(path) {
    knbs_abort("Could not reach the source.", class = "knbs_error_source_unavailable")
  }))
  local_cpix_api()

  expect_message(prices <- knbs_retail_prices(), class = "knbs_message_fallback")
  expect_true(all(prices$source_id == "knbs_cpi"))
  expect_identical(nrow(prices), 6L)
})

test_that("if neither answers, the error names both", {
  local_cache()
  local_hub_api(get_overrides = list("^catalog$" = function(path) {
    knbs_abort("The source refused access to this resource.",
               class = "knbs_error_access_restricted")
  }))
  local_cpix_api(list("." = function(path, query) {
    knbs_abort("Could not reach the source.", class = "knbs_error_source_unavailable")
  }))

  cnd <- expect_error(knbs_retail_prices(), class = "knbs_error_source_unavailable")
  text <- cli::ansi_strip(conditionMessage(cnd))
  expect_match(text, "knbs_opendata: The source refused access", fixed = TRUE)
  expect_match(text, "knbs_cpi: Could not reach", fixed = TRUE)
})

test_that("a changed dataflow is reported, not hidden by the other source", {
  local_cache()
  local_retail_portal(post_overrides = list("DF_CPI_NA" = hub_fixture("gdp-data.json")))
  local_cpix_api()
  expect_error(knbs_retail_prices(), class = "knbs_error_schema_changed")
})

test_that("a pack the register does not know keeps its row and the portal's labels", {
  local_cache()
  payload <- hub_fixture("cpina-data.json")
  item <- payload$dimension$ITEM_PRICE$category
  at <- which(unlist(item$index) == "CP07222100")
  item$index[[at]] <- "CP07222199"
  item$label[["CP07222199"]] <- item$label[["CP07222100"]]
  item$label[["CP07222100"]] <- NULL
  payload$dimension$ITEM_PRICE$category <- item
  local_retail_portal(post_overrides = list("DF_CPI_NA" = payload))

  prices <- knbs_retail_prices()
  stray <- prices[prices$coicop_code == "CP07222199", ]
  expect_identical(nrow(stray), 90L)
  expect_true(all(is.na(stray$commodity_code)))
  expect_identical(unique(stray$commodity), "Petrol")
  expect_identical(unique(stray$unit), "Litre")
  expect_identical(unique(stray$quantity), 1)
})

test_that("the portal's prices filter by month and by COICOP code", {
  local_cache()
  local_retail_portal()
  expect_identical(nrow(knbs_retail_prices(start = "2026-06", end = "2026-06")), 22L)
  expect_identical(nrow(knbs_retail_prices(commodity = "CP07222100")), 90L)
  expect_identical(nrow(knbs_retail_prices(commodity = "petrol", start = 2026)), 7L)
})
