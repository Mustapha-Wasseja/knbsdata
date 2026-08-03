# Fixtures captured from the Kenya National Data Archive on 2026-08-03. Tests
# mock the adapter's single network entry point, so no test ever makes a
# request, and the fixtures pin the exact payload shapes the audit observed.

kenada_fixture <- function(name) {
  jsonlite::fromJSON(
    testthat::test_path("fixtures", "kenada", name),
    simplifyVector = FALSE
  )
}

kenada_source <- function() {
  knbs_source("kenada")
}

#' Mock the NADA API for the duration of a test
#'
#' @param overrides Named list mapping a path pattern to a value or a function.
#'   A value is returned as-is; a function is called with the path.
local_kenada_api <- function(overrides = list(), env = parent.frame()) {
  handler <- function(source, path, query = list(), call = NULL) {
    for (pattern in names(overrides)) {
      if (grepl(pattern, path)) {
        value <- overrides[[pattern]]
        return(if (is.function(value)) value(path) else value)
      }
    }
    if (grepl("/variables/", path)) {
      return(kenada_fixture("variable-detail.json"))
    }
    if (endsWith(path, "/variables")) {
      return(kenada_fixture("variables.json"))
    }
    if (endsWith(path, "/data_files")) {
      return(kenada_fixture("data-files.json"))
    }
    if (identical(path, "catalog/search")) {
      return(kenada_fixture("catalog-search.json"))
    }
    if (startsWith(path, "catalog/")) {
      return(kenada_fixture("study-metadata.json"))
    }
    stop("The test mock was asked for an unexpected path: ", path)
  }

  testthat::local_mocked_bindings(
    nada_get = handler,
    .package = "knbsdata",
    .env = env
  )
}
