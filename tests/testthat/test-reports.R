# Curated tables of KNBS reports published as PDF (audit F-46).

value_of <- function(x, geo_code, column) {
  x$value[x$geo_code == geo_code & x$column == column]
}

test_that("the curated tables are listed with edition, prices and base year", {
  tables <- knbs_report_tables()
  expect_s3_class(tables, "knbs_catalogue")
  expect_named(tables, c("table_id", "series", "edition", "printed", "title", "measure",
                         "prices", "base_year", "unit", "periods", "report"))
  expect_identical(nrow(tables), 19L)
  expect_setequal(unique(tables$edition), c(2019L, 2021L, 2023L, 2024L, 2025L))
  constant <- tables[tables$measure == "gcp" & tables$prices %in% "constant", ]
  # 2009 prices before the 2016 rebasing, 2016 prices after.
  expect_identical(constant$base_year[constant$edition == 2019L], 2009L)
  expect_true(all(constant$base_year[constant$edition > 2019L] == 2016L))
  expect_identical(tables$periods[tables$table_id == "gcp-2025-current"], "2020-2024")
  expect_identical(nrow(knbs_report_tables(series = "nothing")), 0L)
})

test_that("a table comes back with every county once, coded, in one schema", {
  local_cache()
  local_report_pdfs()
  gcp <- knbs_report_table("gcp-2025-current")

  expect_s3_class(gcp, "knbs_report_table")
  expect_named(gcp, c("table_id", "geo_code", "county", "period", "column", "measure",
                      "prices", "base_year", "unit", "status", "value", "edition", "source_id"))
  expect_identical(nrow(gcp), 48L * 5L)
  expect_setequal(unique(gcp$geo_code), c(sprintf("%02d", 1:47), "00"))
  expect_identical(value_of(gcp, "47", "2024"), 4105576)
  expect_identical(unique(gcp$county[gcp$geo_code == "47"]), "Nairobi City")
  expect_identical(unique(gcp$county[gcp$geo_code == "00"]), "Kenya")
  expect_identical(unique(gcp$status[gcp$period == 2024L]), "provisional")
  expect_true(all(is.na(gcp$status[gcp$period < 2024L])))
  expect_identical(unique(gcp$edition), 2025L)
  expect_identical(unique(gcp$unit), "KSh million")
  # The counties add to the total within rounding.
  for (year in 2020:2024) {
    counties <- sum(gcp$value[gcp$period == year & gcp$geo_code != "00"])
    expect_lte(abs(counties - gcp$value[gcp$period == year & gcp$geo_code == "00"]), 24)
  }
})

test_that("two counties per line are read panel by panel, wrapped names and all", {
  local_cache()
  local_report_pdfs()
  gcp <- knbs_report_table("gcp-2024-current")
  expect_identical(nrow(gcp), 48L * 5L)
  # Each of these names is printed across two or three lines in the report:
  # Tharaka-Nithi, West Pokot, Trans Nzoia, Elgeyo/Marakwet, Nairobi City.
  expect_identical(value_of(gcp, "13", "2019"), 55874)
  expect_identical(value_of(gcp, "24", "2023"), 104474)
  expect_identical(value_of(gcp, "26", "2019"), 151079)
  expect_identical(value_of(gcp, "28", "2021"), 130381)
  expect_identical(value_of(gcp, "47", "2019"), 2600760)
  expect_identical(value_of(gcp, "00", "2023"), 13891146)

  shares <- knbs_report_table("gcp-2024-share")
  # "NNYANDARUA", as printed, is Nyandarua by the recipe's relabel.
  expect_identical(value_of(shares, "18", "2019"), 1.5)
  expect_identical(value_of(shares, "47", "average"), 27.5)
  expect_true(is.na(unique(shares$period[shares$column == "average"])))
  expect_identical(unique(shares$measure[shares$column == "average"]), "gva_share_average")
})

test_that("text printed beside a table does not end its rows", {
  local_cache()
  local_report_pdfs()
  real <- knbs_report_table("gcp-2024-constant")
  expect_identical(value_of(real, "02", "2023"), 108147) # beside "The constant price estimates"
  expect_identical(value_of(real, "38", "2019"), 62202)  # on a page laid out further right
  expect_identical(unique(real$base_year), 2016L)
  expect_identical(unique(real$prices), "constant")
})

test_that("older layouts: a county-number column, and years with commas", {
  local_cache()
  local_report_pdfs()
  y2019 <- knbs_report_table("gcp-2019-current")
  expect_identical(value_of(y2019, "01", "2013"), 206170)
  expect_identical(value_of(y2019, "00", "2017"), 7524710)
  y2021 <- knbs_report_table("gcp-2021-current")
  expect_identical(sort(unique(y2021$period)), 2013:2020)
  expect_identical(value_of(y2021, "47", "2020"), 2669829)
})

