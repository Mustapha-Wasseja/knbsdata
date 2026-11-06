# County budget execution from the Controller of Budget's reports (audit
# F-47): the figures shipped with the package, and the recipes they were
# built by, re-read from page-text fixtures of three reports.

test_that("the shipped figures cover eleven years, every county and the total", {
  budget <- knbs_county_budget()
  expect_s3_class(budget, "knbs_data")
  expect_named(budget, c("fiscal_year", "geo_code", "county", "measure", "value", "unit",
                         "status", "table_id", "printed", "pages", "source_id"))
  years <- sprintf("%d/%02d", 2013:2023, 14:24)
  expect_identical(sort(unique(budget$fiscal_year)), years)
  totals <- budget[budget$measure == "expenditure_total", ]
  expect_true(all(table(totals$fiscal_year) == 48L))
  expect_setequal(unique(budget$geo_code), c(sprintf("%02d", 1:47), "00"))
  expect_setequal(unique(budget$unit), c("KSh million", "percent"))
  expect_true(all(budget$source_id == "controller_of_budget"))
  expect_false(anyDuplicated(paste(budget$fiscal_year, budget$geo_code, budget$measure)) > 0L)
})

test_that("the shipped figures obey the tables' own identities", {
  budget <- tibble::as_tibble(knbs_county_budget())
  wide <- stats::reshape(
    as.data.frame(budget[budget$fiscal_year >= "2014/15", c("fiscal_year", "geo_code", "measure", "value", "status")]),
    idvar = c("fiscal_year", "geo_code"), timevar = "measure", direction = "wide", drop = "status"
  )
  col <- function(m) wide[[paste0("value.", m)]]
  gap <- function(total, a, b) col(total) - col(a) - col(b)
  county <- wide$geo_code != "00"
  expect_lte(max(abs(gap("budget_total", "budget_recurrent", "budget_development")[county])), 0.015)
  spend <- gap("expenditure_total", "expenditure_recurrent", "expenditure_development")
  # Busia 2015/16 is the one printed misprint: 5,865.76 against 5,896.98.
  busia <- wide$geo_code == "40" & wide$fiscal_year == "2015/16"
  expect_lte(max(abs(spend[county & !busia])), 0.015)
  expect_equal(spend[busia], 5865.76 - 5896.98, tolerance = 1e-6)
  expect_identical(budget$status[budget$geo_code == "40" & budget$fiscal_year == "2015/16" &
                                   budget$measure == "expenditure_total"], "misprint")
})

test_that("FY 2014/15 is converted to millions, FY 2013/14 totals are derived", {
  fy14 <- knbs_county_budget(fiscal_year = "2014/15", county = "Baringo", measure = "budget_recurrent")
  expect_equal(fy14$value, 2960.575785)
  expect_identical(fy14$unit, "KSh million")
  fy13 <- knbs_county_budget(fiscal_year = "2013/14", county = "Mombasa")
  total <- fy13[fy13$measure == "expenditure_total", ]
  expect_identical(total$status, "derived")
  expect_equal(total$value, 442.5 + 4767.3)
  expect_true(is.na(fy13$status[fy13$measure == "expenditure_assembly_total"]))
})

test_that("filters by year, county and measure, and refuses what it does not hold", {
  x <- knbs_county_budget(fiscal_year = "2023/24", county = c("Nairobi City", "00"),
                          measure = "expenditure_total")
  expect_identical(x$county, c("Nairobi City", "Kenya"))
  expect_identical(x$value, c(31789.13, 446763.19))
  expect_identical(nrow(knbs_county_budget(county = "47", measure = "absorption_development")), 10L)
  expect_error(knbs_county_budget(fiscal_year = "2030/31"), class = "knbs_error_invalid_argument")
  expect_error(knbs_county_budget(measure = "happiness"), class = "knbs_error_invalid_argument")
  meta <- knbs_metadata(x)
  expect_identical(meta$producer, "Office of the Controller of Budget")
  expect_match(meta$title, "FY 2023/24", fixed = TRUE)
  expect_match(format(knbs_cite(meta)), "Controller of Budget", fixed = TRUE)
})

test_that("a report the package cannot fetch asks for your copy, and checks it", {
  local_cache()
  local_report_pdfs()
  expect_error(knbs_report_table("cob-2015-16-budget"), class = "knbs_error_access_restricted",
               regexp = "knbs_county_budget")
  not_pdf <- withr::local_tempfile(fileext = ".pdf")
  writeLines("hello", not_pdf)
  expect_error(knbs_report_table("cob-2015-16-budget", file = not_pdf),
               class = "knbs_error_invalid_argument", regexp = "not a PDF")
  expect_error(knbs_report_table("cob-2015-16-budget", file = "no-such-file.pdf"),
               class = "knbs_error_invalid_argument")

  table <- knbs_report_table("cob-2015-16-budget", file = report_copy("cob-2015-16"))
  expect_identical(unique(table$source_id), "controller_of_budget")
  expect_match(paste(knbs_metadata(table)$notes, collapse = " "), "differs from the one curated", fixed = TRUE)
  # Re-read from the report, the table is what the package ships.
  shipped <- knbs_county_budget(fiscal_year = "2015/16")
  key <- paste(table$geo_code, table$column)
  expect_identical(table$value, shipped$value[match(key, paste(shipped$geo_code, shipped$measure))])
})

