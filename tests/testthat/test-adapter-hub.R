# The SDMX hub adapter (audit F-28). Fixtures are real captured payloads:
# GDP by activity (annual, 41 activities x 8 years) and CPI by region
# (monthly, 211 periods), plus a trimmed two-dataflow catalogue.

test_that("the sdmxhub adapter implements what knbs_opendata declares", {
  implemented <- adapter_methods("sdmxhub")

  expect_true(implemented[["source_search"]])
  expect_true(implemented[["source_fetch"]])
  expect_true(implemented[["source_metadata"]])
  expect_true(implemented[["source_health"]])
  expect_false(implemented[["source_variables"]])
})

test_that("the catalogue maps dataflows to their statistical domain", {
  local_cache()
  local_hub_api()
  catalogue <- knbs_indicators(source = "knbs_opendata")

  expect_named(catalogue, knbs_indicator_list_columns())
  expect_identical(nrow(catalogue), 2L)
  expect_setequal(catalogue$indicator_id, c("DF_NAT_GDPCP", "DF_CPI_R"))
  expect_identical(unique(catalogue$topic), "ECONOMIC STATISTICS")
})

test_that("the aggregate catalogue spans every verified indicator source", {
  local_cache()
  local_knbsapi()
  combined <- knbs_indicators()

  expect_identical(nrow(combined), 40L)
  expect_setequal(
    unique(combined$source_id),
    c("knbs_indicators", "knbs_cpi", "knbs_opendata", "opendataforafrica")
  )
})

test_that("an annual dataflow becomes tidy integer-year observations", {
  local_cache()
  local_knbsapi()
  gdp <- knbs_get_indicator("DF_NAT_GDPCP")

  expect_s3_class(gdp, "knbs_indicator")
  expect_identical(nrow(gdp), 328L)
  expect_type(gdp$period, "integer")
  expect_identical(length(unique(gdp$period)), 8L)
  expect_true(all(gdp$period >= 2016L))
  # A varying dimension is named by its SDMX id in lower case: labels in
  # `na_indic`, the source's codes in `na_indic_code`.
  expect_true(all(c("na_indic", "na_indic_code") %in% names(gdp)))
  expect_false(any(c("NA_INDIC", "NA_INDIC_label") %in% names(gdp)))
  expect_identical(length(unique(gdp$na_indic_code)), 41L)
  expect_true("Accommodation and food service activities" %in% gdp$na_indic)

  # Single-category dimensions fold into metadata, not constant columns.
  expect_false(any(c("approach", "APPROACH") %in% names(gdp)))
  expect_false(any(c("unit_measure", "UNIT_MEASURE") %in% names(gdp)))

  meta <- knbs_metadata(gdp)
  expect_identical(meta$frequency, "annual")
  expect_identical(meta$unit, "Kenya Shillings")
  expect_identical(meta$licence, "Not stated by the source")
  expect_match(paste(meta$notes, collapse = " "), "Fixed for the whole dataflow")
})

test_that("a monthly dataflow becomes Date periods with SDMX area codes", {
  local_cache()
  local_knbsapi()
  cpi <- knbs_get_indicator("DF_CPI_R")

  expect_s3_class(cpi$period, "Date")
  expect_identical(knbs_metadata(cpi)$frequency, "monthly")
  expect_true(all(c("geo_code", "geo_name") %in% names(cpi)))
  expect_true("KE" %in% cpi$geo_code)
  # SDMX area codes are not census territories; no level is guessed.
  expect_true(all(is.na(cpi$geo_level)))

  kenya <- knbs_get_indicator("DF_CPI_R", geo_code = "KE")
  expect_identical(unique(kenya$geo_code), "KE")
})

test_that("period bounds work for both frequencies through the public layer", {
  local_cache()
  local_knbsapi()

  recent <- knbs_get_indicator("DF_NAT_GDPCP", start = 2020)
  expect_true(all(recent$period >= 2020L))

  window <- knbs_get_indicator("DF_CPI_R", start = "2020-01", end = "2020-12")
  expect_true(all(format(window$period, "%Y") == "2020"))
})

