# The Knoema adapter (audit F-30). Fixtures are real captured payloads:
# Gross County Product (annual, geographic, 143 series), nominal interest
# rates (annual and quarterly series side by side, F-33) and money supply
# (annual and monthly), plus a three-dataset listing whose structural fields
# tell the F-32 lie deliberately.

test_that("the knoema adapter implements what opendataforafrica declares", {
  implemented <- adapter_methods("knoema")

  expect_true(implemented[["source_search"]])
  expect_true(implemented[["source_fetch"]])
  expect_true(implemented[["source_metadata"]])
  expect_true(implemented[["source_health"]])
  expect_false(implemented[["source_variables"]])
})

test_that("the catalogue lists datasets with honest NA topics", {
  local_cache()
  local_knoema_api()
  catalogue <- knbs_indicators(source = "opendataforafrica")

  expect_named(catalogue, knbs_indicator_list_columns())
  expect_identical(nrow(catalogue), 3L)
  expect_setequal(
    catalogue$indicator_id,
    c("jhbzkjc", "doflnmd", "gvhnvfe")
  )
  # The API states no subject classification, so none is invented.
  expect_true(all(is.na(catalogue$topic)))
})

test_that("the aggregate catalogue now spans four sources", {
  local_cache()
  local_knbsapi()
  combined <- knbs_indicators()

  expect_identical(nrow(combined), 46L)
  expect_setequal(
    unique(combined$source_id),
    c("knbs_indicators", "knbs_cpi", "knbs_opendata", "opendataforafrica", "dhs_program")
  )
})

test_that("an annual geographic dataset becomes tidy integer-year rows", {
  local_cache()
  local_knbsapi()
  gcp <- knbs_get_indicator("jhbzkjc")

  expect_s3_class(gcp, "knbs_indicator")
  expect_identical(nrow(gcp), 1144L)
  expect_type(gcp$period, "integer")
  expect_identical(sort(unique(gcp$period)), 2013:2020)
  expect_true(all(c("table", "table_code", "geo_code", "geo_name") %in% names(gcp)))
  # Members' names in the dimension's own column, their ids in `_code`.
  expect_false("table_label" %in% names(gcp))
  expect_true("County Contribution to Gross Value Added (GVA) (%)" %in% gcp$table)
  expect_identical(length(unique(gcp$table_code)), 3L)
  expect_identical(length(unique(gcp$geo_code)), 48L)
  expect_true("KE" %in% gcp$geo_code)
  # Portal region codes, not census territories; no level is guessed.
  expect_true(all(is.na(gcp$geo_level)))
  # A constant unit ("", here: none) and a constant scale of one are not
  # emitted as columns.
  expect_false("unit" %in% names(gcp))
  expect_false("scale" %in% names(gcp))

  meta <- knbs_metadata(gcp)
  expect_identical(meta$frequency, "annual")
  expect_identical(meta$unit, NA_character_)
  expect_identical(meta$licence, "Public Domain")
  expect_identical(meta$producer, "Kenya National Bureau of Statistics")
  expect_match(meta$source_url, "/jhbzkjc$")
  notes <- paste(meta$notes, collapse = " ")
  expect_match(notes, "Republished by")
  expect_match(notes, "https://www.knbs.or.ke/", fixed = TRUE)
  expect_match(notes, "not census")
})

test_that("series values land on the right coordinates", {
  # Decode raw series by hand and require the standardised table to carry
  # their values at those exact coordinates: the first value of the first
  # series at its start year, and an eighth value at start year plus seven.
  local_cache()
  local_knbsapi()

  raw <- knoema_fixture("gcp-data.json")
  first <- raw$data[[1]]
  want_table <- first$table$id
  want_geo <- first$`administrative-unit`$RegionId
  want_year <- as.integer(substr(first$startDate, 1, 4))
  want_value <- as.numeric(first$values[[1]])

  nairobi <- Filter(
    function(s) {
      identical(s$table$id, "T2") &&
        identical(s$`administrative-unit`$RegionId, "KE-110-NA")
    },
    raw$data
  )[[1]]

  gcp <- knbs_get_indicator("jhbzkjc")
  hit <- gcp[gcp$table_code == want_table & gcp$geo_code == want_geo &
               gcp$period == want_year, ]
  expect_identical(nrow(hit), 1L)
  expect_identical(hit$value, want_value)

  late <- gcp[gcp$table_code == "T2" & gcp$geo_code == "KE-110-NA" &
                gcp$period == want_year + 7L, ]
  expect_identical(late$value, as.numeric(nairobi$values[[8]]))
})

test_that("a geography filter keeps the asked-for codes or is refused", {
  local_cache()
  local_knbsapi()

  kenya <- knbs_get_indicator("jhbzkjc", geo_code = "KE")
  expect_identical(unique(kenya$geo_code), "KE")
  # The contribution-to-GVA table has no national row (shares sum to 100
  # across counties), so KE appears in two of the three tables.
  expect_identical(nrow(kenya), 16L)
  expect_setequal(unique(kenya$table_code), c("T2", "T3"))

  expect_error(
    knbs_get_indicator("gvhnvfe", frequency = "monthly", geo_code = "KE"),
    class = "knbs_error_invalid_query"
  )
  expect_error(
    knbs_get_indicator("gvhnvfe", frequency = "monthly", geo_code = "KE"),
    regexp = "no geography dimension"
  )
})

