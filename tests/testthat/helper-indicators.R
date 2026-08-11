# Fixtures captured from the KNBS Census Data API on 2026-08-08, plus a
# hand-written miniature JSON-stat table exercising the parser. Tests mock the
# adapter's single network entry point, so nothing here makes a request.

knbsapi_fixture <- function(name) {
  jsonlite::fromJSON(
    testthat::test_path("fixtures", "knbsapi", name),
    simplifyVector = FALSE
  )
}

indicators_source <- function() {
  knbs_source("knbs_indicators")
}

# The miniature JSON-stat table used throughout the parser tests.
mini <- function() {
  knbsapi_fixture("dataset-small.json")
}

#' Mock the census API for the duration of a test
#'
#' @param overrides Named list mapping a path pattern to a value or a function
#'   of (path, query).
local_knbsapi <- function(overrides = list(), env = parent.frame()) {
  handler <- function(source, path, query = list(), call = NULL) {
    for (pattern in names(overrides)) {
      if (grepl(pattern, path)) {
        value <- overrides[[pattern]]
        return(if (is.function(value)) value(path, query) else value)
      }
    }
    if (identical(path, "getDatasetList")) {
      return(knbsapi_fixture("dataset-list.json"))
    }
    if (identical(path, "getDataset")) {
      if (identical(query$id, "NO-SUCH-ID")) {
        # The live API answers 200 "errore"; indicators_get() turns that into
        # this condition, so the mock raises it at the same boundary.
        knbs_abort("The source has no dataset with that identifier.",
                   class = "knbs_error_resource_not_found")
      }
      return(knbsapi_fixture("dataset-small.json"))
    }
    stop("The test mock was asked for an unexpected path: ", path)
  }

  testthat::local_mocked_bindings(
    indicators_get = handler,
    .package = "knbsdata",
    .env = env
  )
  # knbs_indicators() aggregates every verified indicator source, so census
  # tests need the other sources' entry points mocked too or they would reach
  # the network.
  testthat::local_mocked_bindings(
    cpix_get = cpix_default_handler, # nolint: object_usage_linter. Defined in helper-cpix.R.
    hub_get = hub_default_get, # nolint: object_usage_linter. Defined in helper-hub.R.
    hub_post_data = hub_default_post, # nolint: object_usage_linter. Defined in helper-hub.R.
    knoema_get = knoema_default_get, # nolint: object_usage_linter. Defined in helper-knoema.R.
    .package = "knbsdata",
    .env = env
  )
}
