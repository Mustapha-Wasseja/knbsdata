# County matching. The reference is the census frame's 47 counties
# (helper-counties.R); the Data Portal's spellings below are as its county
# dataflows write them.

test_that("the usual spellings resolve to the official codes", {
  local_counties()
  expect_identical(
    knbs_county_code(c("Murang'a", "MURANGA", paste0("Murang", intToUtf8(0x2019), "a"), "Nairobi",
                       "Nairobi City County", "taita/taveta", "Taita Taveta",
                       "Tharaka Nithi", "Elgeyo-Marakwet County", "Homabay",
                       "County Government of Kisumu", "  uasin   gishu ")),
    c("21", "21", "21", "47", "47", "06", "06", "13", "28", "43", "42", "27")
  )
})

test_that("every Data Portal county name has its own code", {
  local_counties()
  portal <- toupper(census_counties()$geo_name)
  portal[portal == "NAIROBI CITY"] <- "NAIROBI"
  portal[portal == "MURANG'A"] <- "MURANGA"
  portal[portal == "THARAKA-NITHI"] <- "THARAKA NITHI"
  codes <- knbs_county_code(portal)
  expect_identical(codes, census_counties()$geo_code)
})

test_that("numbers are county numbers; the country is 00", {
  local_counties()
  expect_identical(knbs_county_code(c(1, 47)), c("01", "47"))
  expect_identical(knbs_county_code(c("1", "01", " 7 ")), c("01", "01", "07"))
  expect_identical(knbs_county_code(c("Kenya", "NATIONAL")), c("00", "00"))
  expect_warning(out <- knbs_county_code(c("48", "0")),
                 class = "knbs_warning_unmatched")
  expect_identical(out, c(NA_character_, NA_character_))
})

test_that("an unmatched value is NA with one warning, never a guess", {
  local_counties()
  expect_warning(
    out <- knbs_county_code(c("Kakamenga", "Mombasa", "Gotham {x}")),
    class = "knbs_warning_unmatched"
  )
  expect_identical(out, c(NA, "01", NA))

  cnd <- tryCatch(knbs_county_code(c("Kakamenga", "Gotham {x}")),
                  knbs_warning_unmatched = function(w) w)
  expect_identical(cnd$unmatched, c("Kakamenga", "Gotham {x}"))
  message <- conditionMessage(cnd)
  expect_match(message, "did you mean \"Kakamega\"", fixed = TRUE)
  # The caller's braces are printed, not evaluated.
  expect_match(message, "Gotham {x}", fixed = TRUE)

  # Missing values stay missing, silently.
  expect_no_warning(expect_identical(knbs_county_code(c("Lamu", NA)), c("05", NA)))
})

test_that("factors work and the result keeps the input's length and order", {
  local_counties()
  x <- factor(c("Nyeri", "Kwale", "Nyeri", "Kwale"))
  expect_identical(knbs_county_code(x), c("19", "02", "19", "02"))
  expect_error(knbs_county_code(list("Nyeri")), class = "knbs_error_invalid_argument")
})

test_that("the diagnostic shows each distinct value and how it matched", {
  local_counties()
  out <- knbs_match_counties(c("Kakamenga", "Uasin-Gishu", "07", "07", "Kenya"))
  expect_named(out, c("input", "geo_code", "geo_name", "matched_by", "suggestion"))
  expect_identical(out$input, c("Kakamenga", "Uasin-Gishu", "07", "Kenya"))
  expect_identical(out$matched_by, c(NA, "name", "number", "national"))
  expect_identical(out$geo_name, c(NA, "Uasin Gishu", "Garissa", "Kenya"))
  expect_identical(out$suggestion, c("Kakamega", NA, NA, NA))
})

test_that("the reference is the census frame, read through knbs_geographies()", {
  local_cache()
  local_knbsapi()
  # The census fixture carries two counties: 01 Mombasa and 47 Nairobi City.
  expect_identical(knbs_county_code(c("MOMBASA", "Nairobi")), c("01", "47"))
  expect_error(knbs_county_code("Mombasa", vintage = 2009L))
})

test_that("the statutory counties stand in when the census service is down", {
  # The built-in list is the census frame's own, name for name.
  expect_identical(county_statutory(), census_counties()) # nolint: object_usage_linter. Defined in helper-counties.R.

  local_mocked_bindings(knbs_geographies = function(...) {
    knbs_abort("Could not reach the census service.", class = "knbs_error_source_unavailable")
  })
  expect_identical(knbs_county_code(c("Mombasa", "Nairobi City County", "Taita Taveta")),
                   c("01", "47", "06"))
})

test_that("a census service that answers wrongly is not papered over", {
  local_mocked_bindings(knbs_geographies = function(...) {
    knbs_abort("The source changed shape.", class = "knbs_error_schema_changed")
  })
  expect_error(knbs_county_code("Mombasa"), class = "knbs_error_schema_changed")
})
