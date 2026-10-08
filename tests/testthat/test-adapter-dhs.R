# Adapter ---------------------------------------------------------------------

test_that("the dhs adapter implements what dhs_program declares", {
  implemented <- adapter_methods("dhs")
  expect_true(implemented[["source_search"]])
  expect_true(implemented[["source_fetch"]])
  expect_true(implemented[["source_metadata"]])
  expect_true(implemented[["source_health"]])
  expect_false(implemented[["source_files"]])
  expect_false(implemented[["source_variables"]])
})

test_that("the indicator listing becomes the catalogue, each id once", {
  local_cache()
  local_dhs_api()

  cat_ <- knbs_indicators(source = "dhs_program")
  expect_named(cat_, knbs_indicator_list_columns())
  # The listing repeats CH_ARSS_C_NGO under a second label; it is kept once.
  expect_identical(nrow(cat_), 6L)
  expect_false(anyDuplicated(cat_$indicator_id) > 0L)
  expect_match(cat_$indicator_name[cat_$indicator_id == "CH_ARSS_C_NGO"], "private medical sector")
  expect_identical(cat_$unit[cat_$indicator_id == "CN_NUTS_C_HA2"], "percent")
  expect_identical(cat_$topic[cat_$indicator_id == "CN_NUTS_C_HA2"], "Child Nutrition")
  expect_true(all(cat_$source_id == "dhs_program"))
})

# Observations ----------------------------------------------------------------

test_that("an indicator arrives for every survey, with its groups and geography", {
  local_cache()
  local_dhs_api()
  local_counties() # nolint: object_usage_linter. Defined in helper-counties.R.

  stunting <- knbs_get_indicator("CN_NUTS_C_HA2", source = "dhs_program")
  expect_s3_class(stunting, "knbs_indicator")
  expect_identical(names(stunting)[1:5],
                   c("indicator_id", "indicator_name", "period", "period_label", "value"))
  expect_true(all(c("geo_code", "geo_name", "geo_level", "survey", "survey_code",
                    "characteristic_type", "characteristic", "characteristic_code",
                    "preferred", "source_id") %in% names(stunting)))
  expect_type(stunting$period, "integer")

  national <- stunting[stunting$characteristic_type == "Total", ]
  expect_identical(national$value, c(35.3, 26.0, 17.6))
  expect_identical(national$period_label, c("2008-09", "2014", "2022"))
  expect_identical(national$survey, c("2008-09 DHS", "2014 DHS", "2022 DHS"))
  expect_identical(unique(national$geo_code), "00")

  # Background characteristics describe Kenya as a whole.
  wealth <- stunting[stunting$characteristic_type == "Wealth quintile", ]
  expect_identical(wealth$characteristic, c("Lowest", "Second", "Middle", "Fourth", "Highest"))
  expect_identical(unique(wealth$geo_level), "national")
})

test_that("counties carry census codes; provinces and Nairobi are placed by level", {
  local_cache()
  local_dhs_api()
  local_counties() # nolint: object_usage_linter. Defined in helper-counties.R.
  stunting <- knbs_get_indicator("CN_NUTS_C_HA2", source = "dhs_program")
  rows <- function(year, level) stunting[stunting$period == year & stunting$geo_level == level, ]

  # 2008: the eight former provinces, no counties.
  expect_identical(nrow(rows(2008, "region")), 8L)
  expect_identical(nrow(rows(2008, "county")), 0L)

  # 2014: eight provinces and 47 counties; Nairobi, listed twice, is one of each.
  counties14 <- rows(2014, "county")
  expect_identical(sort(counties14$geo_code), sprintf("%02d", 1:47))
  expect_identical(counties14$value[counties14$geo_code == "47"], 17.2)
  expect_identical(counties14$value[counties14$geo_name == "Mombasa"], 21.1)
  expect_true("Nairobi" %in% rows(2014, "region")$geo_name)
  expect_identical(nrow(rows(2014, "region")), 8L)

  # 2022: seven provinces and 47 counties; its one Nairobi row is the county.
  counties22 <- rows(2022, "county")
  expect_identical(sort(counties22$geo_code), sprintf("%02d", 1:47))
  expect_identical(counties22$value[counties22$geo_code == "47"], 11.1)
  expect_identical(counties22$value[counties22$geo_code == "01"], 13.5)
  expect_false("Nairobi" %in% rows(2022, "region")$geo_name)
  expect_true(all(is.na(rows(2022, "region")$geo_code)))
  # The ".." nesting marks are not part of a name.
  expect_false(any(startsWith(stunting$geo_name, ".")))
})

