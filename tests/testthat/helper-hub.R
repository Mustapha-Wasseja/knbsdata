# Fixtures captured from opendata.knbs.or.ke's DataBrowser hub on 2026-08-08
# (audit F-28): real GDP-by-activity and CPI-by-region dataflow payloads, plus
# a trimmed two-dataflow catalogue. Both network entry points are mocked.

hub_fixture <- function(name) {
  jsonlite::fromJSON(
    testthat::test_path("fixtures", "hub", name),
    simplifyVector = FALSE
  )
}

hub_source <- function() {
  knbs_source("knbs_opendata")
}

hub_default_get <- function(source, path, call = NULL) {
  if (identical(path, "catalog")) {
    return(hub_fixture("catalog-small.json"))
  }
  if (grepl("/structure$", path)) {
    return(hub_fixture("gdp-structure.json"))
  }
  stop("The hub GET mock was asked for an unexpected path: ", path)
}

hub_default_post <- function(source, ref, call = NULL) {
  if (identical(ref, "KE1,DF_NAT_GDPCP,1.0")) {
    return(hub_fixture("gdp-data.json"))
  }
  if (identical(ref, "KE1,DF_CPI_R,1.0")) {
    return(hub_fixture("cpir-data.json"))
  }
  stop("The hub POST mock was asked for an unexpected ref: ", ref)
}

local_hub_api <- function(get_overrides = list(), post_overrides = list(),
                          env = parent.frame()) {
  get_handler <- function(source, path, call = NULL) {
    for (pattern in names(get_overrides)) {
      if (grepl(pattern, path)) {
        value <- get_overrides[[pattern]]
        return(if (is.function(value)) value(path) else value)
      }
    }
    hub_default_get(source, path, call)
  }
  post_handler <- function(source, ref, call = NULL) {
    for (pattern in names(post_overrides)) {
      if (grepl(pattern, ref)) {
        value <- post_overrides[[pattern]]
        return(if (is.function(value)) value(ref) else value)
      }
    }
    hub_default_post(source, ref, call)
  }
  testthat::local_mocked_bindings(
    hub_get = get_handler,
    hub_post_data = post_handler,
    .package = "knbsdata",
    .env = env
  )
}
