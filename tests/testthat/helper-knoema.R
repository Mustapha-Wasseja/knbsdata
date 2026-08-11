# Fixtures captured from kenya.opendataforafrica.org on 2026-08-11 (audit
# F-30): the Gross County Product dataset (annual, geographic, one genuinely
# null cell), the nominal interest rates dataset (annual and quarterly series
# side by side, audit F-33) and the money supply dataset (annual and monthly),
# plus a three-dataset listing. The listing deliberately keeps the live API's
# hasGeoDimension false for the GCP dataset - the listing really says that
# while the dataset's own metadata says true (audit F-32) - so these tests
# also pin that structure is never read from the listing.

knoema_fixture <- function(name) {
  jsonlite::fromJSON(
    testthat::test_path("fixtures", "knoema", name),
    simplifyVector = FALSE
  )
}

knoema_test_source <- function() {
  knbs_source("opendataforafrica")
}

knoema_default_get <- function(source, path, query = list(), call = NULL) {
  if (identical(path, "1.0/meta/dataset")) {
    return(knoema_fixture("datasets-small.json"))
  }
  if (identical(path, "1.0/meta/dataset/jhbzkjc")) {
    return(knoema_fixture("gcp-meta.json"))
  }
  if (identical(path, "1.0/meta/dataset/doflnmd")) {
    return(knoema_fixture("rates-meta.json"))
  }
  if (identical(path, "1.0/meta/dataset/gvhnvfe")) {
    return(knoema_fixture("money-meta.json"))
  }
  if (identical(path, "2.0/data")) {
    id <- as.character(query$datasetId %||% "")
    if (identical(id, "jhbzkjc")) {
      return(knoema_fixture("gcp-data.json"))
    }
    if (identical(id, "doflnmd")) {
      return(knoema_fixture("rates-data.json"))
    }
    if (identical(id, "gvhnvfe")) {
      return(knoema_fixture("money-data.json"))
    }
  }
  # The live API answers 200 with a bare explanatory string for an unknown
  # dataset (audit F-31); knoema_get() turns that into this condition, so the
  # mock raises it at the same boundary.
  knbs_abort("The source has no dataset with that identifier.",
             class = "knbs_error_resource_not_found")
}

local_knoema_api <- function(overrides = list(), env = parent.frame()) {
  handler <- function(source, path, query = list(), call = NULL) {
    for (pattern in names(overrides)) {
      if (grepl(pattern, path)) {
        value <- overrides[[pattern]]
        return(if (is.function(value)) value(path, query) else value)
      }
    }
    knoema_default_get(source, path, query, call)
  }
  testthat::local_mocked_bindings(
    knoema_get = handler,
    .package = "knbsdata",
    .env = env
  )
}
