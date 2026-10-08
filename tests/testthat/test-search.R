# One search across every catalogue. Every source's network entry point is
# mocked, so the catalogues are the fixtures: census and CPI indicators, two
# SDMX dataflows, two africa-portal datasets, three archive studies, three
# publications, and the curated Abstract tables.

local_search_apis <- function(env = parent.frame()) {
  local_knbsapi(env = env) # nolint: object_usage_linter. Defined in helper-indicators.R.
  local_kenada_api(env = env) # nolint: object_usage_linter. Defined in helper-nada.R.
  local_wp_api(env = env) # nolint: object_usage_linter. Defined in helper-wordpress.R.
}

test_that("one search spans every catalogue in one schema", {
  local_cache()
  local_search_apis()

  surveys <- knbs_search("survey")
  expect_s3_class(surveys, "knbs_catalogue")
  expect_named(surveys, knbs_search_columns())
  expect_setequal(unique(surveys$resource_type), c("survey", "microdata", "publication"))

  gdp <- knbs_search("gross domestic product")
  expect_true(all(c("indicator", "table") %in% gdp$resource_type))
  expect_true("DF_NAT_GDPCP" %in% gdp$resource_id)
  expect_true("2.2" %in% gdp$resource_id)
})

test_that("each result carries the call that retrieves it, and the call works", {
  local_cache()
  local_search_apis()
  local_abstract_workbook()

  flow <- knbs_search("DF_NAT_GDPCP")
  expect_identical(flow$resource_id[[1]], "DF_NAT_GDPCP")
  expect_identical(flow$get[[1]],
                   'knbs_get_indicator("DF_NAT_GDPCP", source = "knbs_opendata")')
  expect_s3_class(eval(parse(text = flow$get[[1]])), "knbs_indicator")

  table <- knbs_search("capital formation", type = "table")
  expect_s3_class(eval(parse(text = table$get[[1]])), "knbs_abstract_table")

  study <- knbs_search("demographic health", type = "survey")
  expect_s3_class(eval(parse(text = study$get[[1]])), "knbs_survey")

  documents <- knbs_search("economic survey", type = "publication")
  expect_match(documents$get, '^knbs_download_publication\\("[0-9]+"\\)$')
})

test_that("open microdata is found by round, with the call that downloads and reads it", {
  hits <- knbs_search("finaccess", type = "microdata")
  expect_setequal(hits$resource_id,
                  c("hh2024", "hh2021", "hh2016", "hh2013", "hh2009", "hh2006",
                    "mse2023", "mse2022"))
  expect_identical(hits$resource_id[1:2], c("hh2024", "hh2021"))
  expect_true(all(hits$access == "open"))
  # Each round is offered in its best-labelled format.
  expect_identical(hits$get[hits$resource_id == "hh2024"],
                   'knbs_read_microdata(knbs_download_finaccess("hh2024-stata"))')
  expect_identical(hits$get[hits$resource_id == "hh2016"],
                   'knbs_read_microdata(knbs_download_finaccess("hh2016-spss"))')

  enterprises <- knbs_search("micro and small enterprises", type = "microdata")
  expect_setequal(enterprises$resource_id, c("mse2023", "mse2022"))
  expect_identical(knbs_search("financial inclusion 2021", type = "microdata")$resource_id,
                   "hh2021")
})

test_that("plurals, prefixes and acronyms match both ways", {
  stems <- search_stem(c("indices", "prices", "rates", "census", "analysis",
                         "economies", "taxes", "business"))
  expect_identical(stems, c("index", "price", "rate", "census", "analysis",
                            "economy", "tax", "business"))

  words_of <- function(text) search_stem(search_words(text)[[1]])
  release <- words_of("Kenya-Consumer-Price-Indices-and-Inflation-Rates")
  expect_true(search_matches(search_terms("Consumer Price Index"), release))
  expect_true(search_matches(search_terms("cpi"), release))
  # A spelled-out acronym also finds the acronym alone.
  expect_true(search_matches(search_terms("gross domestic product"),
                             words_of("Real GDP growth")))
  # Four letters or more match as the start of a word; shorter ones do not.
  expect_true(search_matches(search_terms("agric"), words_of("Agriculture")))
  expect_false(search_matches(search_terms("gas"), words_of("Gasoline")))
  # Every word must match, common words aside.
  expect_true(search_matches(search_terms("the price of oil"),
                             words_of("Oil price index")))
  expect_false(search_matches(search_terms("price of oil"),
                              words_of("Food price index")))
})

test_that("ranking puts the exact id first and data before documents", {
  local_cache()
  local_search_apis()

  expect_identical(knbs_search("POPCEN0002")$resource_id[[1]], "POPCEN0002")
  expect_identical(knbs_search("cpi")$resource_id[[1]], "CPI_ALL_ITEMS")

  # Every word in the title, but not as the phrase: the all-words tier.
  ranked <- search_score(
    search_rows("publication", "1", "Survey of population", source_id = "s",
                get = "x", text = "Survey of population",
                release_date = as.Date("2026-01-01")),
    "population survey", search_terms("population survey")
  )
  expect_identical(ranked$score, 50)
})

test_that("an unreachable catalogue is a warning; all of them, an error", {
  local_cache()
  local_search_apis()
  local_wp_api(list("^media$" = function(path, query) {
    knbs_abort("The source failed to answer.",
               class = "knbs_error_source_unavailable")
  }))

  expect_warning(hits <- knbs_search("survey"),
                 class = "knbs_warning_partial_failure")
  expect_false("publication" %in% hits$resource_type)
  expect_true("survey" %in% hits$resource_type)

  expect_error(knbs_search("survey", type = "publication"),
               class = "knbs_error_source_unavailable")
})

test_that("an unreachable indicator source is named in the one warning", {
  local_cache()
  local_search_apis()
  local_knoema_api(list("." = function(path, query) {
    knbs_abort("The source refused access to this resource.",
               class = "knbs_error_access_restricted")
  }))

  expect_warning(hits <- knbs_search("population", type = "indicator"),
                 regexp = "opendataforafrica")
  expect_true(all(hits$source_id != "opendataforafrica"))
  expect_gt(nrow(hits), 0)
})

test_that("type and limit narrow the results; an empty query is refused", {
  local_cache()
  local_search_apis()

  tables <- knbs_search("gross domestic product", type = "table")
  expect_gt(nrow(tables), 0)
  expect_true(all(tables$resource_type == "table"))
  expect_lte(nrow(knbs_search("population", limit = 2)), 2L)

  expect_error(knbs_search("the of and"), class = "knbs_error_invalid_argument")
  expect_error(knbs_search("population", type = "map"),
               class = "knbs_error_invalid_argument")
  expect_identical(nrow(knbs_search("zzqx nothing matches")), 0L)
})

test_that("the publications listing pages through the whole library", {
  local_cache()
  base <- wp_fixture("media-listing.json")
  page_of <- function(ids) {
    out <- base[seq_along(ids)]
    for (i in seq_along(ids)) {
      out[[i]]$id <- ids[[i]]
    }
    attr(out, "wp_total") <- 4L
    attr(out, "wp_total_pages") <- 2L
    out
  }
  # Page 2 repeats a record, as an upload landing mid-scan would cause.
  local_wp_api(list("^media$" = function(path, query) {
    if (is.null(query$page)) page_of(c(101L, 102L, 103L)) else page_of(c(103L, 104L))
  }))

  listing <- publications_listing()
  expect_identical(sort(listing$publication_id), c("101", "102", "103", "104"))
})
