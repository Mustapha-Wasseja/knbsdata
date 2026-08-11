# The CPI Explorer adapter (audit section 1c). The fixtures mirror the live
# service: series arrive with id "overall" and are identified only by
# metadata.region; the "Central" region exists in the region list but carries
# no data (F-26); an unknown region would be answered with the national series
# (F-24), which is the substitution these tests prove the adapter refuses.

test_that("the cpiexplorer adapter implements what knbs_cpi declares", {
  implemented <- adapter_methods("cpiexplorer")

  expect_true(implemented[["source_search"]])
  expect_true(implemented[["source_fetch"]])
  expect_true(implemented[["source_metadata"]])
  expect_true(implemented[["source_health"]])
  expect_false(implemented[["source_variables"]])
})

test_that("the catalogue aggregates census and CPI sources", {
  local_cache()
  local_knbsapi()
  catalogue <- knbs_indicators()

  expect_identical(nrow(catalogue), 40L)
  expect_setequal(
    unique(catalogue$source_id),
    c("knbs_indicators", "knbs_cpi", "knbs_opendata", "opendataforafrica")
  )

  prices <- knbs_indicators(topic = "prices")
  expect_identical(nrow(prices), 3L)
  expect_setequal(
    prices$indicator_id,
    c("CPI_ALL_ITEMS", "CPI_INFLATION_YOY", "CPI_INFLATION_MOM")
  )
  expect_identical(prices$frequency, rep("monthly", 3L))
  expect_identical(prices$unit, c("index", "percent", "percent"))
})

test_that("the plan's headline example works", {
  local_cache()
  local_knbsapi()

  cpi <- knbs_get_indicator("CPI_ALL_ITEMS", start = "2026-04", end = "2026-06")

  expect_s3_class(cpi, "knbs_indicator")
  expect_identical(nrow(cpi), 3L)
  expect_s3_class(cpi$period, "Date")
  expect_identical(cpi$period_label, c("2026-04", "2026-05", "2026-06"))
  expect_identical(cpi$value[[3]], 154.91)
  expect_identical(unique(cpi$geo_code), "national")
  expect_identical(unique(cpi$unit), "index")
  expect_identical(unique(cpi$frequency), "monthly")

  meta <- knbs_metadata(cpi)
  expect_identical(meta$licence, "Not stated by the source")
  expect_match(paste(meta$notes, collapse = " "), "base period", fixed = TRUE)
})

test_that("the inflation variants read their own measure", {
  local_cache()
  local_knbsapi()

  yoy <- knbs_get_indicator("CPI_INFLATION_YOY", start = "2026-04", end = "2026-06")
  mom <- knbs_get_indicator("CPI_INFLATION_MOM", start = "2026-04", end = "2026-06")
  cpi <- knbs_get_indicator("CPI_ALL_ITEMS", start = "2026-04", end = "2026-06")

  expect_identical(unique(yoy$unit), "percent")
  expect_false(identical(yoy$value, cpi$value))
  expect_false(identical(yoy$value, mom$value))
  expect_true(all(abs(mom$value) < 5, na.rm = TRUE))
})

test_that("regions come by code or level, and default to national", {
  local_cache()
  local_knbsapi()

  upper <- knbs_get_indicator("CPI_ALL_ITEMS", geo_code = "1",
                              start = "2026-04", end = "2026-06")
  expect_identical(unique(upper$geo_name), "Nairobi Upper Income")
  expect_identical(unique(upper$geo_level), "region")

  both <- knbs_get_indicator("CPI_ALL_ITEMS", geo_code = c("national", "1"),
                             start = "2026-04", end = "2026-06")
  expect_setequal(unique(both$geo_code), c("national", "1"))

  regions <- knbs_get_indicator("CPI_ALL_ITEMS", geo_level = "region",
                                start = "2026-04", end = "2026-06")
  expect_false("national" %in% regions$geo_code)
})

