# Fixtures captured from cpiexplorer.knbs.or.ke/api/v1 on 2026-08-08, trimmed.
# The default data handler behaves like the live server: it answers only for
# the regions asked, and the "Central" series is empty in every period, both
# as observed live (audit F-26).

cpix_fixture <- function(name) {
  jsonlite::fromJSON(
    testthat::test_path("fixtures", "cpix", name),
    simplifyVector = FALSE
  )
}

cpi_source <- function() {
  knbs_source("knbs_cpi")
}

cpix_default_handler <- function(source, path, query = list(), call = NULL) {
  if (identical(path, "explorer/regions/")) {
    return(cpix_fixture("regions.json"))
  }
  if (identical(path, "periods/")) {
    return(cpix_fixture("periods.json"))
  }
  if (identical(path, "explorer/data/")) {
    regions <- cpix_fixture("regions.json")
    id_to_name <- stats::setNames(
      vapply(regions, function(r) as.character(r$name), character(1)),
      vapply(regions, function(r) as.character(r$id), character(1))
    )
    asked <- id_to_name[as.character(query$`region_id[]`)]
    series <- cpix_fixture("data-small.json")
    return(Filter(function(s) s$metadata$region %in% asked, series))
  }
  if (identical(path, "commodities/")) {
    return(cpix_fixture("commodities.json"))
  }
  if (identical(path, "retail-prices/")) {
    page <- cpix_fixture("retail-page.json")
    if (!is.null(query$period)) {
      page$results <- Filter(
        function(r) identical(r$period, query$period),
        page$results
      )
      page$count <- length(page$results)
    }
    return(page)
  }
  stop("The test mock was asked for an unexpected path: ", path)
}

local_cpix_api <- function(overrides = list(), env = parent.frame()) {
  handler <- function(source, path, query = list(), call = NULL) {
    for (pattern in names(overrides)) {
      if (grepl(pattern, path)) {
        value <- overrides[[pattern]]
        return(if (is.function(value)) value(path, query) else value)
      }
    }
    cpix_default_handler(source, path, query, call)
  }
  testthat::local_mocked_bindings(
    cpix_get = handler,
    .package = "knbsdata",
    .env = env
  )
}
