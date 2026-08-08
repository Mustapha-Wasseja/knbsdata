test_that("geographies come back in the documented schema", {
  local_cache()
  local_knbsapi()
  geo <- knbs_geographies()

  expect_s3_class(geo, "knbs_geography")
  expect_s3_class(geo, "knbs_data")
  expect_named(geo, knbs_geography_columns())
  # The mini fixture's territory: Kenya, Mombasa, Changamwe, Nairobi City.
  expect_identical(geo$geo_code, c("00", "01", "0101", "47"))
  expect_identical(geo$geo_level, c("national", "county", "subcounty", "county"))
  expect_type(geo$geo_code, "character")
})

test_that("parenthood is structural and names resolve", {
  local_cache()
  local_knbsapi()
  geo <- knbs_geographies()

  expect_true(is.na(geo$parent_code[geo$geo_code == "00"]))
  expect_identical(geo$parent_code[geo$geo_code == "01"], "00")
  expect_identical(geo$parent_code[geo$geo_code == "0101"], "01")
  expect_identical(geo$parent_name[geo$geo_code == "0101"], "Mombasa")
  expect_identical(geo$parent_name[geo$geo_code == "47"], "Kenya")
})

test_that("the vintage is explicit and other vintages are refused", {
  local_cache()
  local_knbsapi()

  expect_true(all(knbs_geographies()$vintage == 2019L))
  expect_no_error(knbs_geographies(vintage = 2019))
  expect_error(knbs_geographies(vintage = 2009),
               class = "knbs_error_resource_not_found")
  expect_error(knbs_geographies(vintage = 2009), regexp = "2019 census frame")
})

test_that("level and parent filters narrow the reference", {
  local_cache()
  local_knbsapi()

  expect_identical(knbs_geographies(level = "county")$geo_code, c("01", "47"))
  expect_identical(knbs_geographies(level = "national")$geo_name, "Kenya")
  expect_identical(knbs_geographies(parent = "01")$geo_code, "0101")
  expect_identical(nrow(knbs_geographies(parent = "zz")), 0L)
  expect_error(knbs_geographies(level = "village"),
               class = "knbs_error_invalid_argument")
})

test_that("provenance names the source, licence and reference table", {
  local_cache()
  local_knbsapi()
  meta <- knbs_metadata(knbs_geographies())

  expect_identical(meta$resource_type, "geography")
  expect_match(meta$licence, "CC BY 4.0", fixed = TRUE)
  expect_match(meta$notes, "POPCEN0001", fixed = TRUE)
  expect_match(format(knbs_cite(meta)), "territorial codes", fixed = TRUE)
})

test_that("duplicate territory codes are refused", {
  expect_error(
    standardise_census_geographies(c("00", "01", "01"),
                                   c(`00` = "Kenya", `01` = "Mombasa"), "test"),
    class = "knbs_error_validation_failed"
  )
})

test_that("a sub-county whose county is missing is refused", {
  expect_error(
    standardise_census_geographies(
      c("00", "0101"),
      c(`00` = "Kenya", `0101` = "Changamwe"),
      "test"
    ),
    class = "knbs_error_validation_failed"
  )
  expect_error(
    standardise_census_geographies(
      c("00", "0101"),
      c(`00` = "Kenya", `0101` = "Changamwe"),
      "test"
    ),
    regexp = "reference a county"
  )
})

test_that("a code of unrecognised shape gets NA level and no parent guess", {
  geo <- standardise_census_geographies(
    c("00", "01", "X9Z"),
    c(`00` = "Kenya", `01` = "Mombasa", X9Z = "Mystery"),
    "test"
  )
  odd <- geo[geo$geo_code == "X9Z", ]
  expect_true(is.na(odd$geo_level))
  expect_true(is.na(odd$parent_code))
})

test_that("a reference table without a Territory dimension is a schema change", {
  local_cache()
  payload <- knbsapi_fixture("dataset-small.json")
  payload$dimension$system_total$label <- "Something Else"
  local_knbsapi(list("^getDataset$" = payload))

  expect_error(knbs_geographies(refresh = TRUE),
               class = "knbs_error_schema_changed")
})

test_that("the reference is cached and refresh bypasses", {
  local_cache()
  calls <- 0L
  local_knbsapi(list("^getDataset$" = function(path, query) {
    calls <<- calls + 1L
    knbsapi_fixture("dataset-small.json")
  }))

  knbs_geographies()
  knbs_geographies(level = "county")
  expect_identical(calls, 1L)
  knbs_geographies(refresh = TRUE)
  expect_identical(calls, 2L)
})

test_that("geography codes join the indicator observations exactly", {
  local_cache()
  local_knbsapi()

  geo <- knbs_geographies(level = "county")
  pop <- knbs_get_indicator("POPCEN0001", geo_level = "county")
  joined <- merge(pop, geo[, c("geo_code", "parent_code")], by = "geo_code")

  # Every county observation finds its reference row: same codes, same type.
  expect_identical(nrow(joined), nrow(pop))
})
