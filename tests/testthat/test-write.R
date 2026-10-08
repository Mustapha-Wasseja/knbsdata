# Export with provenance. Files go to a per-test temporary directory.

census_table <- function(env = parent.frame()) {
  local_cache(env = env) # nolint: object_usage_linter. Defined in helper-cache.R.
  local_knbsapi(env = env) # nolint: object_usage_linter. Defined in helper-indicators.R.
  knbs_get_indicator("POPCEN0001")
}

test_that("an Excel workbook carries the data and an about sheet", {
  skip_if_not_installed("writexl")
  pop <- census_table()
  path <- file.path(withr::local_tempdir(), "pop.xlsx")

  expect_identical(knbs_write(pop, path, quiet = TRUE), path)
  expect_identical(readxl::excel_sheets(path), c("data", "about"))

  data <- readxl::read_excel(path, sheet = "data", col_types = "text")
  expect_identical(nrow(data), nrow(pop))
  # Codes stay text, leading zeros intact.
  expect_true(all(c("00", "01", "0101") %in% data$geo_code))

  about <- readxl::read_excel(path, sheet = "about")
  expect_named(about, c("field", "value"))
  value_of <- function(f) about$value[about$field == f]
  expect_identical(value_of("Title"), knbs_metadata(pop)$title)
  expect_identical(value_of("Licence"), "CC BY 4.0 (stated on the portal)")
  expect_match(value_of("Citation"), "Kenya National Bureau of Statistics")
})

test_that("CSV, Stata and SPSS files get a provenance sidecar", {
  skip_if_not_installed("haven")
  pop <- census_table()
  dir <- withr::local_tempdir()

  for (ext in c("csv", "dta", "sav")) {
    path <- file.path(dir, paste0("pop.", ext))
    knbs_write(pop, path, quiet = TRUE)
    sidecar <- file.path(dir, paste0("pop.", ext, ".metadata.json"))
    expect_true(file.exists(sidecar), info = ext)
    record <- jsonlite::read_json(sidecar)
    expect_identical(record$format, ext)
    expect_identical(record$title, knbs_metadata(pop)$title)
    expect_match(record$citation, "Kenya National Bureau of Statistics")
    expect_identical(record$rows, nrow(pop))
  }
  # The three files share a stem, not a record: each keeps its own sidecar.
  formats <- vapply(c("csv", "dta", "sav"), function(ext) {
    jsonlite::read_json(file.path(dir, paste0("pop.", ext, ".metadata.json")))$format
  }, character(1), USE.NAMES = FALSE)
  expect_identical(formats, c("csv", "dta", "sav"))

  csv <- readLines(file.path(dir, "pop.csv"))
  expect_true(any(grepl("\"0101\"", csv, fixed = TRUE)))
  stata <- haven::read_dta(file.path(dir, "pop.dta"))
  expect_identical(nrow(stata), nrow(pop))
  expect_identical(attr(stata, "label"), knbs_metadata(pop)$title)
  expect_type(stata$geo_code, "character")
})

test_that("Stata names are shortened, paired and labelled with the original", {
  expect_identical(
    stata_names(c("disability_limits_economic_activity",
                  "disability_limits_economic_activity_code", "value", "2019")),
    c("disability_limits_economic_activ", "disability_limits_economic_code",
      "value", "v_2019")
  )
  expect_true(all(nchar(stata_names(strrep("a", c(40, 40, 40)))) <= 32L))
  expect_false(anyDuplicated(stata_names(strrep("a", c(40, 40, 40)))) > 0L)

  skip_if_not_installed("haven")
  wide <- new_knbs_data(
    tibble::tibble(disability_limits_economic_activity = "Yes",
                   disability_limits_economic_activity_code = "1", value = 3),
    new_knbs_metadata(title = "A wide table")
  )
  path <- file.path(withr::local_tempdir(), "wide.dta")
  knbs_write(wide, path, quiet = TRUE)
  back <- haven::read_dta(path)
  expect_true(all(nchar(names(back)) <= 32L))
  expect_identical(attr(back$disability_limits_economic_code, "label"),
                   "disability_limits_economic_activity_code")
  record <- jsonlite::read_json(file.path(dirname(path), "wide.dta.metadata.json"))
  expect_identical(record$renamed_columns$disability_limits_economic_activity_code,
                   "disability_limits_economic_code")
})

test_that("an .rds file keeps the object whole", {
  pop <- census_table()
  path <- file.path(withr::local_tempdir(), "pop.rds")
  knbs_write(pop, path, quiet = TRUE)
  back <- readRDS(path)
  expect_s3_class(back, "knbs_indicator")
  expect_identical(knbs_metadata(back)$title, knbs_metadata(pop)$title)
})

test_that("a derived table records the provenance it is given", {
  skip_if_not_installed("writexl")
  pop <- census_table()
  totals <- data.frame(geo_code = c("00", "01"), value = c(1, 2))
  dir <- withr::local_tempdir()

  expect_warning(knbs_write(totals, file.path(dir, "bare.csv"), quiet = TRUE),
                 class = "knbs_warning_missing_metadata")
  bare <- jsonlite::read_json(file.path(dir, "bare.csv.metadata.json"))
  expect_match(bare$provenance, "No provenance")

  expect_no_warning(knbs_write(totals, file.path(dir, "derived.xlsx"),
                               metadata = knbs_metadata(pop), quiet = TRUE))
  about <- readxl::read_excel(file.path(dir, "derived.xlsx"), sheet = "about")
  expect_identical(about$value[about$field == "Title"], knbs_metadata(pop)$title)

  knbs_write(totals, file.path(dir, "derived.rds"), metadata = knbs_metadata(pop),
             quiet = TRUE)
  expect_identical(knbs_metadata(readRDS(file.path(dir, "derived.rds")))$title,
                   knbs_metadata(pop)$title)
})

test_that("list columns are written as JSON text, and say so", {
  skip_if_not_installed("writexl")
  vars <- new_knbs_data(
    tibble::tibble(name = c("a", "b"),
                   value_labels = list(list(`1` = "Yes", `2` = "No"), NULL)),
    new_knbs_metadata(title = "Variables")
  )
  path <- file.path(withr::local_tempdir(), "vars.xlsx")
  knbs_write(vars, path, quiet = TRUE)
  data <- readxl::read_excel(path, sheet = "data")
  expect_identical(data$value_labels[[1]], "{\"1\":\"Yes\",\"2\":\"No\"}")
  expect_true(is.na(data$value_labels[[2]]))
  about <- readxl::read_excel(path, sheet = "about")
  expect_identical(about$value[about$field == "Written as JSON text"], "value_labels")
})

test_that("bad requests are refused before anything is written", {
  pop <- census_table()
  dir <- withr::local_tempdir()
  path <- file.path(dir, "pop.csv")
  knbs_write(pop, path, quiet = TRUE)

  expect_error(knbs_write(pop, path, quiet = TRUE), class = "knbs_error_invalid_argument")
  expect_no_error(knbs_write(pop, path, overwrite = TRUE, quiet = TRUE))
  expect_error(knbs_write(pop, file.path(dir, "pop.parquet")),
               class = "knbs_error_invalid_argument")
  expect_error(knbs_write(pop, file.path(dir, "noextension")),
               class = "knbs_error_invalid_argument")
  expect_error(knbs_write(list(a = 1), file.path(dir, "x.csv")),
               class = "knbs_error_invalid_argument")
  expect_error(knbs_write(pop, file.path(dir, "y.csv"), metadata = list(title = "x")),
               class = "knbs_error_invalid_argument")
  expect_false(file.exists(file.path(dir, "pop.parquet")))
})
