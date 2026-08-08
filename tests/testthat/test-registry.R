test_that("the shipped registry is valid", {
  expect_no_error(read_source_registry())
})

test_that("verified and unverified sources are marked consistently", {
  # Phase 1 gate: a source may only leave "discovery" once its base_url, terms
  # and access conditions have been checked and recorded in the source audit.
  sources <- knbs_sources()
  verified <- sources$base_url != "PLACEHOLDER_TO_VERIFY"

  # Unverified: still in discovery, no verification date.
  expect_true(all(sources$stability[!verified] == "discovery"))
  expect_true(all(is.na(sources$last_verified[!verified])))

  # Verified: HTTPS endpoint - or plain HTTP only where the registry entry
  # declares http_only (a host with no TLS listener, audit F-16) - and a
  # recorded verification date.
  raw <- read_source_registry()$sources
  http_only_ids <- vapply(
    raw[vapply(raw, function(s) isTRUE(s$http_only), logical(1))],
    function(s) s$source_id, character(1)
  )
  https_ok <- startsWith(sources$base_url, "https://") |
    (startsWith(sources$base_url, "http://") & sources$source_id %in% http_only_ids)
  expect_true(all(https_ok[verified]))
  expect_true(all(!is.na(sources$last_verified[verified])))

  # Nothing has earned "stable" yet: that needs fixtures, monitoring and a
  # documented schema contract.
  expect_false(any(sources$stability == "stable"))
})

test_that("kenada is registered as audited, metadata-only", {
  kenada <- knbs_sources()[knbs_sources()$source_id == "kenada", ]

  expect_identical(nrow(kenada), 1L)
  expect_identical(kenada$stability, "experimental")
  expect_identical(kenada$last_verified, as.Date("2026-08-03"))

  # Microdata download is gated behind a login (audit finding F-03), so the
  # source must not advertise a download operation.
  expect_false("download_public_files" %in% kenada$operations[[1]])
  expect_true(all(
    c("search_surveys", "survey_metadata", "variables", "files") %in%
      kenada$operations[[1]]
  ))
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
  expect_identical(
    nrow(knbs_sources(status = c("discovery", "experimental"))),
    nrow(knbs_sources())
  )

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

test_that("http_only is an explicit, validated exception to the HTTPS rule", {
  # A host with no TLS listener (audit F-16) may declare itself http_only.
  expect_no_error(
    validate_source_registry(test_registry(test_source(
      base_url = "http://example.org",
      http_only = TRUE,
      stability = "experimental",
      last_verified = "2026-08-08"
    )))
  )
  # The flag must be literally true, not any truthy junk.
  expect_error(
    validate_source_registry(test_registry(test_source(
      base_url = "http://example.org",
      http_only = "yes",
      stability = "experimental"
    ))),
    class = "knbs_error_validation_failed"
  )
  # The flag does not excuse a placeholder from the discovery rule.
  expect_error(
    validate_source_registry(test_registry(test_source(
      http_only = TRUE,
      stability = "beta"
    ))),
    class = "knbs_error_validation_failed"
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
