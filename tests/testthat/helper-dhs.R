# Responses of the DHS Program Indicator Data API, captured 2026-10-08 and
# trimmed: stunting (CN_NUTS_C_HA2) for 2008, 2014 and 2022 with its region and
# county rows; antenatal care (RH_ANCP_W_NON), whose 1989 values come for three
# reference periods; malaria prevalence (ML_PMAL_C_RDT) by malaria zone; and
# an id the listing repeats under two labels (CH_ARSS_C_NGO).

dhs_fixture <- function(name) {
  parse_json_file(test_path("fixtures", "dhs", name), source_id = "dhs_program")
}

dhs_source <- function() knbs_source("dhs_program")

dhs_default_get <- function(source, path, query = list(), call = NULL) {
  if (identical(path, "info")) {
    return(dhs_fixture("version.json"))
  }
  if (identical(path, "surveys")) {
    return(dhs_fixture("surveys.json"))
  }
  if (identical(path, "indicators")) {
    listing <- dhs_fixture("indicators.json")
    if (!is.null(query$indicatorIds)) {
      listing$Data <- Filter(function(r) identical(r$IndicatorId, query$indicatorIds),
                             listing$Data)
    }
    return(listing)
  }
  if (identical(path, "data")) {
    file <- switch(as.character(query$indicatorIds %||% ""),
      CN_NUTS_C_HA2 = "data-stunting.json",
      RH_ANCP_W_NON = "data-anc.json",
      ML_PMAL_C_RDT = "data-malaria.json",
      "data-empty.json"
    )
    return(dhs_fixture(file))
  }
  stop("The test mock was asked for an unexpected path: ", path)
}

local_dhs_api <- function(handler = dhs_default_get, env = parent.frame()) {
  testthat::local_mocked_bindings(dhs_get = handler, .package = "knbsdata", .env = env)
}
