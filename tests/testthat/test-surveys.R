test_that("survey search returns the documented schema", {
  local_cache()
  local_kenada_api()
  results <- knbs_search_surveys("household")

  expect_s3_class(results, "knbs_catalogue")
  expect_named(results, knbs_survey_columns())
  expect_identical(nrow(results), 3L)
  expect_identical(knbs_metadata(results)$source_id, "kenada")
})

test_that("search filters the source cannot apply are applied locally", {
  local_cache()
  local_kenada_api()

  expect_identical(nrow(knbs_search_surveys(access = "public_use")), 3L)
  expect_identical(nrow(knbs_search_surveys(access = "licensed")), 0L)
  expect_identical(nrow(knbs_search_surveys(producer = "Kenya National Bureau")), 3L)
  expect_identical(nrow(knbs_search_surveys(producer = "Nowhere Institute")), 0L)
  expect_identical(nrow(knbs_search_surveys(limit = 2)), 2L)
})

test_that("search validates its arguments", {
  expect_error(knbs_search_surveys(query = 42), class = "knbs_error_invalid_argument")
  expect_error(knbs_search_surveys(access = "free"), class = "knbs_error_invalid_argument")
  expect_error(knbs_search_surveys(limit = 0), class = "knbs_error_invalid_argument")
  expect_error(knbs_search_surveys(year = "2015"), class = "knbs_error_invalid_argument")
  expect_error(knbs_search_surveys(year = c(2015, 2016, 2017)), class = "knbs_error_invalid_argument")
})

test_that("a year or a range both work", {
  expect_identical(normalise_year_range(NULL), list(from = NULL, to = NULL))
  expect_identical(normalise_year_range(2015), list(from = 2015L, to = 2015L))
  expect_identical(normalise_year_range(c(2020, 2015)), list(from = 2015L, to = 2020L))
})

test_that("a year filter excludes studies with no recorded year, and says how many", {
  # The live archive answers a 2016 search with every study it stores year 0
  # for; the fixture keeps three of them beside the two genuine matches.
  local_cache()
  local_kenada_api(list("catalog/search" = kenada_fixture("catalog-search-year-zero.json")))

  expect_warning(
    results <- knbs_search_surveys(year = 2016),
    class = "knbs_warning_missing_metadata"
  )
  expect_identical(
    results$survey_id,
    c("DDI-KEN-KNBS-MSME-2016-v1.0", "KEN-KNBS-KIHBS-2015-2016-v01")
  )

  cnd <- rlang::catch_cnd(knbs_search_surveys(year = 2016), "knbs_warning_missing_metadata")
  expect_match(conditionMessage(cnd), "Excluded 3 studies", fixed = TRUE)
  expect_setequal(
    cnd$excluded,
    c("DDI-KEN-KNBS-FNS-2013-V01", "DDI-KEN-MOH-SMS-WRK-2016-V001", "KEN-KNBS-KPHC-2019-v01")
  )

  # Only studies the other filters would have kept are counted.
  cnd <- rlang::catch_cnd(
    knbs_search_surveys(year = 2016, producer = "Kenya National Bureau"),
    "knbs_warning_missing_metadata"
  )
  expect_match(conditionMessage(cnd), "Excluded 2 studies", fixed = TRUE)
})

test_that("without a year filter, studies with no recorded year are kept", {
  local_cache()
  local_kenada_api(list("catalog/search" = kenada_fixture("catalog-search-year-zero.json")))

  expect_no_warning(results <- knbs_search_surveys())
  expect_identical(nrow(results), 5L)
  expect_identical(sum(is.na(results$reference_years)), 3L)
})

test_that("a year filter leaves studies with recorded years as they were", {
  local_cache()
  local_kenada_api()

  # Every study in this fixture has its year recorded: nothing to report.
  expect_no_warning(results <- knbs_search_surveys(year = 2021))
  expect_identical(
    results$survey_id,
    c("DDI-KEN-KNBS-FHS-2021-V01", "DDI-KEN-KNBS-KTUS-2021-V001")
  )
  expect_identical(results$reference_years, c("2021", "2021"))
  expect_no_warning(wide <- knbs_search_surveys(year = c(2015, 2025)))
  expect_identical(nrow(wide), 3L)
})

test_that("a study spanning several years matches any year it covers", {
  local_cache()
  local_kenada_api(list("catalog/search" = kenada_fixture("catalog-search-year-zero.json")))

  spanning <- suppressWarnings(knbs_search_surveys(year = 2015))
  expect_identical(spanning$survey_id, "KEN-KNBS-KIHBS-2015-2016-v01")
  expect_identical(spanning$reference_years, "2015-2016")

  expect_identical(
    survey_years_overlap(c("2016", "2015-2016", NA, "2010"), 2016L, 2018L),
    c(TRUE, TRUE, NA, FALSE)
  )
})

