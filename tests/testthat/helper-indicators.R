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

# Observed 2026-10-05: the census API labels POPCEN0002, POPCEN0003 and
# POPCEN0004 alike, while its dataset list names each one correctly.
repeated_census_label <- "Census 2019 - Population by sex and marital status"

# A getDataset override serving the miniature table under that label.
mislabelled_dataset <- function(path, query) {
  payload <- knbsapi_fixture("dataset-small.json")
  payload$label <- repeated_census_label
  payload
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

#' A hand-built census table: one dimension under test, by sex and territory
#'
#' @param dim_id,dim_label The dimension's source id and label.
#' @param codes,labels Its categories.
#' @param base Named numeric: the value of each code in the first cell; the
#'   other cells are multiples of it, so every cell keeps the same structure.
census_payload <- function(dim_id, dim_label, codes, labels, base) {
  factors <- c(10, 4, 6, 2) # (Total, Kenya), (Total, Mombasa), (Male, ...)
  values <- unlist(lapply(codes, function(code) base[[code]] * factors))
  dimension <- list(
    list(label = dim_label,
         category = list(index = as.list(codes),
                         label = stats::setNames(as.list(labels), codes))),
    list(label = "Sex",
         category = list(index = list("T", "1"),
                         label = list(T = "Total", `1` = "Male"))),
    list(label = "Territory",
         category = list(index = list("00", "01"),
                         label = list(`00` = "Kenya", `01` = "Mombasa")))
  )
  names(dimension) <- c(dim_id, "p11_vs1", "system_total")
  list(
    class = "dataset",
    version = "2.0",
    label = "Census 2019 - hand-built test table",
    source = "KNBS Population Census 2019",
    updated = "2019-12-31",
    id = list(dim_id, "p11_vs1", "system_total"),
    size = list(length(codes), 2L, 2L),
    dimension = dimension,
    value = as.list(values)
  )
}

#' The census age table in miniature: a total, single years, their groups,
#' and an open-ended group with no single years of its own
census_age_payload <- function() {
  codes <- c("T", "0", "1", "0-1", "2", "3", "2-3", "100-120", "   ")
  labels <- c("Total", "0", "1", "0 - 1", "2", "3", "2 - 3", "100 - 120", "NR")
  base <- c(T = 15, `0` = 1, `1` = 2, `0-1` = 3, `2` = 3, `3` = 4, `2-3` = 7,
            `100-120` = 5, `   ` = NA)
  census_payload("p12_vs3", "Single and Grouped Ages", codes, labels, base)
}
