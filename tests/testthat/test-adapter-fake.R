# The fake adapter is the end-to-end proof that the query object, adapter
# contract, cache, metadata classes and citation builder work together without a
# network (plan Phase 2 exit criteria).

test_that("sources are built from the registry and dispatch on their adapter", {
  source <- knbs_source("fake_source")

  expect_s3_class(source, "knbs_source_fake")
  expect_s3_class(source, "knbs_source")
  expect_identical(source$adapter, "fake")
  expect_error(knbs_source("no_such_source"), class = "knbs_error_resource_not_found")
})

test_that("the fake adapter satisfies the whole contract", {
  implemented <- adapter_methods("fake")
  expect_true(all(implemented))
  expect_named(implemented, adapter_contract())
})

test_that("an adapter that implements nothing fails loudly", {
  # A registry entry naming an adapter with no methods is a package bug, and it
  # must not look like an empty result. Constructed here rather than taken from
  # the registry so that the test can never reach a network.
  phantom <- structure(
    list(source_id = "phantom", adapter = "phantom", operations = "search_surveys",
         stability = "beta"),
    class = c("knbs_source_phantom", "knbs_source")
  )

  expect_error(
    source_search(phantom, new_knbs_query("survey")),
    class = "knbs_error_invalid_argument"
  )
  expect_error(source_metadata(phantom, "X"), class = "knbs_error_invalid_argument")
  expect_error(source_variables(phantom, "X"), class = "knbs_error_invalid_argument")
  expect_false(any(adapter_methods("phantom")))
})

test_that("the registry decides what a source may be asked to do", {
  # KeNADA gates its downloads (audit F-03), so it does not declare the
  # operation and the package refuses before any request is built.
  expect_error(
    check_operation(knbs_source("kenada"), "download_public_files"),
    class = "knbs_error_invalid_query"
  )
  expect_silent(check_operation(knbs_source("kenada"), "search_surveys"))
})

test_that("an unverified source cannot be called", {
  expect_error(
    check_source_verified(knbs_source("knbs_publications")),
    class = "knbs_error_source_unavailable"
  )
  expect_silent(check_source_verified(knbs_source("kenada")))
})

test_that("search returns the standard catalogue schema", {
  results <- source_search(knbs_source("fake_source"), new_knbs_query("survey"))

  expect_s3_class(results, "knbs_catalogue")
  expect_s3_class(results, "knbs_data")
  expect_named(results, knbs_catalogue_columns())
  expect_identical(nrow(results), 3L)
  expect_s3_class(results$release_date, "Date")
  expect_identical(knbs_metadata(results)$source_id, "fake_source")
})

test_that("search filters narrow the result and unknown filters are refused", {
  source <- knbs_source("fake_source")

  hits <- source_search(source, new_knbs_query("survey", filters = list(search = "restricted")))
  expect_identical(nrow(hits), 1L)
  expect_identical(hits$resource_id, "FAKE-SURVEY-002")

  indicators <- source_search(source, new_knbs_query("survey", filters = list(type = "indicator")))
  expect_identical(indicators$resource_id, "FAKE-CPI")

  none <- source_search(source, new_knbs_query("survey", filters = list(search = "zzz")))
  expect_identical(nrow(none), 0L)

  expect_error(
    source_search(source, new_knbs_query("survey", filters = list(colour = "blue"))),
    class = "knbs_error_invalid_query"
  )
})

test_that("study metadata come back as a metadata object", {
  meta <- source_metadata(knbs_source("fake_source"), "FAKE-SURVEY-001")

  expect_s3_class(meta, "knbs_metadata")
  expect_identical(meta$title, "Fake Household Survey 2020")
  expect_identical(meta$version, "v01")
  expect_identical(meta$release_date, as.Date("2021-03-15"))
  expect_length(meta$notes, 2L)
  expect_false(is.null(meta$raw))

  expect_error(
    source_metadata(knbs_source("fake_source"), "NO-SUCH-ID"),
    class = "knbs_error_resource_not_found"
  )
})

test_that("file listings report access, and restricted resources are refused", {
  files <- source_files(knbs_source("fake_source"), "FAKE-SURVEY-001")

  expect_identical(nrow(files), 3L)
  expect_identical(files$file_id, c("F1", "F2", "F3"))
  expect_identical(files$downloadable, c(TRUE, TRUE, FALSE))
  expect_identical(files$access[[3]], "restricted")

  expect_error(
    source_files(knbs_source("fake_source"), "FAKE-SURVEY-002"),
    class = "knbs_error_access_restricted"
  )
})

test_that("fetching returns data with provenance attached", {
  local_cache()
  query <- new_knbs_query("indicator", resource_id = "FAKE-CPI", source = "fake_source")
  data <- source_fetch(knbs_source("fake_source"), query)

  expect_s3_class(data, "knbs_indicator")
  expect_identical(nrow(data), 5L)

  # A missing value keeps its meaning instead of becoming a bare NA.
  missing <- data[is.na(data$value), ]
  expect_identical(nrow(missing), 1L)
  expect_identical(missing$observation_status, "not_available")

  # County codes stay character: 047 must not become 47.
  expect_type(data$geo_code, "character")
  expect_true("047" %in% data$geo_code)

  meta <- knbs_metadata(data)
  expect_identical(meta$unit, "index")
  expect_identical(meta$frequency, "monthly")
  expect_identical(meta$release_date, as.Date("2020-04-10"))
})

test_that("fetch filters are applied and validated", {
  local_cache()
  source <- knbs_source("fake_source")

  filtered <- source_fetch(source, new_knbs_query(
    "indicator",
    resource_id = "FAKE-CPI",
    filters = list(start = "2020-02", geo_code = "0")
  ))
  expect_identical(nrow(filtered), 2L)
  expect_true(all(filtered$geo_code == "0"))

  expect_error(
    source_fetch(source, new_knbs_query("indicator", resource_id = "FAKE-CPI",
                                        filters = list(colour = "blue"))),
    class = "knbs_error_invalid_query"
  )
  expect_error(
    source_fetch(source, new_knbs_query("indicator")),
    class = "knbs_error_invalid_query"
  )
})

test_that("fetching a restricted resource is refused", {
  local_cache()
  expect_error(
    source_fetch(knbs_source("fake_source"),
                 new_knbs_query("indicator", resource_id = "FAKE-SURVEY-002")),
    class = "knbs_error_access_restricted"
  )
})

test_that("fetched data are cached under the source and resource", {
  local_cache()
  query <- new_knbs_query("indicator", resource_id = "FAKE-CPI")

  source_fetch(knbs_source("fake_source"), query)
  info <- knbs_cache_info()

  expect_identical(nrow(info), 1L)
  expect_identical(info$source_id, "fake_source")
  expect_identical(info$resource_id, "FAKE-CPI")
  expect_false(info$expired)
})

test_that("health checks report without touching a network", {
  health <- source_health(knbs_source("fake_source"))

  expect_identical(health$status, "ok")
  expect_true(is.na(health$http_status))
})

test_that("search to citation works end to end", {
  local_cache()
  source <- knbs_source("fake_source")

  found <- source_search(source, new_knbs_query("survey", filters = list(search = "price")))
  expect_identical(nrow(found), 1L)

  data <- source_fetch(source, new_knbs_query(
    "indicator",
    resource_id = found$resource_id[[1]],
    source = source$source_id
  ))
  citation <- format(knbs_cite(data))

  expect_match(citation, "Fake consumer price index", fixed = TRUE)
  expect_match(citation, "10 April 2020", fixed = TRUE)
  expect_match(citation, "knbsdata version", fixed = TRUE)
})
