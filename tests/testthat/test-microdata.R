labelled_frame <- function() {
  tibble::tibble(
    id = 1:3,
    sex = haven::labelled(c(1, 2, 1), c(Male = 1, Female = 2), label = "Sex of respondent")
  )
}

test_that("Stata and SPSS files are read with their labels", {
  skip_if_not_installed("haven")
  dir <- withr::local_tempdir()
  haven::write_dta(labelled_frame(), file.path(dir, "s.dta"))
  haven::write_sav(labelled_frame(), file.path(dir, "s.sav"))

  for (name in c("s.dta", "s.sav")) {
    back <- knbs_read_microdata(file.path(dir, name))
    # No sidecar, so no provenance to attach: a plain tibble.
    expect_false(inherits(back, "knbs_data"), info = name)
    expect_true(haven::is.labelled(back$sex), info = name)
    expect_identical(attr(back$sex, "label"), "Sex of respondent", info = name)
  }
  # Reader arguments pass through.
  expect_named(knbs_read_microdata(file.path(dir, "s.dta"), col_select = "id"), "id")
})

test_that("Excel files are read too, and other formats refused", {
  dir <- withr::local_tempdir()
  xlsx <- test_path("fixtures", "abstract", "Statistical-Abstract-2025-chapters-subset.xlsx")
  skip_if_not(file.exists(xlsx))
  sheet <- knbs_read_microdata(xlsx, sheet = 1, range = "A1:B2", col_names = c("a", "b"))
  expect_s3_class(sheet, "tbl_df")
  expect_named(sheet, c("a", "b"))

  writeLines("a,b", file.path(dir, "data.csv"))
  expect_error(knbs_read_microdata(file.path(dir, "data.csv")),
               class = "knbs_error_invalid_argument")
  expect_error(knbs_read_microdata(file.path(dir, "missing.dta")),
               class = "knbs_error_resource_not_found")
})

test_that("the data file inside an archive is found, read and cleaned up", {
  skip_if_not_installed("haven")
  before <- list.files(tempdir(), pattern = "^knbs-unzip-")

  # round.zip holds a questionnaire and one data file.
  back <- knbs_read_microdata(finaccess_fixture("round.zip"))
  expect_identical(nrow(back), 3L)
  expect_true(haven::is.labelled(back$sex))
  expect_identical(list.files(tempdir(), pattern = "^knbs-unzip-"), before)

  # two-files.zip holds two: one must be named.
  expect_error(knbs_read_microdata(finaccess_fixture("two-files.zip")),
               class = "knbs_error_ambiguous_resource")
  chosen <- knbs_read_microdata(finaccess_fixture("two-files.zip"), file = "other.dta")
  expect_identical(nrow(chosen), 3L)
  expect_error(knbs_read_microdata(finaccess_fixture("two-files.zip"), file = "nope.sav"),
               class = "knbs_error_resource_not_found")
})

test_that("file names an archive entry and nothing else", {
  skip_if_not_installed("haven")
  path <- file.path(withr::local_tempdir(), "s.dta")
  haven::write_dta(labelled_frame(), path)
  expect_error(knbs_read_microdata(path, file = "s.dta"),
               class = "knbs_error_invalid_argument")
})

test_that("a provenance sidecar makes the result citable", {
  skip_if_not_installed("haven")
  dir <- withr::local_tempdir()
  local_finaccess_drive(list(
    driveStata0000000000000 = list(name = "FinAccess_2024.dta", bytes = local({
      path <- tempfile(fileext = ".dta")
      haven::write_dta(labelled_frame(), path)
      readBin(path, "raw", file.size(path))
    }))
  ))
  # The pretend catalogue pins other bytes, so keep what is served.
  record <- knbs_download_finaccess("hh2024-stata", dir, verify = FALSE, quiet = TRUE)

  fa <- knbs_read_microdata(record)
  expect_s3_class(fa, "knbs_microdata")
  meta <- knbs_metadata(fa)
  expect_identical(meta$resource_id, "hh2024-stata")
  expect_identical(meta$resource_type, "microdata")
  expect_identical(meta$checksum, record$sha256)
  expect_identical(meta$source_url, "https://finaccess.knbs.or.ke/reports-and-datasets")
  expect_identical(meta$reference_period, "2024")

  citation <- format(knbs_cite(fa))
  expect_match(citation, "^Central Bank of Kenya, Kenya National Bureau of Statistics and FSD Kenya\\.")
  expect_match(citation, "FinAccess Household Survey 2024", fixed = TRUE)
})

test_that("a download record picks out its one data file", {
  skip_if_not_installed("haven")
  dir <- withr::local_tempdir()
  haven::write_dta(labelled_frame(), file.path(dir, "s.dta"))
  writeLines("%PDF-1.4", file.path(dir, "q.pdf"))
  record <- tibble::tibble(local_path = file.path(dir, c("q.pdf", "s.dta")))
  expect_identical(nrow(knbs_read_microdata(record)), 3L)

  both <- tibble::tibble(local_path = file.path(dir, c("s.dta", "s.dta")))
  expect_error(knbs_read_microdata(both), class = "knbs_error_invalid_argument")
  expect_error(knbs_read_microdata(data.frame(x = 1)), class = "knbs_error_invalid_argument")
})

test_that("a sidecar from an earlier version is used only if it names the file", {
  skip_if_not_installed("haven")
  dir <- withr::local_tempdir()
  haven::write_dta(labelled_frame(), file.path(dir, "data.dta"))
  legacy <- file.path(dir, "data.metadata.json")

  jsonlite::write_json(list(original_name = "data.sav", title = "The SPSS copy"),
                       legacy, auto_unbox = TRUE)
  expect_false(inherits(knbs_read_microdata(file.path(dir, "data.dta")), "knbs_data"))

  jsonlite::write_json(list(original_name = "data.dta", title = "The Stata copy"),
                       legacy, auto_unbox = TRUE)
  expect_identical(knbs_metadata(knbs_read_microdata(file.path(dir, "data.dta")))$title,
                   "The Stata copy")
})

test_that("the remnant of a byte-order mark is removed from the first name only", {
  mojibake <- paste0(intToUtf8(c(0xC3, 0xAF)), "interview__key")
  expect_identical(microdata_repair_names(c(mojibake, "b2")), c("interview__key", "b2"))
  expect_identical(microdata_repair_names(paste0(intToUtf8(0xFEFF), "a1")), "a1")
  expect_identical(microdata_repair_names(paste0(intToUtf8(c(0xEF, 0xBB, 0xBF)), "s")), "s")
  # Not the first name, a clash with another name, or nothing left: untouched.
  expect_identical(microdata_repair_names(c("a", mojibake)), c("a", mojibake))
  clash <- c(paste0(intToUtf8(0xEF), "b2"), "b2")
  expect_identical(microdata_repair_names(clash), clash)
  expect_identical(microdata_repair_names(character(0)), character(0))
})