test_that("population tables carry each measure with its unit", {
  local_cache()
  local_report_pdfs()
  pop <- knbs_report_table("gcp-2025-population")
  expect_identical(value_of(pop, "00", "census_2019"), 47564296)
  expect_identical(value_of(pop, "00", "2024"), 52428273)
  expect_identical(unique(pop$unit[pop$measure == "land_area"]), "sq km")
  expect_identical(unique(pop$period[pop$column == "census_2019"]), 2019L)
  expect_identical(unique(pop$measure[pop$column == "2022"]), "population_projected")
})

test_that("a changed figure, a lost county or a short row is refused", {
  local_cache()
  # A pinned figure changes.
  local_report_pdfs(edit_line("gcp-2025", "4,105,576", "4,105,577"))
  expect_error(knbs_report_table("gcp-2025-current"), class = "knbs_error_validation_failed")
  # An unpinned figure changes: the counties no longer add to the total.
  local_report_pdfs(edit_line("gcp-2025", "(KWALE\\s+)119,049", "\\1129,049"))
  expect_error(knbs_report_table("gcp-2025-current", refresh = TRUE),
               class = "knbs_error_validation_failed", regexp = "do not add up")
  # A county disappears.
  local_report_pdfs(edit_line("gcp-2025", "LAMU", "LAMBDA"))
  expect_error(knbs_report_table("gcp-2025-current", refresh = TRUE),
               class = "knbs_error_schema_changed", regexp = "Lamu")
  # A row loses a figure: refused, never shifted.
  local_report_pdfs(edit_line("gcp-2025", "(ISIOLO\\s+)26,588\\s+", "\\1"))
  expect_error(knbs_report_table("gcp-2025-current", refresh = TRUE),
               class = "knbs_error_schema_changed", regexp = "one figure per column")
  # The title is gone from the report.
  local_report_pdfs(edit_line("gcp-2025", "Table 8: Gross County Product", "Table 8: County output"))
  expect_error(knbs_report_table("gcp-2025-current", refresh = TRUE),
               class = "knbs_error_schema_changed", regexp = "Could not find")
})

test_that("provenance names the report, its file, pages and checks", {
  local_cache()
  local_report_pdfs()
  meta <- knbs_metadata(knbs_report_table("gcp-2024-current"))
  expect_match(meta$title, "Gross County Product 2024, Table 5", fixed = TRUE)
  notes <- paste(meta$notes, collapse = " ")
  expect_match(notes, "2024-Gross-County-Product.pdf, SHA-256 fe2dff51a697", fixed = TRUE)
  expect_match(notes, "pages 27, 28", fixed = TRUE)
  expect_match(notes, "pinned figures are verified", fixed = TRUE)
  expect_false(grepl("differs from the one curated", notes))
  expect_match(meta$source_url, "2024-Gross-County-Product.pdf$")
  expect_match(format(knbs_cite(meta)), "Gross County Product 2024", fixed = TRUE)
})

test_that("a re-uploaded report file is said to differ, and still checked", {
  local_cache()
  testthat::local_mocked_bindings(
    report_fetch_pdf = function(source, report, refresh = FALSE, call = NULL) {
      list(path = report$report_id, url = NA_character_, sha256 = strrep("0", 64))
    },
    pdf_pages = function(path, pages = NULL, call = NULL) {
      all <- report_fixture_pages(path)
      if (is.null(pages)) all else all[names(all) %in% as.character(pages)]
    }
  )
  notes <- paste(knbs_metadata(knbs_report_table("gcp-2025-current"))$notes, collapse = " ")
  expect_match(notes, "differs from the one curated", fixed = TRUE)
})

test_that("tables resolve by id or by words of their title", {
  local_cache()
  local_report_pdfs()
  expect_identical(unique(knbs_report_table("GCP-2025-CURRENT")$table_id), "gcp-2025-current")
  expect_identical(unique(knbs_report_table("2025 table 8")$table_id), "gcp-2025-current")
  expect_error(knbs_report_table("gross county product"), class = "knbs_error_ambiguous_resource")
  expect_error(knbs_report_table("no such table"), class = "knbs_error_resource_not_found")
})

