test_that("the shipped registry is valid", {
  expect_no_error(read_source_registry())
})

test_that("no shipped source claims verified status yet", {
  # Phase 1 gate: a source may only leave "discovery" once its base_url, terms
  # and access conditions have been checked and recorded in the source audit.
  sources <- knbs_sources()

  expect_true(all(sources$stability == "discovery"))
  expect_true(all(sources$base_url == "PLACEHOLDER_TO_VERIFY"))
  expect_true(all(is.na(sources$last_verified)))
})

test_that("knbs_sources() returns the documented schema", {
  sources <- knbs_sources()

  expect_s3_class(sources, "tbl_df")
  expect_named(
    sources,
    c(
      "source_id", "source_name", "source_type", "operations",
      "stability", "authentication", "last_verified", "base_url"
    )
  )
  expect_type(sources$operations, "list")
  expect_s3_class(sources$last_verified, "Date")
  expect_identical(anyDuplicated(sources$source_id), 0L)
  expect_gt(nrow(sources), 0L)
})

test_that("knbs_sources() filters by operation and status", {
  surveys <- knbs_sources(operation = "search_surveys")
  expect_true(all(vapply(surveys$operations, function(x) "search_surveys" %in% x, logical(1))))
  expect_true("kenada" %in% surveys$source_id)
  expect_false("knbs_publications" %in% surveys$source_id)

  expect_identical(nrow(knbs_sources(status = "stable")), 0L)
  expect_identical(nrow(knbs_sources(status = "discovery")), nrow(knbs_sources()))

  # Multiple operations must all be supported by the same source.
  both <- knbs_sources(operation = c("search_surveys", "get_indicator"))
  expect_true(all(both$source_id == "fake_source"))
})

test_that("knbs_sources() rejects unknown filters", {
  expect_error(knbs_sources(operation = "teleport"), class = "knbs_error_invalid_argument")
  expect_error(knbs_sources(status = "perfect"), class = "knbs_error_invalid_argument")
  expect_error(knbs_sources(operation = 1), class = "knbs_error_invalid_argument")
})

test_that("registry structure is validated", {
  expect_error(
    validate_source_registry(list(sources = list(test_source()))),
    class = "knbs_error_validation_failed"
  )
  expect_error(
    validate_source_registry(list(schema_version = 2L, sources = list(test_source()))),
    class = "knbs_error_validation_failed"
  )
  expect_error(
    validate_source_registry(list(schema_version = 1L, sources = list())),
    class = "knbs_error_validation_failed"
  )
})

test_that("source identifiers must be unique and snake case", {
  expect_error(
    validate_source_registry(test_registry(test_source(), test_source())),
    class = "knbs_error_validation_failed"
  )
  expect_error(
    validate_source_registry(test_registry(test_source(source_id = "Test-Source"))),
    class = "knbs_error_validation_failed"
  )
})

test_that("required fields must be present", {
  incomplete <- test_source()
  incomplete$adapter <- NULL

  expect_error(
    validate_source_registry(test_registry(incomplete)),
    class = "knbs_error_validation_failed"
  )
})

test_that("controlled vocabularies are enforced", {
  expect_error(
    validate_source_registry(test_registry(test_source(operations = c("search_surveys", "mine_bitcoin")))),
    class = "knbs_error_validation_failed"
  )
  expect_error(
    validate_source_registry(test_registry(test_source(stability = "probably_fine"))),
    class = "knbs_error_validation_failed"
  )
  expect_error(
    validate_source_registry(test_registry(test_source(authentication = "vibes"))),
    class = "knbs_error_validation_failed"
  )
  expect_error(
    validate_source_registry(test_registry(test_source(source_type = "spreadsheet"))),
    class = "knbs_error_validation_failed"
  )
})

test_that("base URLs must be HTTPS or an explicit placeholder", {
  expect_error(
    validate_source_registry(test_registry(test_source(
      base_url = "http://example.org",
      stability = "beta"
    ))),
    class = "knbs_error_validation_failed"
  )
  expect_no_error(
    validate_source_registry(test_registry(test_source(
      base_url = "https://example.org",
      stability = "beta",
      last_verified = "2026-08-03"
    )))
  )
})

test_that("an unverified source cannot claim stability", {
  expect_error(
    validate_source_registry(test_registry(test_source(stability = "stable"))),
    class = "knbs_error_validation_failed"
  )
})

test_that("last_verified must be a valid date", {
  expect_error(
    validate_source_registry(test_registry(test_source(last_verified = "soon"))),
    class = "knbs_error_validation_failed"
  )
  expect_no_error(
    validate_source_registry(test_registry(test_source(last_verified = "2026-08-03")))
  )
})

test_that("a missing registry file fails clearly", {
  expect_error(
    read_source_registry(file.path(tempdir(), "no-such-registry.yml")),
    class = "knbs_error_validation_failed"
  )
})

test_that("a malformed registry file fails clearly", {
  path <- withr::local_tempfile(fileext = ".yml")
  writeLines(c("schema_version: 1", "sources:", "  - source_id: [unclosed"), path)

  expect_error(read_source_registry(path), class = "knbs_error_parse_failed")
})