test_that("a geography filter on a flow without geography is refused", {
  local_cache()
  local_knbsapi()
  expect_error(
    knbs_get_indicator("DF_NAT_GDPCP", geo_code = "KE"),
    class = "knbs_error_invalid_query"
  )
  expect_error(
    knbs_get_indicator("DF_NAT_GDPCP", geo_code = "KE"),
    regexp = "no geography dimension"
  )
})

test_that("the data request carries the full SDMX reference", {
  local_cache()
  seen <- new.env()
  local_knbsapi()
  local_hub_api(post_overrides = list("." = function(ref) {
    seen$ref <- ref
    hub_default_post(NULL, ref)
  }))

  knbs_get_indicator("DF_NAT_GDPCP", refresh = TRUE)
  expect_identical(seen$ref, "KE1,DF_NAT_GDPCP,1.0")
})

test_that("catalogue and reference breakage are schema changes", {
  local_cache()
  local_hub_api(get_overrides = list("^catalog$" = list(nothing = TRUE)))
  expect_error(knbs_indicators(source = "knbs_opendata", refresh = TRUE),
               class = "knbs_error_schema_changed")

  # Two versions of one dataflow would make the middle-segment id ambiguous.
  broken <- hub_fixture("catalog-small.json")
  broken$datasetMap <- list(
    "KE1,DF_X,1.0" = list(title = "One"),
    "KE1,DF_X,2.0" = list(title = "Two")
  )
  local_hub_api(get_overrides = list("^catalog$" = broken))
  expect_error(knbs_indicators(source = "knbs_opendata", refresh = TRUE),
               class = "knbs_error_schema_changed")
})

test_that("an unknown dataflow id is not found", {
  local_cache()
  local_knbsapi()
  expect_error(knbs_get_indicator("DF_NOPE"),
               class = "knbs_error_resource_not_found")
})

test_that("dataflow metadata name the domain and dimensions", {
  local_cache()
  local_hub_api()
  meta <- source_metadata(hub_source(), "DF_NAT_GDPCP")

  expect_match(paste(meta$notes, collapse = " "), "ECONOMIC STATISTICS")
  expect_match(paste(meta$notes, collapse = " "), "Approach")
  expect_identical(meta$licence, "Not stated by the source")
})

test_that("health reports the catalogue size", {
  local_hub_api()
  health <- source_health(hub_source())
  expect_identical(health$status, "ok")
  expect_match(health$message, "2 dataflows")
})

test_that("sparse values land on the right coordinates", {
  # Decode one raw sparse entry of the real GDP payload by hand — row-major,
  # last dimension fastest — and require the standardised table to carry that
  # value at those coordinates. A misalignment anywhere in the expansion would
  # scramble every sparse dataflow while still passing shape checks.
  local_cache()
  local_knbsapi()

  raw <- hub_fixture("gdp-data.json")
  sizes <- as.integer(unlist(raw$size))
  dims <- as.character(unlist(raw$id))
  entry <- names(raw$value)[[1]]
  expected <- as.numeric(raw$value[[entry]])

  position <- as.integer(entry)
  coords <- integer(length(sizes))
  for (i in rev(seq_along(sizes))) {
    coords[[i]] <- position %% sizes[[i]]
    position <- position %/% sizes[[i]]
  }
  code_at <- function(dim_id, zero_index) {
    index <- raw$dimension[[dim_id]]$category$index
    codes <- if (is.list(index) && !is.null(names(index))) {
      names(index)[order(unlist(index))]
    } else {
      as.character(unlist(index))
    }
    codes[[zero_index + 1L]]
  }
  want_indic <- code_at("NA_INDIC", coords[[match("NA_INDIC", dims)]])
  want_period <- code_at("TIME_PERIOD", coords[[match("TIME_PERIOD", dims)]])

  gdp <- knbs_get_indicator("DF_NAT_GDPCP")
  hit <- gdp[gdp$na_indic_code == want_indic & gdp$period_label == want_period, ]
  expect_identical(nrow(hit), 1L)
  expect_identical(hit$value, expected)
})