test_that("knbs_gcp() picks the edition and keeps base years apart", {
  local_cache()
  local_report_pdfs()
  latest <- knbs_gcp()
  expect_named(latest, c("geo_code", "county", "period", "value", "measure", "prices",
                         "base_year", "unit", "status", "edition", "table_id", "source_id"))
  expect_identical(unique(latest$edition), 2025L)
  expect_identical(sort(unique(latest$period)), 2020:2024)

  both <- knbs_gcp(edition = c(2024, 2025))
  expect_setequal(unique(both$edition), c(2024L, 2025L))
  # The same year in two editions: a revision, kept apart by edition.
  expect_identical(both$value[both$geo_code == "00" & both$period == 2020L & both$edition == 2025L],
                   both$value[both$geo_code == "00" & both$period == 2020L & both$edition == 2024L])

  real <- knbs_gcp(prices = "constant", edition = 2024)
  expect_identical(unique(real$base_year), 2016L)
  shares <- knbs_gcp("share", edition = 2024)
  expect_false("gva_share_average" %in% shares$measure)
  expect_true(all(!is.na(shares$period)))

  expect_error(knbs_gcp(edition = 2022), class = "knbs_error_resource_not_found")
  expect_error(knbs_gcp(edition = "newest"), class = "knbs_error_invalid_argument")
  expect_error(knbs_gcp("per_capita", edition = 2025), class = "knbs_error_resource_not_found")
  expect_match(knbs_metadata(latest)$title, "GCP, current prices (2025 edition)", fixed = TRUE)
})

test_that("knbs_county_population() gives census and projections by county", {
  local_cache()
  local_report_pdfs()
  pop <- knbs_county_population()
  expect_identical(unique(pop$edition), 2025L)
  expect_setequal(unique(pop$measure),
                  c("population_census", "population_projected", "land_area", "population_density"))
  kenya <- pop[pop$geo_code == "00" & pop$measure == "population_projected", ]
  expect_identical(kenya$period, 2020:2024)
  older <- knbs_county_population(edition = 2024)
  expect_identical(max(older$period[older$measure == "population_projected"]), 2023L)
})

test_that("report tables are found by search, as GCP and as county GDP", {
  local_cache()
  hits <- knbs_search("county gdp constant", type = "table")
  expect_true("gcp-2025-constant" %in% hits$resource_id)
  expect_identical(hits$get[hits$resource_id == "gcp-2025-constant"],
                   'knbs_report_table("gcp-2025-constant")')
  expect_true("gcp-2024-population" %in% knbs_search("county population", type = "table")$resource_id)
})

test_that("figures parse as printed: commas, parentheses, marks", {
  expect_identical(pdf_value(c("1,234", "(387)", "-12.5", "2024*", "7+", "-", "..")),
                   c(1234, -387, -12.5, 2024, 7, NA, NA))
  expect_identical(pdf_is_figure(c("12,34", "1,234", "MOMBASA", "(1,310)")),
                   c(FALSE, TRUE, FALSE, TRUE))
  expect_identical(pdf_split_line("  TANA RIVER   29,469  35,516 ")$label, "TANA RIVER")
  side <- pdf_split_line("KWALE 90,121 92,461 The constant price estimates", trailing = TRUE)
  expect_identical(side$figures, c("90,121", "92,461"))
  expect_length(pdf_split_line("KWALE 90,121 92,461 The constant price estimates")$figures, 0L)
})

test_that("county labels match however they are printed", {
  key_of <- pdf_county_key_fn(list())
  expect_identical(
    vapply(c("NAIROBI CITY", "Nairobi", "MURANG'A", "Murang’a", "ELGEYO/ MARAKWET",
             "Uasin-Gishu", "Homabay", "TAITA/TAVETA", "30 Baringo", "Total", "KENYA", "County"),
           key_of, character(1), USE.NAMES = FALSE),
    c("47", "47", "21", "21", "28", "27", "43", "06", "30", "00", "00", NA)
  )
  expect_identical(pdf_county_key_fn(list(relabel = list(NNYANDARUA = "Nyandarua")))("NNYANDARUA"), "18")
})

test_that("pages are read from the PDF by number", {
  skip_if_not_installed("pdftools")
  skip_if_not_installed("qpdf")
  path <- withr::local_tempfile(fileext = ".pdf")
  grDevices::pdf(path)
  for (i in 1:3) {
    graphics::plot.new()
    graphics::text(0.5, 0.5, paste("PAGE", i, "MOMBASA 1,234"))
  }
  grDevices::dev.off()
  pages <- pdf_pages(path, c(2, 3, 9))
  expect_identical(names(pages), c("2", "3"))
  expect_match(pages[["3"]], "PAGE 3")
  expect_length(pdf_pages(path), 3L)
})

test_that("cached reports the registry no longer names are tidied away", {
  dir <- local_cache()
  reports <- file.path(dir, "reports")
  dir.create(reports)
  keep <- file.path(reports, "16344-2025-Gross-County-Product.pdf")
  old <- file.path(reports, "1-Old-Report.pdf")
  file.create(c(keep, old))
  the$cache_tidied <- setdiff(the$cache_tidied, dir)
  cache_tidy(dir)
  expect_true(file.exists(keep))
  expect_false(file.exists(old))
  knbs_cache_clear(quiet = TRUE)
  expect_false(dir.exists(reports))
})
