# Fixtures captured from www.knbs.or.ke/wp-json/wp/v2 on 2026-08-08. As with
# the NADA helper, the adapter's single network entry point is mocked, so no
# test makes a request.

wp_fixture <- function(name) {
  payload <- jsonlite::fromJSON(
    testthat::test_path("fixtures", "knbs-wp", name),
    simplifyVector = FALSE
  )
  attr(payload, "wp_total") <- length(payload)
  attr(payload, "wp_total_pages") <- 1L
  payload
}

wp_source <- function() {
  knbs_source("knbs_publications")
}

local_wp_api <- function(overrides = list(), env = parent.frame()) {
  handler <- function(source, path, query = list(), call = NULL) {
    for (pattern in names(overrides)) {
      if (grepl(pattern, path)) {
        value <- overrides[[pattern]]
        return(if (is.function(value)) value(path, query) else value)
      }
    }
    if (grepl("^media/[0-9]+$", path)) {
      return(wp_fixture("media-single.json"))
    }
    if (identical(path, "media")) {
      return(wp_fixture("media-listing.json"))
    }
    stop("The test mock was asked for an unexpected path: ", path)
  }

  testthat::local_mocked_bindings(
    wp_get = handler,
    .package = "knbsdata",
    .env = env
  )
}
