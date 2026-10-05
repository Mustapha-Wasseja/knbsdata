test_that("the nada adapter implements the operations kenada declares", {
  implemented <- adapter_methods("nada")

  expect_true(implemented[["source_search"]])
  expect_true(implemented[["source_metadata"]])
  expect_true(implemented[["source_files"]])
  expect_true(implemented[["source_variables"]])
  expect_true(implemented[["source_health"]])

  # KeNADA publishes no aggregate indicators, so there is nothing to fetch.
  expect_false(implemented[["source_fetch"]])
})

test_that("API urls are built from the registry base url", {
  source <- kenada_source()
  expect_identical(
    nada_url(source, "catalog/search"),
    "https://statistics.knbs.or.ke/nada/index.php/api/catalog/search"
  )
})

test_that("search standardises rows into the survey schema", {
  local_kenada_api()
  results <- source_search(kenada_source(), new_knbs_query("survey"))

  expect_s3_class(results, "knbs_catalogue")
  expect_named(results, knbs_survey_columns())
  expect_identical(nrow(results), 3L)
  expect_identical(results$survey_id[[1]], "DDI-KEN-KNBS-KDHS-2022-V001")
  expect_identical(results$country[[1]], "Kenya")
  expect_s3_class(results$metadata_updated, "Date")

  # form_model "public" is translated, not passed through: it means public-use
  # files exist, not that they can be downloaded.
  expect_identical(results$access_type[[1]], "public_use")

  # The source's own match count travels with the page.
  expect_identical(json_int(knbs_metadata(results)$raw, "found"), 129L)
})

test_that("a year stored as 0 is standardised to NA, never read off the title", {
  # KeNADA stores "0" for studies catalogued without a reference year. One of
  # them is titled "... BUSIA 2016"; its year still stays unknown.
  local_kenada_api(list("catalog/search" = kenada_fixture("catalog-search-year-zero.json")))
  results <- source_search(kenada_source(), new_knbs_query("survey"))
  years <- stats::setNames(results$reference_years, results$survey_id)

  expect_identical(
    unname(years[c("DDI-KEN-KNBS-MSME-2016-v1.0", "KEN-KNBS-KIHBS-2015-2016-v01")]),
    c("2016", "2015-2016")
  )
  unrecorded <- c("DDI-KEN-KNBS-FNS-2013-V01", "DDI-KEN-MOH-SMS-WRK-2016-V001",
                  "KEN-KNBS-KPHC-2019-v01")
  expect_true(all(is.na(years[unrecorded])))
  expect_false("0" %in% results$reference_years)
})

test_that("a year of 0 at either end of a span counts as unrecorded", {
  span <- function(from, to, sep = "-") {
    nada_year_span(list(year_start = from, year_end = to), sep)
  }
  expect_identical(span("0", "0"), NA_character_)
  expect_identical(span("2015", "0"), "2015")
  expect_identical(span("0", "2016"), "2016")
  expect_identical(span("2015", "2016", " to "), "2015 to 2016")
  expect_identical(span("2016", "2016"), "2016")
  expect_identical(nada_year_span(list(), "-"), NA_character_)
})

test_that("a study record with year 0 has no reference period", {
  study <- kenada_fixture("study-metadata.json")
  study$dataset$year_start <- "0"
  study$dataset$year_end <- "0"
  local_kenada_api(list("^catalog/[^/]+$" = study))
  meta <- source_metadata(kenada_source(), "KEN-KNBS-KIHBS-2015-2016-v01")

  expect_identical(meta$reference_period, NA_character_)
})

test_that("an empty catalogue response returns zero rows with the full schema", {
  local_kenada_api(list("catalog/search" = kenada_fixture("catalog-search-empty.json")))
  results <- source_search(kenada_source(), new_knbs_query("survey"))

  expect_identical(nrow(results), 0L)
  expect_named(results, knbs_survey_columns())
})

test_that("study metadata become a knbs_survey object", {
  local_kenada_api()
  meta <- source_metadata(kenada_source(), "KEN-KNBS-KIHBS-2015-2016-v01")

  expect_s3_class(meta, "knbs_survey")
  expect_s3_class(meta, "knbs_metadata")
  expect_identical(meta$resource_id, "KEN-KNBS-KIHBS-2015-2016-v01")
  expect_identical(meta$access, "public_use")
  expect_match(meta$citation, "Kenya Integrated Household Budget Survey", fixed = TRUE)
  expect_identical(meta$variable_count, 463L)
  expect_true(all(c("study_info", "method", "data_access") %in% names(meta$sections)))
})