test_that("a mixed-frequency dataset refuses to pick one silently", {
  local_cache()
  local_knbsapi()

  expect_error(knbs_get_indicator("doflnmd"),
               class = "knbs_error_invalid_query")
  expect_error(knbs_get_indicator("doflnmd"), regexp = "mixes")
  expect_error(knbs_get_indicator("gvhnvfe"), regexp = "mixes")
})

test_that("a frequency choice keeps exactly those series", {
  local_cache()
  local_knbsapi()

  annual <- knbs_get_indicator("doflnmd", frequency = "annual")
  expect_identical(nrow(annual), 54L)
  expect_type(annual$period, "integer")
  expect_identical(sort(unique(annual$period)), 2018:2023)
  expect_identical(length(unique(annual$indicator_code)), 9L)
  expect_identical(knbs_metadata(annual)$unit, "Percent")
  expect_identical(knbs_metadata(annual)$frequency, "annual")
  tbill <- annual[annual$indicator_code == "CBK_91_T" & annual$period == 2018L, ]
  expect_identical(tbill$value, 7.34)

  quarterly <- knbs_get_indicator("doflnmd", frequency = "quarterly")
  expect_identical(nrow(quarterly), 36L)
  expect_s3_class(quarterly$period, "Date")
  expect_setequal(
    unique(quarterly$period_label),
    c("2024-Q1", "2024-Q2", "2024-Q3", "2024-Q4")
  )
  # The quarterly series state no unit; none is inherited from the annual ones.
  expect_identical(knbs_metadata(quarterly)$unit, NA_character_)
  overdraft <- quarterly[quarterly$indicator_code == "C_BANKS_OVER_DRA" &
                           quarterly$period_label == "2024-Q1", ]
  expect_identical(overdraft$period, as.Date("2024-01-01"))
  expect_identical(overdraft$value, 15.97)

  expect_error(knbs_get_indicator("doflnmd", frequency = "monthly"),
               class = "knbs_error_invalid_query")
  expect_error(knbs_get_indicator("doflnmd", frequency = "monthly"),
               regexp = "no monthly")
})

test_that("monthly series carry first-of-month Dates", {
  local_cache()
  local_knbsapi()

  monthly <- knbs_get_indicator("gvhnvfe", frequency = "monthly")
  expect_identical(nrow(monthly), 144L)
  expect_s3_class(monthly$period, "Date")
  expect_identical(min(monthly$period), as.Date("2022-01-01"))
  expect_identical(max(monthly$period), as.Date("2024-12-01"))
  expect_identical(knbs_metadata(monthly)$unit, "KSh Million")
  m1 <- monthly[monthly$indicator_code == "M1" & monthly$period_label == "2022-01", ]
  expect_identical(m1$value, 1768316)

  annual <- knbs_get_indicator("gvhnvfe", frequency = "annual")
  expect_identical(nrow(annual), 24L)
  expect_type(annual$period, "integer")
})

test_that("period bounds work through the public layer", {
  local_cache()
  local_knbsapi()

  window <- knbs_get_indicator("jhbzkjc", start = 2015, end = 2018)
  expect_identical(sort(unique(window$period)), 2015:2018)

  recent <- knbs_get_indicator("gvhnvfe", frequency = "monthly",
                               start = "2024-01")
  expect_true(all(recent$period >= as.Date("2024-01-01")))
})

test_that("unstated bounds trim nothing", {
  # A default window would silently hide the ends of long histories.
  history <- tibble::tibble(period = c(1995L, 2020L), value = c(1, 2))
  open_bounds <- normalise_period_bounds(NULL, NULL)
  expect_false(open_bounds$from_given)
  expect_false(open_bounds$to_given)
  expect_identical(nrow(filter_period_bounds(history, open_bounds)), 2L)

  from_2000 <- normalise_period_bounds(2000, NULL)
  expect_true(from_2000$from_given)
  expect_false(from_2000$to_given)
  expect_identical(filter_period_bounds(history, from_2000)$period, 2020L)

  dates <- tibble::tibble(
    period = as.Date(c("1999-06-01", "2020-06-01")),
    value = c(1, 2)
  )
  expect_identical(nrow(filter_period_bounds(dates, open_bounds)), 2L)
  expect_identical(
    filter_period_bounds(dates, from_2000)$period,
    as.Date("2020-06-01")
  )
})

test_that("the frequency filter is refused where it means nothing", {
  local_cache()
  local_knbsapi()
  expect_error(
    knbs_get_indicator("CPI_ALL_ITEMS", frequency = "monthly"),
    class = "knbs_error_invalid_query"
  )
})

