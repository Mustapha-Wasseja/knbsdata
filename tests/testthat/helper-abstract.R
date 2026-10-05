# The real Chapter 2 (National Accounts) workbook of the 2025 Statistical
# Abstract, downloaded from the KNBS media library on 2026-08-11 (audit F-35).
# Extraction tests read it directly; public-function tests mock the workbook
# fetch so nothing touches the network.

abstract_fixture_path <- function() {
  testthat::test_path("fixtures", "abstract",
                      "NA-Statistical-Abstract_2025-1.xlsx")
}

# Chapters 3-16: the sheets the registry curates, copied cell for cell (as the
# text readxl reads) from the real 2025 chapter workbooks downloaded from the
# KNBS media library on 2026-10-06. The full workbooks run to several
# megabytes; only trailing empty rows and columns differ from them.
abstract_chapters_fixture_path <- function() {
  testthat::test_path("fixtures", "abstract",
                      "Statistical-Abstract-2025-chapters-subset.xlsx")
}

abstract_fixture_cells <- function(sheet, path = abstract_fixture_path()) {
  readxl::read_excel(path, sheet = sheet,
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
        path = if (identical(workbook$workbook_id, "na")) {
          abstract_fixture_path()
        } else {
          abstract_chapters_fixture_path()
        },
        url = paste0("https://www.knbs.or.ke/wp-content/uploads/2026/01/",
                     workbook$file_name),
        sha256 = "fixture-sha256-not-computed"
      )
    },
    .package = "knbsdata",
    .env = env
  )
  # County tables take their census codes from the census frame's names.
  local_counties(env = env) # nolint: object_usage_linter. Defined in helper-counties.R.
}
