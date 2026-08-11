# The real Chapter 2 (National Accounts) workbook of the 2025 Statistical
# Abstract, downloaded from the KNBS media library on 2026-08-11 (audit F-35).
# Extraction tests read it directly; public-function tests mock the workbook
# fetch so nothing touches the network.

abstract_fixture_path <- function() {
  testthat::test_path("fixtures", "abstract",
                      "NA-Statistical-Abstract_2025-1.xlsx")
}

abstract_fixture_cells <- function(sheet) {
  readxl::read_excel(abstract_fixture_path(), sheet = sheet,
                     col_names = FALSE, col_types = "text",
                     .name_repair = "minimal")
}

abstract_spec <- function(table_id) {
  registry <- abstract_registry()
  for (spec in registry$tables) {
    if (identical(spec$table_id, table_id)) {
      return(spec)
    }
  }
  stop("No such spec in the abstract registry: ", table_id)
}

local_abstract_workbook <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(
    abstract_fetch_workbook = function(source, workbook, refresh = FALSE,
                                       call = NULL) {
      list(
        path = abstract_fixture_path(),
        url = paste0("https://www.knbs.or.ke/wp-content/uploads/2026/01/",
                     "NA-Statistical-Abstract_2025-1.xlsx"),
        sha256 = "fixture-sha256-not-computed"
      )
    },
    .package = "knbsdata",
    .env = env
  )
}