test_that("an unknown region is refused before any data request", {
  local_cache()
  data_calls <- new.env()
  data_calls$n <- 0L
  local_knbsapi()
  local_cpix_api(list("^explorer/data/$" = function(path, query) {
    data_calls$n <- data_calls$n + 1L
    cpix_default_handler(NULL, path, query)
  }))

  expect_error(
    knbs_get_indicator("CPI_ALL_ITEMS", geo_code = "mars"),
    class = "knbs_error_resource_not_found"
  )
  expect_error(
    knbs_get_indicator("CPI_ALL_ITEMS", geo_code = "mars"),
    regexp = "collection strata"
  )
  expect_identical(data_calls$n, 0L)
})

test_that("a series that was not requested is refused, not relabelled", {
  # F-24: the live endpoint answers unknown regions with the national series.
  local_cache()
  local_knbsapi()
  local_cpix_api(list("^explorer/data/$" = function(path, query) {
    Filter(function(s) s$metadata$region == "National",
           cpix_fixture("data-small.json"))
  }))

  expect_error(
    knbs_get_indicator("CPI_ALL_ITEMS", geo_code = "1",
                       start = "2026-04", end = "2026-06"),
    class = "knbs_error_validation_failed"
  )
  expect_error(
    knbs_get_indicator("CPI_ALL_ITEMS", geo_code = "1",
                       start = "2026-04", end = "2026-06"),
    regexp = "not requested"
  )
})

test_that("a listed region with no data returns zero rows, not an error", {
  # F-26: the former provinces are listed but empty in every period.
  local_cache()
  local_knbsapi()

  central <- knbs_get_indicator("CPI_ALL_ITEMS", geo_code = "6",
                                start = "2026-04", end = "2026-06")
  expect_identical(nrow(central), 0L)
  expect_true(all(c("period", "period_label", "value", "geo_code") %in% names(central)))
})

test_that("change variants request thirteen months of lead-in", {
  # The server computes changes only within the requested window (verified
  # live: a window starting 2026-01 returns NULL year-on-year throughout), so
  # the change variants must ask earlier and trim back.
  local_cache()
  local_knbsapi()
  asked <- new.env()
  local_cpix_api(list("^explorer/data/$" = function(path, query) {
    asked$start <- query$start_date
    cpix_default_handler(NULL, path, query)
  }))

  knbs_get_indicator("CPI_INFLATION_YOY", start = "2026-04", end = "2026-06")
  expect_identical(asked$start, "2025-03-01")

  knbs_get_indicator("CPI_ALL_ITEMS", start = "2026-04", end = "2026-06",
                     refresh = TRUE)
  expect_identical(asked$start, "2026-04-01")
})

test_that("the lead-in is trimmed back to the caller's bounds", {
  local_cache()
  local_knbsapi()

  yoy <- knbs_get_indicator("CPI_INFLATION_YOY", start = "2026-05", end = "2026-06")
  # The fixture spans 2026-04 to 2026-06; only the asked months come back.
  expect_identical(yoy$period_label, c("2026-05", "2026-06"))
})

test_that("date bounds are enforced even if the server ignores them", {
  local_cache()
  local_knbsapi()
  # This handler returns the full fixture span regardless of the dates asked.
  local_cpix_api(list("^explorer/data/$" = function(path, query) {
    Filter(function(s) s$metadata$region == "National",
           cpix_fixture("data-small.json"))
  }))

  narrow <- knbs_get_indicator("CPI_ALL_ITEMS", start = "2026-06", end = "2026-06")
  expect_identical(nrow(narrow), 1L)
  expect_identical(narrow$period_label, "2026-06")
})

test_that("duplicate observations are refused", {
  local_cache()
  local_knbsapi()
  local_cpix_api(list("^explorer/data/$" = function(path, query) {
    series <- Filter(function(s) s$metadata$region == "National",
                     cpix_fixture("data-small.json"))
    series[[1]]$data <- c(series[[1]]$data, series[[1]]$data[1])
    series
  }))

  expect_error(
    knbs_get_indicator("CPI_ALL_ITEMS", start = "2026-04", end = "2026-06"),
    class = "knbs_error_validation_failed"
  )
})