test_that("rows printed over two lines are reunited by position", {
  local_cache()
  local_report_pdfs()
  table <- knbs_report_table("cob-2015-16-budget", file = report_copy("cob-2015-16"))
  value <- function(code, column) table$value[table$geo_code == code & table$column == column]
  # Five-digit totals are set on a lower baseline: on the next line in the text.
  expect_identical(value("39", "budget_total"), 10053.70)
  expect_identical(value("22", "expenditure_total"), 10427.29)
  # Nairobi City runs over three lines.
  expect_identical(value("47", "budget_recurrent"), 21209.40)
  expect_identical(value("47", "budget_development"), 7878.67)
  expect_identical(value("47", "absorption_total"), 82.3)
})

test_that("a row that does not add up as its table says is refused", {
  local_cache()
  local_report_pdfs(edit_line("cob-2015-16", "2,738.27", "2,748.27"))  # Bomet's, not pinned
  expect_error(knbs_report_table("cob-2015-16-budget", file = report_copy("cob-2015-16")),
               class = "knbs_error_validation_failed", regexp = "does not add up as the table says")
})

test_that("two-line rows join, past a running head printed between them", {
  local_cache()
  local_report_pdfs()
  table <- knbs_report_table("cob-2014-15-budget", file = report_copy("cob-2014-15"))
  value <- function(code, column) table$value[table$geo_code == code & table$column == column]
  # Baringo's rate is printed "99.5%"; Kajiado follows a running head; Elgeyo
  # Marakwet and Tharaka-Nithi each run over three lines, the rates between
  # the halves of the name.
  expect_identical(value("30", "absorption_recurrent"), 99.5)
  expect_identical(value("34", "budget_recurrent"), 3623695468)
  expect_identical(value("28", "expenditure_total"), 3387398251)
  expect_identical(value("13", "budget_total"), 3961074439)
})

test_that("dashes are nil where the recipe says so, and a wrapped name's dash is a hyphen", {
  local_cache()
  local_report_pdfs()
  table <- knbs_report_table("cob-2013-14-budget", file = report_copy("cob-2013-14"))
  value <- function(code, column) table$value[table$geo_code == code & table$column == column]
  expect_identical(value("36", "expenditure_assembly_development"), 0)  # Bomet, printed "-"
  expect_identical(value("13", "budget_total"), 2580.2)                  # "Tharaka -" over "Nithi"
  expect_identical(pdf_split_line("     Tharaka –")$figures, character(0))
})

test_that("a declared blank cell is filled from its identity and marked derived", {
  values <- function(code) if (code == "05") c("10.0", "5.0") else c("10.0", "5.0", "15.0")
  page <- synthetic_county_page(function(code) {
    if (code == "00") c("470.0", "235.0", "705.0") else values(code)
  })
  spec <- list(
    table_id = "synthetic", anchor = "County A B C", pages = list(1),
    columns = list("a", "b", "c"), rounding = 0.1, min_rows_on_first_page = 0,
    blank_cells = list(list(geo_code = "05", column = "c", derive = list("a", "b"))),
    identities = list(list(column = "c", sum = list("a", "b")))
  )
  out <- extract_pdf_county_table(c("1" = paste(c("Table 1: County A B C", page), collapse = "\n")), spec)
  lamu <- out$table[out$table$geo_code == "05" & out$table$column == "c", ]
  expect_identical(lamu$value, 15)
  expect_identical(lamu$status, "derived")
  # Without the declaration the short row is refused.
  spec$blank_cells <- NULL
  expect_error(extract_pdf_county_table(c("1" = paste(c("Table 1: County A B C", page), collapse = "\n")), spec),
               class = "knbs_error_schema_changed")
})

test_that("overflow lines are joined only when every column then holds one figure", {
  lines <- c(
    "Alpha     1.00     2.00     3.00",
    "Beta      1.00     2.00     3.00",
    "Gamma     1.00     2.00     3.00",
    "Delta     1.00              3.00",
    "                   2.00",
    "Epsilon   1.00     2.00         ",
    "                                    9.00"
  )
  merged <- pdf_merge_overflow(lines, 3L)
  expect_length(merged, 6L)
  expect_identical(pdf_split_line(merged[[4]])$figures, c("1.00", "2.00", "3.00"))
  # Epsilon's lone figure sits under no column: left alone, refused later.
  expect_identical(pdf_split_line(merged[[5]])$figures, c("1.00", "2.00"))
})