test_that("geography and period filters apply", {
  local_cache()
  local_dhs_api()
  local_counties() # nolint: object_usage_linter. Defined in helper-counties.R.

  counties <- knbs_get_indicator("CN_NUTS_C_HA2", source = "dhs_program", geo_level = "county")
  expect_identical(unique(counties$geo_level), "county")
  expect_identical(nrow(counties), 94L)

  nairobi <- knbs_get_indicator("CN_NUTS_C_HA2", source = "dhs_program", geo_code = "47")
  expect_identical(nairobi$value, c(17.2, 11.1))

  recent <- knbs_get_indicator("CN_NUTS_C_HA2", source = "dhs_program", start = 2014)
  expect_identical(sort(unique(recent$period)), c(2014L, 2022L))

  expect_error(knbs_get_indicator("CN_NUTS_C_HA2", source = "dhs_program", frequency = "annual"),
               class = "knbs_error_invalid_query")
})

test_that("alternative reference periods are kept and marked", {
  local_cache()
  local_dhs_api()
  anc <- knbs_get_indicator("RH_ANCP_W_NON", source = "dhs_program")

  expect_true(all(c("by_variable", "by_variable_code") %in% names(anc)))
  total <- anc[anc$characteristic_type == "Total", ]
  expect_identical(nrow(total), 3L)
  expect_identical(total$value[total$preferred], 19.8)
  expect_identical(total$by_variable[total$preferred], "Two years preceding the survey")
  expect_identical(sum(!anc$preferred), 6L)
  expect_match(knbs_metadata(anc)$notes, "6 value\\(s\\) are alternatives", all = FALSE)
})

test_that("malaria zones are regions without codes", {
  local_cache()
  local_dhs_api()
  malaria <- knbs_get_indicator("ML_PMAL_C_RDT", source = "dhs_program")
  zones <- malaria[malaria$geo_level == "region", ]
  expect_identical(zones$geo_name, c("Highland epidemic", "Lake endemic", "Coast endemic",
                                     "Semi-arid, seasonal", "Low risk"))
  expect_true(all(is.na(zones$geo_code)))
  expect_identical(malaria$survey[[1]], "2020 MIS")
})

test_that("provenance names the API's required citation and the implementers", {
  local_cache()
  local_dhs_api()
  local_counties() # nolint: object_usage_linter. Defined in helper-counties.R.
  meta <- knbs_metadata(knbs_get_indicator("CN_NUTS_C_HA2", source = "dhs_program"))

  expect_identical(meta$title, "Children stunted")
  expect_identical(meta$unit, "percent")
  expect_identical(meta$citation, dhs_citation())
  expect_identical(meta$reference_period, "2008-09 to 2022")
  expect_identical(meta$release_date, as.Date("2023-07-03"))
  expect_match(meta$notes, "^Definition: Percentage of children stunted", all = FALSE)
  expect_match(meta$notes, "KE2022DHS - Kenya National Bureau of Statistics", all = FALSE)
  expect_match(meta$notes, "census county codes", all = FALSE)

  citation <- format(knbs_cite(knbs_get_indicator("CN_NUTS_C_HA2", source = "dhs_program")))
  expect_match(citation, "^The DHS Program Indicator Data API")
})

test_that("an id listed under two labels says so", {
  local_dhs_api()
  meta <- source_metadata(dhs_source(), "CH_ARSS_C_NGO")
  expect_match(meta$notes, "under 2 labels", all = FALSE)
})

