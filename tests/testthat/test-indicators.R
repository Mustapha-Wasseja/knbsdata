test_that("the indicators adapter implements what the registry declares", {
  implemented <- adapter_methods("indicators")

  expect_true(implemented[["source_search"]])
  expect_true(implemented[["source_fetch"]])
  expect_true(implemented[["source_metadata"]])
  expect_true(implemented[["source_health"]])
  # A census API has no survey files or variables to list.
  expect_false(implemented[["source_files"]])
  expect_false(implemented[["source_variables"]])
})

test_that("knbs_indicators() returns the themed catalogue", {
  local_cache()
  local_knbsapi()
  catalogue <- knbs_indicators(source = "knbs_indicators")

  expect_s3_class(catalogue, "knbs_catalogue")
  expect_named(catalogue, knbs_indicator_list_columns())
  expect_identical(nrow(catalogue), 32L)
  expect_true("POPCEN0001" %in% catalogue$indicator_id)
  expect_identical(sort(unique(catalogue$topic)), sort(c(
    "Population", "Health", "ICT", "Household Farming"
  )))
  # Not invented: a census table has no frequency or unit.
  expect_true(all(is.na(catalogue$frequency)))
  expect_true(all(is.na(catalogue$unit)))

  # The default aggregates every verified indicator source.
  combined <- knbs_indicators()
  expect_identical(nrow(combined), 37L)
  expect_setequal(unique(combined$source_id), c("knbs_indicators", "knbs_cpi", "knbs_opendata"))
})

test_that("catalogue filters narrow by topic and text", {
  local_cache()
  local_knbsapi()

  expect_identical(nrow(knbs_indicators(topic = "Population")), 10L)
  expect_identical(nrow(knbs_indicators(topic = "population")), 10L)
  expect_identical(nrow(knbs_indicators(topic = "ICT")), 3L)
  marital <- knbs_indicators(search = "marital")
  expect_identical(marital$indicator_id, "POPCEN0001")
  expect_identical(nrow(knbs_indicators(search = "zzz-nothing")), 0L)
})

test_that("a broken dataset list is a schema change, not a result", {
  local_cache()
  local_knbsapi(list("getDatasetList" = list(list(no_datasets_here = 1))))

  # Asked for that source alone, its own condition survives.
  expect_error(knbs_indicators(source = "knbs_indicators"),
               class = "knbs_error_schema_changed")
  # In the aggregate, the broken source degrades with a warning instead.
  expect_warning(combined <- knbs_indicators(),
                 class = "knbs_warning_partial_failure")
  expect_setequal(unique(combined$source_id), c("knbs_cpi", "knbs_opendata"))
})

test_that("knbs_get_indicator() returns tidy observations", {
  local_cache()
  local_knbsapi()
  pop <- knbs_get_indicator("POPCEN0001")

  expect_s3_class(pop, "knbs_indicator")
  expect_identical(nrow(pop), 24L)
  expect_identical(
    names(pop),
    c("indicator_id", "indicator_name", "period", "value",
      "geo_code", "geo_name", "geo_level", "sex",
      "p18_vs1", "p18_vs1_label", "release_date", "source_id")
  )
  # The reference year comes from the source statement, not from a guess.
  expect_true(all(pop$period == 2019L))
  expect_identical(unique(pop$sex), c("total", "male", "female"))
  expect_type(pop$geo_code, "character")
  expect_true("0101" %in% pop$geo_code)
})

test_that("territory codes map to documented levels", {
  local_cache()
  local_knbsapi()
  pop <- knbs_get_indicator("POPCEN0001")

  expect_identical(unique(pop$geo_level[pop$geo_code == "00"]), "national")
  expect_identical(unique(pop$geo_level[pop$geo_code == "01"]), "county")
  expect_identical(unique(pop$geo_level[pop$geo_code == "47"]), "county")
  expect_identical(unique(pop$geo_level[pop$geo_code == "0101"]), "subcounty")

  expect_identical(census_geo_level(c("00", "07", "0703", "X")),
                   c("national", "county", "subcounty", NA))
})