test_that("a null cell becomes NA quietly at its own coordinates", {
  local_cache()
  local_knbsapi()
  doctored <- knoema_fixture("gcp-data.json")
  doctored$data[[1]]$values[3] <- list(NULL)
  local_knoema_api(overrides = list("^2\\.0/data$" = doctored))

  expect_no_warning(gcp <- knbs_get_indicator("jhbzkjc"))
  first <- doctored$data[[1]]
  hole <- gcp[gcp$table_code == first$table$id &
                gcp$geo_code == first$`administrative-unit`$RegionId &
                gcp$period == 2015L, ]
  expect_identical(hole$value, NA_real_)
  expect_identical(sum(is.na(gcp$value)), 1L)
})

test_that("continuation tokens are followed until the dataset is whole", {
  local_cache()
  local_knbsapi()
  raw <- knoema_fixture("rates-data.json")
  seen <- new.env()
  local_knoema_api(overrides = list("^2\\.0/data$" = function(path, query) {
    if (is.null(query$continuationToken)) {
      list(continuationToken = "abc", data = raw$data[1:9])
    } else {
      seen$token <- query$continuationToken
      list(continuationToken = NULL, data = raw$data[10:18])
    }
  }))

  annual <- knbs_get_indicator("doflnmd", frequency = "annual")
  expect_identical(seen$token, "abc")
  expect_identical(nrow(annual), 54L)
  expect_identical(length(unique(annual$indicator_code)), 9L)
})

test_that("the portal's 200-with-a-string answers are classed at the boundary", {
  testthat::local_mocked_bindings(
    knbs_perform = function(req, ...) NULL,
    parse_json_response = function(resp, ...) {
      "Requested dataset doesn't exist or you don't have access to it."
    },
    .package = "knbsdata"
  )
  expect_error(
    knoema_get(knoema_test_source(), "1.0/meta/dataset/zzzznope"),
    class = "knbs_error_resource_not_found"
  )

  testthat::local_mocked_bindings(
    knbs_perform = function(req, ...) NULL,
    parse_json_response = function(resp, ...) "Something unexpected.",
    .package = "knbsdata"
  )
  expect_error(
    knoema_get(knoema_test_source(), "1.0/meta/dataset"),
    class = "knbs_error_schema_changed"
  )
})

test_that("an unknown dataset id is not found", {
  local_cache()
  local_knbsapi()
  expect_error(knbs_get_indicator("zzzznope"),
               class = "knbs_error_resource_not_found")
})

test_that("listing and metadata breakage are schema changes", {
  local_cache()
  local_knoema_api(overrides = list("^1\\.0/meta/dataset$" = list()))
  expect_error(knbs_indicators(source = "opendataforafrica", refresh = TRUE),
               class = "knbs_error_schema_changed")

  duplicated_listing <- list(
    list(id = "same", name = "One"),
    list(id = "same", name = "Two")
  )
  local_knoema_api(overrides = list("^1\\.0/meta/dataset$" = duplicated_listing))
  expect_error(knbs_indicators(source = "opendataforafrica", refresh = TRUE),
               class = "knbs_error_schema_changed")
})

test_that("a series that misstates its own timeline is refused", {
  local_cache()
  local_knbsapi()
  doctored <- knoema_fixture("rates-data.json")
  doctored$data[[1]]$endDate <- "2024-01-01T00:00:00"
  local_knoema_api(overrides = list("^2\\.0/data$" = doctored))

  expect_error(knbs_get_indicator("doflnmd", frequency = "annual"),
               class = "knbs_error_schema_changed")
})

test_that("a dataset without a licence label says so", {
  local_cache()
  unlabelled <- knoema_fixture("gcp-meta.json")
  unlabelled$source$licenseTypeName <- NULL
  local_knoema_api(
    overrides = list("^1\\.0/meta/dataset/jhbzkjc$" = unlabelled)
  )

  meta <- source_metadata(knoema_test_source(), "jhbzkjc")
  expect_identical(meta$licence, "Not stated by the source")
})

test_that("dataset metadata names the producer and dimensions", {
  local_cache()
  local_knoema_api()
  meta <- source_metadata(knoema_test_source(), "jhbzkjc")

  expect_identical(meta$title, "Gross County Product (GCP) 2021")
  expect_identical(meta$producer, "Kenya National Bureau of Statistics")
  expect_identical(meta$licence, "Public Domain")
  notes <- paste(meta$notes, collapse = " ")
  expect_match(notes, "Table, Administrative Unit")
  expect_match(notes, "Republished by")
  expect_match(notes, "next release for 2023-11-18")
})

test_that("a single-member dimension folds into metadata", {
  raw <- knoema_fixture("money-data.json")
  m1_only <- Filter(function(s) identical(s$indicator$id, "M1"), raw$data)
  out <- standardise_knoema_obs(
    m1_only, knoema_fixture("money-meta.json"),
    "gvhnvfe", "opendataforafrica", frequency = "monthly"
  )

  expect_false(any(c("indicator", "indicator_code") %in% names(out$table)))
  expect_match(out$fixed, "Indicator = M1")
  expect_identical(nrow(out$table), 36L)
})

test_that("health reports the listing size", {
  local_knoema_api()
  health <- source_health(knoema_test_source())
  expect_identical(health$status, "ok")
  expect_match(health$message, "3 datasets")
})
