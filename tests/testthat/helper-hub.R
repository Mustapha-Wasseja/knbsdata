# Fixtures captured from opendata.knbs.or.ke's DataBrowser hub on 2026-08-08
# (audit F-28): real GDP-by-activity and CPI-by-region dataflow payloads, plus
# a trimmed two-dataflow catalogue. cpina-data.json is the whole retail-price
# dataflow DF_CPI_NA as served on 2026-11-06 (audit F-45): 22 commodities,
# February 2019 to July 2026. Both network entry points are mocked.

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
  if (identical(ref, "KE1,DF_CPI_NA,1.0")) {
    return(hub_fixture("cpina-data.json"))
  }
  stop("The hub POST mock was asked for an unexpected ref: ", ref)
}

# The trimmed catalogue with the retail-price dataflow added, kept apart from
# the default so the catalogue counts other tests pin stay as they are.
hub_catalog_retail <- function() {
  catalog <- hub_fixture("catalog-small.json")
  ref <- "KE1,DF_CPI_NA,1.0"
  catalog$datasetMap[[ref]] <- list(title = "National Average Retail Prices",
                                    datasetType = "dataflow")
  catalog$categoryGroups[[1]]$categories[[2]]$datasetIdentifiers <-
    list("KE1,DF_CPI_R,1.0", ref)
  catalog
}

# The Data Portal serving retail prices.
local_retail_portal <- function(post_overrides = list(), env = parent.frame()) {
  local_hub_api(get_overrides = list("^catalog$" = hub_catalog_retail()),
                post_overrides = post_overrides, env = env)
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