test_that("non-numeric value cells become NA quietly", {
  expect_identical(jsonstat_cell(NULL), NA_real_)
  expect_identical(jsonstat_cell("-"), NA_real_)
  expect_identical(jsonstat_cell(""), NA_real_)
  expect_identical(jsonstat_cell("12.5"), 12.5)
  expect_no_warning(jsonstat_values(list(`0` = 1, `3` = "-"), 5))
})

test_that("SDMX time codes classify by convention", {
  expect_identical(sdmx_periods(c("2020", "2021")),
                   list(period = c(2020L, 2021L), frequency = "annual"))
  monthly <- sdmx_periods(c("2020-01", "2020-12"))
  expect_identical(monthly$frequency, "monthly")
  expect_identical(monthly$period, as.Date(c("2020-01-01", "2020-12-01")))
  quarterly <- sdmx_periods(c("2020-Q1", "2020-Q4"))
  expect_identical(quarterly$frequency, "quarterly")
  expect_identical(quarterly$period, as.Date(c("2020-01-01", "2020-10-01")))
  mixed <- sdmx_periods(c("2020", "2020-01"))
  expect_true(all(is.na(mixed$period)))
  expect_identical(mixed$frequency, NA_character_)
})

test_that("an undeclared geo role falls back to the SDMX reference area", {
  # By 2026-10-05 the hub had stopped declaring role.geo, which it declared in
  # August (audit F-37). REF_AREA is the SDMX concept for the reference area,
  # so it stands in, as TIME_PERIOD does for an undeclared time role.
  local_cache()
  local_knbsapi()
  undeclared <- hub_fixture("cpir-data.json")
  undeclared$role$geo <- list()
  local_hub_api(post_overrides = list("DF_CPI_R" = undeclared))

  cpi <- knbs_get_indicator("DF_CPI_R")
  expect_true(all(c("geo_code", "geo_name") %in% names(cpi)))
  expect_false(any(c("ref_area", "ref_area_code") %in% names(cpi)))
  kenya <- knbs_get_indicator("DF_CPI_R", geo_code = "KE")
  expect_identical(unique(kenya$geo_code), "KE")
})

test_that("a Sex dimension becomes lower-case sex, like the census tables'", {
  payload <- list(
    class = "dataset",
    version = "2.0",
    label = "A hand-built dataflow",
    id = list("SEX", "EDUCATION_LEVEL", "TIME_PERIOD"),
    size = list(3L, 2L, 1L),
    role = list(time = list("TIME_PERIOD"), geo = list()),
    dimension = list(
      SEX = list(label = "Sex", category = list(
        index = list("_T", "F", "M"),
        label = list(`_T` = "Total", F = "Female", M = "Male")
      )),
      EDUCATION_LEVEL = list(label = "Education level", category = list(
        index = list("PRI", "SEC"),
        label = list(PRI = "Primary", SEC = "Secondary")
      )),
      TIME_PERIOD = list(label = "Time", category = list(
        index = list("2024"), label = list(`2024` = "2024")
      ))
    ),
    value = as.list(1:6)
  )
  out <- standardise_sdmx_obs(
    parse_jsonstat(payload), "DF_TEST", "knbs_opendata",
    roles = list(time = "TIME_PERIOD", geo = character(0))
  )$table

  expect_setequal(unique(out$sex), c("total", "female", "male"))
  expect_false(any(c("SEX", "SEX_label", "sex_code") %in% names(out)))
  expect_true(all(c("education_level", "education_level_code") %in% names(out)))
  expect_identical(
    unique(out$education_level[out$education_level_code == "SEC"]),
    "Secondary"
  )
})