test_that("variables are standardised and missing documentation is not an error", {
  local_kenada_api()
  variables <- source_variables(kenada_source(), "KEN-KNBS-KIHBS-2015-2016-v01")

  expect_named(variables, knbs_variable_columns())
  expect_identical(variables$variable_name[[1]], "county")
  expect_identical(variables$file_id[[1]], "F19")
  expect_type(variables$value_labels, "list")

  # Audit F-04: several studies are catalogued with no variables at all.
  local_kenada_api(list("/variables$" = list(total = 0, variables = list())))
  empty <- source_variables(kenada_source(), "DDI-KEN-KNBS-KDHS-2022-V001")
  expect_identical(nrow(empty), 0L)
  expect_named(empty, knbs_variable_columns())
})

test_that("data files are standardised and an absent listing is handled", {
  local_kenada_api()
  files <- source_files(kenada_source(), "KEN-KNBS-KIHBS-2015-2016-v01")

  expect_named(files, knbs_file_columns())
  expect_identical(files$file_name[[1]], "HH_Information")
  expect_identical(files$case_count[[1]], 21773L)
  # Nothing at this source may be fetched by the package.
  expect_false(any(files$downloadable))

  # An absent listing arrives as `false`, not as an empty array.
  local_kenada_api(list("data_files" = kenada_fixture("data-files-absent.json")))
  none <- source_files(kenada_source(), "DDI-KEN-KNBS-KDHS-2022-V001")
  expect_identical(nrow(none), 0L)
  expect_named(none, knbs_file_columns())
})

test_that("a study payload arriving from the wrong endpoint is a schema change", {
  # Audit F-08: this API answers unknown subpaths with 200 and the study record
  # rather than a 404. Without a shape check, a renamed endpoint would silently
  # deliver study metadata where variables were expected.
  local_kenada_api(list("/variables$" = kenada_fixture("study-metadata.json")))

  expect_error(
    source_variables(kenada_source(), "KEN-KNBS-KIHBS-2015-2016-v01"),
    class = "knbs_error_schema_changed"
  )
  expect_error(
    source_variables(kenada_source(), "KEN-KNBS-KIHBS-2015-2016-v01"),
    regexp = "endpoint has probably been renamed"
  )
})

test_that("a truncated payload is reported rather than parsed", {
  local_kenada_api(list("catalog/search" = list(result = list(rows = list()))))
  expect_error(
    source_search(kenada_source(), new_knbs_query("survey")),
    class = "knbs_error_schema_changed"
  )
})

test_that("NADA's own not-found message becomes a not-found condition", {
  # A 400 carrying IDNO-NOT-FOUND is a missing resource, not a bad query.
  resp <- fake_response(
    400L,
    headers = list(`Content-Type` = "application/json"),
    body = '{"status":"failed","message":"IDNO-NOT-FOUND"}'
  )
  expect_error(
    nada_body_check(resp, source_id = "kenada"),
    class = "knbs_error_resource_not_found"
  )

  other <- fake_response(
    400L,
    headers = list(`Content-Type` = "application/json"),
    body = '{"status":"failed","message":"SOMETHING-ELSE"}'
  )
  expect_silent(nada_body_check(other, source_id = "kenada"))
})

test_that("variable details fill the per-variable fields", {
  local_kenada_api()
  row <- source_variables(kenada_source(), "KEN-KNBS-KIHBS-2015-2016-v01")[1, ]
  detail <- source_variable_detail(kenada_source(), "KEN-KNBS-KIHBS-2015-2016-v01", "V753")
  filled <- standardise_nada_var_detail(row, detail)

  expect_identical(filled$variable_type, "discrete")
  expect_type(filled$value_labels, "list")
})

test_that("access types are translated into the canonical vocabulary", {
  expect_identical(nada_access_type("public"), "public_use")
  expect_identical(nada_access_type("data_na"), "not_available")
  expect_identical(nada_access_type("licensed"), "licensed")
  expect_identical(nada_access_type(c("open", "direct")), c("open", "direct"))

  # Something the package does not recognise is labelled, never guessed.
  expect_identical(nada_access_type("brand_new_model"), "unknown")
  expect_true(all(nada_access_type(c("public", "data_na")) %in% knbs_access_types()))
})

test_that("health checks report a failing source rather than erroring", {
  local_kenada_api(list("catalog/search" = function(path) {
    knbs_abort("Nope.", class = "knbs_error_source_unavailable")
  }))
  health <- source_health(kenada_source())

  expect_identical(health$status, "unavailable")
  expect_identical(health$source_id, "kenada")
})