test_that("a year-filtered page short of the source's matches is widened first", {
  # Otherwise `limit` would cut the page before the unrecorded studies are
  # counted, and the warning would undercount them.
  local_cache()
  full <- kenada_fixture("catalog-search-year-zero.json")
  page_sizes <- character(0)
  testthat::local_mocked_bindings(
    nada_get = function(source, path, query = list(), call = NULL) {
      page_sizes <<- c(page_sizes, query$ps)
      page <- full
      page$result$rows <- page$result$rows[seq_len(min(as.integer(query$ps), 5L))]
      page
    },
    .package = "knbsdata"
  )

  cnd <- rlang::catch_cnd(knbs_search_surveys(year = 2016, limit = 1),
                          "knbs_warning_missing_metadata")
  # The first page held one of the five matches, so all five were asked for.
  expect_identical(page_sizes, c("1", "5"))
  expect_length(cnd$excluded, 3L)

  results <- suppressWarnings(knbs_search_surveys(year = 2016, limit = 1))
  expect_identical(results$survey_id, "DDI-KEN-KNBS-MSME-2016-v1.0")
  # The widened answer was cached under the original query.
  expect_identical(page_sizes, c("1", "5"))

  # Without a year filter nothing is dropped, so the page is not widened.
  knbs_search_surveys(limit = 1)
  expect_identical(page_sizes, c("1", "5", "1"))
})

test_that("survey metadata come back as a printable knbs_survey", {
  local_cache()
  local_kenada_api()
  meta <- knbs_survey_metadata("KEN-KNBS-KIHBS-2015-2016-v01")

  expect_s3_class(meta, "knbs_survey")
  expect_identical(meta$access, "public_use")

  out <- capture.output(print(meta))
  expect_true(any(grepl("KEN-KNBS-KIHBS-2015-2016-v01", out)))
  # The print method must not let "public use" be read as "freely downloadable".
  expect_true(any(grepl("requires an account", out)))
})

test_that("include keeps only the requested sections", {
  local_cache()
  local_kenada_api()

  all_sections <- knbs_survey_metadata("KEN-KNBS-KIHBS-2015-2016-v01")
  access_only <- knbs_survey_metadata("KEN-KNBS-KIHBS-2015-2016-v01", include = "access")

  expect_true("study_info" %in% names(all_sections$sections))
  expect_false("study_info" %in% names(access_only$sections))
  expect_true("data_access" %in% names(access_only$sections))
})

test_that("a study can be cited straight from its metadata", {
  local_cache()
  local_kenada_api()
  citation <- format(knbs_cite(knbs_survey_metadata("KEN-KNBS-KIHBS-2015-2016-v01")))

  # The source states its own required citation, which must win.
  expect_match(citation, "2015-2016 Kenya Integrated Household Budget Survey", fixed = TRUE)
  expect_match(citation, "knbsdata version", fixed = TRUE)
})

test_that("an unknown identifier falls back to searching the catalogue", {
  local_cache()
  # The source rejects the identifier, so the catalogue is searched instead. The
  # search fixture holds three studies, which is ambiguous. The search override
  # comes first because the handler takes the first matching pattern.
  local_kenada_api(list(
    "^catalog/search$" = kenada_fixture("catalog-search.json"),
    "^catalog/[^/]+$" = function(path) {
      knbs_abort("no", class = "knbs_error_resource_not_found")
    }
  ))

  expect_error(
    knbs_survey_metadata("household"),
    class = "knbs_error_ambiguous_resource"
  )
  cnd <- rlang::catch_cnd(knbs_survey_metadata("household"))
  expect_length(cnd$matches, 3L)
})

test_that("an identifier matching nothing is reported as not found", {
  local_cache()
  local_kenada_api(list(
    "^catalog/search$" = kenada_fixture("catalog-search-empty.json"),
    "^catalog/[^/]+$" = function(path) knbs_abort("no", class = "knbs_error_resource_not_found")
  ))

  expect_error(knbs_survey_metadata("no-such-study"), class = "knbs_error_resource_not_found")
})

test_that("variables are listed with their file names", {
  local_cache()
  local_kenada_api()
  variables <- knbs_variables("KEN-KNBS-KIHBS-2015-2016-v01")

  expect_named(variables, knbs_variable_columns())
  expect_identical(variables$file_name[[1]], "HH_Information")
  expect_true(all(is.na(variables$question_text)))
})