test_that("start and end are validated", {
  expect_error(knbs_get_indicator("CPI_ALL_ITEMS", start = "recently"),
               class = "knbs_error_invalid_argument")
  expect_error(knbs_get_indicator("CPI_ALL_ITEMS", start = "2026-13"),
               class = "knbs_error_invalid_argument")
  expect_error(knbs_get_indicator("CPI_ALL_ITEMS", start = 2026, end = 2020),
               class = "knbs_error_invalid_argument")
})

test_that("period bounds parse years, months and dates", {
  expect_identical(
    normalise_period_bounds(2020, 2021),
    list(from = as.Date("2020-01-01"), to = as.Date("2021-12-01"),
         from_given = TRUE, to_given = TRUE)
  )
  expect_identical(
    normalise_period_bounds("2020-07", "2020-09-15")$to,
    as.Date("2020-09-01")
  )
  # The default window still exists for adapters that need a concrete request
  # start (the CPI Explorer), but it is marked as not caller-given, so it
  # never trims results.
  open_bounds <- normalise_period_bounds(NULL, NULL)
  expect_identical(open_bounds$from, as.Date("2000-01-01"))
  expect_false(open_bounds$from_given)
})

test_that("census indicators still work through the aggregated path", {
  local_cache()
  local_knbsapi()

  pop <- knbs_get_indicator("POPCEN0001", geo_level = "county")
  expect_s3_class(pop, "knbs_indicator")
  expect_true(all(pop$geo_level == "county"))

  # The census year is an integer period; year bounds apply to it.
  expect_identical(nrow(knbs_get_indicator("POPCEN0001", start = 2020,
                                           geo_level = "county")), 0L)
  expect_gt(nrow(knbs_get_indicator("POPCEN0001", start = 2019, end = 2019,
                                    geo_level = "county")), 0L)
})

test_that("an ambiguous name lists candidates across sources", {
  local_cache()
  local_knbsapi()

  cnd <- rlang::catch_cnd(knbs_get_indicator("inflation"), "knbs_error")
  expect_s3_class(cnd, "knbs_error_ambiguous_resource")
  expect_length(cnd$matches, 2L)
})

test_that("one unreachable source degrades the catalogue with a warning", {
  # The CPI listing is package constants and needs no request, so with the
  # census API down the catalogue degrades to the three CPI rows.
  local_cache()
  local_knbsapi(list("." = function(path, query) {
    knbs_abort("Census API down.", class = "knbs_error_source_unavailable")
  }))

  expect_warning(
    catalogue <- knbs_indicators(refresh = TRUE),
    class = "knbs_warning_partial_failure"
  )
  expect_identical(nrow(catalogue), 8L)
  expect_setequal(
    unique(catalogue$source_id),
    c("knbs_cpi", "knbs_opendata", "opendataforafrica")
  )
})

test_that("no source at all is an error", {
  local_cache()
  # The CPI listing cannot fail over the network (it is package constants), so
  # total failure is exercised at the aggregation layer itself.
  local_mocked_bindings(
    source_search = function(source, query, ...) {
      knbs_abort("down", class = "knbs_error_source_unavailable")
    },
    .package = "knbsdata"
  )

  expect_error(knbs_indicators(refresh = TRUE),
               class = "knbs_error_source_unavailable")
})

test_that("indicator metadata and health work", {
  local_cache()
  local_knbsapi()

  meta <- source_metadata(cpi_source(), "CPI_ALL_ITEMS")
  expect_identical(meta$frequency, "monthly")
  expect_identical(meta$reference_period, "2026-01 to 2026-06")
  expect_identical(meta$licence, "Not stated by the source")

  expect_error(source_metadata(cpi_source(), "CPI_NOPE"),
               class = "knbs_error_resource_not_found")
  expect_identical(source_health(cpi_source())$status, "ok")
})