test_that("geographic filters narrow the observations", {
  local_cache()
  local_knbsapi()

  counties <- knbs_get_indicator("POPCEN0001", geo_level = "county")
  expect_identical(sort(unique(counties$geo_code)), c("01", "47"))

  nairobi <- knbs_get_indicator("POPCEN0001", geo_code = "47")
  expect_identical(nrow(nairobi), 6L)
  expect_identical(unique(nairobi$geo_name), "Nairobi City")

  expect_error(knbs_get_indicator("POPCEN0001", geo_level = "galaxy"),
               class = "knbs_error_invalid_argument")
})

test_that("provenance carries the licence, release and dimensions", {
  local_cache()
  local_knbsapi()
  meta <- knbs_metadata(knbs_get_indicator("POPCEN0001"))

  expect_match(meta$licence, "CC BY 4.0", fixed = TRUE)
  expect_identical(meta$release_date, as.Date("2019-12-31"))
  expect_identical(meta$reference_period, "KNBS Population Census 2019")
  expect_match(meta$notes, "Marital Status", fixed = TRUE)

  citation <- format(knbs_cite(meta))
  expect_match(citation, "Kenya National Bureau of Statistics", fixed = TRUE)
  expect_match(citation, "Miniature fixture table", fixed = TRUE)
})

test_that("names resolve to ids, ambiguously or not", {
  local_cache()
  local_knbsapi()

  by_name <- knbs_get_indicator("Marital Status")
  expect_identical(unique(by_name$indicator_id), "POPCEN0001")

  cnd <- rlang::catch_cnd(knbs_get_indicator("population"))
  expect_s3_class(cnd, "knbs_error_ambiguous_resource")
  expect_gt(length(cnd$matches), 1L)

  expect_error(knbs_get_indicator("zzz-no-such-dataset"),
               class = "knbs_error_resource_not_found")
})

test_that("the API's 200 'errore' answer surfaces as not-found", {
  local_cache()
  local_knbsapi()
  # NO-SUCH-ID passes catalogue resolution only if asked for directly at the
  # adapter layer; the public path resolves names first, so exercise the
  # adapter to pin the errore mapping.
  expect_error(
    source_fetch(indicators_source(),
                 new_knbs_query("indicator", resource_id = "NO-SUCH-ID")),
    class = "knbs_error_resource_not_found"
  )
})

test_that("duplicate keys after standardisation are refused", {
  local_cache()
  payload <- knbsapi_fixture("dataset-small.json")
  # Collapse the territory dimension into repeated codes: same cell twice.
  payload$dimension$system_total$category$index <- list(`00` = 0, `00` = 1, `0101` = 2, `47` = 3)
  local_knbsapi(list("^getDataset$" = payload))

  expect_error(knbs_get_indicator("POPCEN0001", refresh = TRUE),
               class = "knbs_error_validation_failed")
})

test_that("observations are cached and refresh bypasses", {
  local_cache()
  calls <- 0L
  local_knbsapi(list("^getDataset$" = function(path, query) {
    calls <<- calls + 1L
    knbsapi_fixture("dataset-small.json")
  }))

  knbs_get_indicator("POPCEN0001")
  knbs_get_indicator("POPCEN0001")
  expect_identical(calls, 1L)
  knbs_get_indicator("POPCEN0001", refresh = TRUE)
  expect_identical(calls, 2L)
})

test_that("indicator metadata can be fetched without the data shape", {
  local_knbsapi()
  meta <- source_metadata(indicators_source(), "POPCEN0001")

  expect_s3_class(meta, "knbs_metadata")
  expect_identical(meta$resource_id, "POPCEN0001")
  expect_match(meta$licence, "CC BY 4.0", fixed = TRUE)
})

test_that("health reports the census API like any other source", {
  local_knbsapi()
  health <- source_health(indicators_source())
  expect_identical(health$status, "ok")

  local_knbsapi(list("getDatasetList" = function(path, query) {
    knbs_abort("gone", class = "knbs_error_source_unavailable")
  }))
  expect_identical(source_health(indicators_source())$status, "unavailable")
})
