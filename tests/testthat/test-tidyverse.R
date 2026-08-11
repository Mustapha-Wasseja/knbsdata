# The tidyverse contract. Every data-carrying object the package returns is a
# tibble built on vctrs, so dplyr verbs keep the class and the provenance
# metadata, aggregation and reshaping degrade to plain tibbles (derived data
# is no longer the source's data), and as_tibble() is the escape hatch.
# These tests lock that contract so a dependency update cannot silently
# loosen it.

test_that("dplyr verbs keep the class and provenance of abstract tables", {
  testthat::skip_if_not_installed("dplyr")
  local_cache()
  local_abstract_workbook()
  gdp <- knbs_abstract_table("2.2")

  filtered <- dplyr::filter(gdp, industry == "Manufacturing")
  expect_s3_class(filtered, "knbs_abstract_table")
  expect_identical(knbs_metadata(filtered)$resource_id, "2.2")

  mutated <- dplyr::mutate(gdp, billions = value / 1000)
  expect_s3_class(mutated, "knbs_abstract_table")
  expect_true("billions" %in% names(mutated))

  arranged <- dplyr::arrange(gdp, dplyr::desc(value))
  expect_s3_class(arranged, "knbs_abstract_table")

  selected <- dplyr::select(gdp, industry, period, value)
  expect_s3_class(selected, "knbs_abstract_table")

  top <- dplyr::slice_max(dplyr::filter(gdp, period == 2024), value, n = 3)
  expect_s3_class(top, "knbs_abstract_table")
  expect_identical(nrow(top), 3L)

  bound <- dplyr::bind_rows(
    dplyr::filter(gdp, period == 2024),
    dplyr::filter(gdp, period == 2023)
  )
  expect_s3_class(bound, "knbs_abstract_table")
})

test_that("dplyr verbs keep the class and provenance of indicators", {
  testthat::skip_if_not_installed("dplyr")
  local_cache()
  local_knbsapi()
  gcp <- knbs_get_indicator("jhbzkjc")

  latest <- dplyr::filter(gcp, table == "T3", period == 2020)
  expect_s3_class(latest, "knbs_indicator")
  expect_identical(knbs_metadata(latest)$resource_id, "jhbzkjc")

  ranked <- dplyr::arrange(latest, dplyr::desc(value))
  expect_s3_class(ranked, "knbs_indicator")
})

test_that("aggregation degrades to a plain tibble, as derived data should", {
  testthat::skip_if_not_installed("dplyr")
  local_cache()
  local_abstract_workbook()
  gdp <- knbs_abstract_table("2.2")

  totals <- dplyr::summarise(
    dplyr::group_by(gdp, period),
    industries = dplyr::n(),
    .groups = "drop"
  )
  expect_s3_class(totals, "tbl_df")
  expect_false(inherits(totals, "knbs_abstract_table"))
  expect_identical(nrow(totals), 10L)
})

test_that("pivot_wider reproduces the printed-table look", {
  testthat::skip_if_not_installed("dplyr")
  testthat::skip_if_not_installed("tidyr")
  local_cache()
  local_abstract_workbook()
  gdp <- knbs_abstract_table("2.2")

  wide <- tidyr::pivot_wider(
    dplyr::select(
      dplyr::filter(gdp, industry %in% c("Manufacturing", "GDP at market prices")),
      industry, period, value
    ),
    names_from = period,
    values_from = value
  )
  expect_s3_class(wide, "tbl_df")
  expect_identical(nrow(wide), 2L)
  expect_true(all(c("industry", "2015", "2024") %in% names(wide)))
  expect_identical(
    wide[["2016"]][wide$industry == "GDP at market prices"],
    7594064
  )

  # And back again: the long form round-trips.
  long <- tidyr::pivot_longer(wide, -industry, names_to = "period",
                              values_to = "value")
  expect_identical(nrow(long), 20L)
})

test_that("as_tibble() strips the wrapper cleanly", {
  local_cache()
  local_abstract_workbook()
  gdp <- knbs_abstract_table("2.2")

  plain <- tibble::as_tibble(gdp)
  expect_identical(class(plain), c("tbl_df", "tbl", "data.frame"))
  expect_null(attr(plain, "knbs_metadata", exact = TRUE))
  expect_identical(nrow(plain), nrow(gdp))
})