test_that("an indicator with no values is an empty table, not an error", {
  local_cache()
  local_dhs_api()
  tfr <- knbs_get_indicator("FE_FRTR_W_TFR", source = "dhs_program")
  expect_identical(nrow(tfr), 0L)
  expect_true(all(c("indicator_id", "period", "value", "geo_code") %in% names(tfr)))
  expect_match(knbs_metadata(tfr)$notes, "serves no values", all = FALSE)
})

test_that("an unknown indicator is a missing resource", {
  local_dhs_api()
  query <- new_knbs_query("indicator", resource_id = "NOT_AN_INDICATOR", source = "dhs_program")
  expect_error(source_fetch(dhs_source(), query), class = "knbs_error_resource_not_found")
})

# Robustness ------------------------------------------------------------------

test_that("geography levels follow each survey's county level", {
  survey <- c("A", "A", "A", "A", "B", "B", "B", "C")
  category <- c("Total", "Region", "Region", "Region", "Region", "Region", "Region", "Region")
  label <- c("Total", "Coast", "..Mombasa", "Nairobi", "Coast", "..Mombasa", "Nairobi", "Lake endemic")
  rank <- c(NA, "1", "2", "2", NA, "1", "1", "1")
  expect_identical(
    dhs_geo_level(survey, category, label, rank),
    c("national", "region", "county", "county", "region", "county", "county", "region")
  )

  # An indicator published only by province still carries Nairobi's county
  # row, one level down, with no prefixed counties to anchor it.
  expect_identical(
    dhs_geo_level(rep("D", 3), rep("Region", 3), c("Coast", "Nairobi", "Nairobi"),
                  c("1", "1", "2")),
    c("region", "region", "county")
  )
})

test_that("results are paged through, but not without end", {
  pages <- 0L
  local_dhs_api(function(source, path, query = list(), call = NULL) {
    pages <<- pages + 1L
    list(Data = list(list(IndicatorId = paste0("X", query$page))), TotalPages = 3L)
  })
  records <- dhs_all(dhs_source(), "indicators")
  expect_identical(vapply(records, function(r) r$IndicatorId, ""), c("X1", "X2", "X3"))

  local_dhs_api(function(source, path, query = list(), call = NULL) {
    list(Data = list(), TotalPages = 99L)
  })
  expect_error(dhs_all(dhs_source(), "indicators"), class = "knbs_error_schema_changed")
})

test_that("an answer of the wrong shape is a schema change", {
  local_mocked_bindings(knbs_perform = function(req, ...) {
    httr2::response(status_code = 200L, headers = list(`Content-Type` = "application/json"),
                    body = charToRaw('{"error": "something else"}'))
  })
  expect_error(dhs_get(dhs_source(), "indicators"), class = "knbs_error_schema_changed")
})

test_that("a record served twice is kept once; two values for one group are refused", {
  record <- list(SurveyId = "KE2014DHS", SurveyYear = 2014, SurveyYearLabel = "2014",
                 SurveyType = "DHS", CharacteristicCategory = "Total",
                 CharacteristicLabel = "Total", CharacteristicId = 1000, Value = 17409,
                 IsPreferred = 1)
  once <- standardise_dhs_obs(list(record, record), "X", "X", "dhs_program")
  expect_identical(nrow(once$table), 1L)
  expect_match(once$notes, "served twice, identically", all = FALSE)

  # As the API serves WS_HNDW_H_UNW, an id it reuses for two indicators.
  other <- record
  other$Value <- 10850
  expect_error(standardise_dhs_obs(list(record, other), "WS_HNDW_H_UNW", "X", "dhs_program"),
               "17,409 and 10,850", class = "knbs_error_validation_failed")
})

test_that("the health check reports the API version", {
  local_dhs_api()
  health <- source_health(dhs_source())
  expect_identical(health$status, "ok")
  expect_match(health$message, "version 8.1")
})