test_that("variables can be filtered by name, text and file", {
  local_cache()
  local_kenada_api()

  expect_identical(nrow(knbs_variables("X", name = "county")), 1L)
  expect_identical(nrow(knbs_variables("X", search = "sampling")), 1L)
  expect_identical(nrow(knbs_variables("X", file = "HH_Information")), 5L)
  expect_identical(nrow(knbs_variables("X", file = "F19")), 5L)
  expect_identical(nrow(knbs_variables("X", limit = 2)), 2L)
  expect_identical(nrow(knbs_variables("X", name = "no_such_variable")), 0L)
})

test_that("a study without variable documentation returns zero rows", {
  local_cache()
  local_kenada_api(list("/variables$" = list(total = 0, variables = list())))
  variables <- knbs_variables("DDI-KEN-KNBS-KDHS-2022-V001")

  expect_identical(nrow(variables), 0L)
  expect_named(variables, knbs_variable_columns())
})

test_that("details fill the per-variable fields and are capped", {
  local_cache()
  local_kenada_api()
  detailed <- knbs_variables("X", name = "county", details = TRUE)

  expect_identical(nrow(detailed), 1L)
  expect_identical(detailed$variable_type[[1]], "discrete")

  # Concepts only exist in the per-variable records.
  expect_error(knbs_variables("X", concept = "geography"), class = "knbs_error_invalid_query")
})

test_that("a lost file listing warns but still returns variables", {
  local_cache()
  local_kenada_api(list("data_files" = function(path) {
    knbs_abort("gone", class = "knbs_error_source_unavailable")
  }))

  expect_warning(
    variables <- knbs_variables("KEN-KNBS-KIHBS-2015-2016-v01"),
    class = "knbs_warning_missing_metadata"
  )
  expect_identical(nrow(variables), 5L)
  expect_true(all(is.na(variables$file_name)))
})

test_that("file listings carry the study's access type", {
  local_cache()
  local_kenada_api()
  files <- knbs_survey_files("KEN-KNBS-KIHBS-2015-2016-v01")

  expect_named(files, knbs_file_columns())
  expect_identical(nrow(files), 2L)
  expect_true(all(files$access_type == "public_use"))
  expect_false(any(files$downloadable))

  expect_identical(nrow(knbs_survey_files("X", type = "microdata")), 2L)
  expect_identical(nrow(knbs_survey_files("X", type = "questionnaire")), 0L)
  expect_identical(nrow(knbs_survey_files("X", access = "licensed")), 0L)
})

test_that("microdata download refuses and explains the official route", {
  local_cache()
  expect_error(
    knbs_download_microdata("KEN-KNBS-KIHBS-2015-2016-v01"),
    class = "knbs_error_authentication_required"
  )
  expect_error(
    knbs_download_microdata("KEN-KNBS-KIHBS-2015-2016-v01"),
    regexp = "requires an account"
  )

  cnd <- rlang::catch_cnd(knbs_download_microdata("KEN-KNBS-KIHBS-2015-2016-v01"))
  expect_match(cnd$access_url, "statistics.knbs.or.ke", fixed = TRUE)
})

test_that("public functions never reach the offline fixture source", {
  # fake_source declares search_surveys, but it is at discovery stability and so
  # must never be chosen for a user-facing call.
  expect_identical(resolve_source("search_surveys")$source_id, "kenada")
  expect_error(
    resolve_source("search_surveys", source = "fake_source"),
    class = "knbs_error_source_unavailable"
  )
})

test_that("an operation with no verified source fails clearly", {
  # get_indicator and geographies are verified now; classifications and
  # boundaries still have no source.
  expect_identical(resolve_source("get_indicator")$source_id, "knbs_indicators")
  expect_identical(resolve_source("geographies")$source_id, "knbs_indicators")
  expect_error(resolve_source("classifications"), class = "knbs_error_source_unavailable")
  expect_error(resolve_source("boundaries"), class = "knbs_error_source_unavailable")
})

test_that("catalogue responses are cached and refresh bypasses the cache", {
  local_cache()
  calls <- 0L
  local_kenada_api(list("catalog/search" = function(path) {
    calls <<- calls + 1L
    kenada_fixture("catalog-search.json")
  }))

  knbs_search_surveys("household")
  knbs_search_surveys("household")
  expect_identical(calls, 1L)

  knbs_search_surveys("household", refresh = TRUE)
  expect_identical(calls, 2L)

  expect_identical(knbs_cache_info()$operation, "search_surveys")
})
