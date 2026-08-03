# Builders for registry fixtures. Tests modify one field at a time so that a
# failure points at exactly one validation rule.

test_source <- function(...) {
  utils::modifyList(
    list(
      source_id = "test_source",
      source_name = "Test source",
      owner = "knbsdata tests",
      source_type = "fake",
      base_url = "PLACEHOLDER_TO_VERIFY",
      adapter = "fake",
      operations = c("search_surveys", "survey_metadata"),
      authentication = "none",
      stability = "discovery",
      last_verified = NULL
    ),
    list(...),
    keep.null = TRUE
  )
}

test_registry <- function(...) {
  sources <- list(...)
  if (length(sources) == 0L) {
    sources <- list(test_source())
  }
  list(schema_version = 1L, sources = sources)
}
