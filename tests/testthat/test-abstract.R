# Curated Statistical Abstract extraction (audit F-35, F-36). The fixture is
# the real Chapter 2 workbook; every curated table must extract from it and
# every drift defence must refuse a doctored copy.

test_that("the catalogue lists every curated table", {
  catalogue <- knbs_abstract_tables()

  expect_s3_class(catalogue, "knbs_catalogue")
  expect_named(
    catalogue,
    c("table_id", "title", "chapter", "unit", "sheet", "workbook")
  )
  expect_identical(nrow(catalogue), 15L)
  expect_setequal(
    catalogue$table_id,
    c("2.1", "2.2", "2.3", "2.4", "2.5", "2.6a", "2.6b", "2.6c", "2.6d",
      "2.7a", "2.7b", "2.7c", "2.7d", "2.8", "2.9")
  )
  expect_identical(unique(catalogue$chapter), "Chapter 2: National Accounts")
})

test_that("every curated table extracts cleanly from the real workbook", {
  local_cache()
  local_abstract_workbook()
  catalogue <- knbs_abstract_tables()

  for (id in catalogue$table_id) {
    tab <- knbs_abstract_table(id)
    expect_s3_class(tab, "knbs_abstract_table")
    expect_gt(nrow(tab), 0)
    expect_type(tab$period, "integer")
    expect_true(all(tab$period %in% 2015:2024), info = id)
    expect_true(all(is.na(tab$status) |
                      tab$status %in% c("provisional", "revised")), info = id)
    expect_type(tab$value, "double")
    expect_identical(unique(tab$table_id), id)
    expect_identical(
      knbs_metadata(tab)$unit,
      catalogue$unit[catalogue$table_id == id]
    )
  }
})

test_that("year status flags follow the source's own marks", {
  local_cache()
  local_abstract_workbook()
  gdp <- knbs_abstract_table("2.2")

  expect_identical(unique(gdp$status[gdp$period == 2024]), "provisional")
  expect_identical(unique(gdp$status[gdp$period == 2023]), "revised")
  expect_identical(unique(gdp$status[gdp$period == 2022]), "revised")
  expect_identical(unique(gdp$status[gdp$period == 2015]), NA_character_)
})

test_that("the production accounts carry industry sections and honest gaps", {
  local_cache()
  local_abstract_workbook()
  prod <- knbs_abstract_table("2.1")

  expect_true(all(c("industry", "measure") %in% names(prod)))
  expect_identical(length(unique(prod$industry)), 20L)

  # "Less: Subsidies" is printed without figures under two different
  # aggregates; both survive as items with NA values, because that is what
  # the source shows.
  subsidies <- prod[prod$measure == "Less: Subsidies", ]
  expect_setequal(
    unique(subsidies$industry),
    c("All industries at basic prices", "Total economy")
  )
  expect_true(all(is.na(subsidies$value)))

  pinned <- prod[prod$industry == "Total economy" &
                   prod$measure == "GDP at market prices" &
                   prod$period == 2016, ]
  expect_identical(pinned$value, 7594064)
})

test_that("GDP agrees between the production and expenditure tables", {
  local_cache()
  local_abstract_workbook()
  by_activity <- knbs_abstract_table("2.2")
  by_expenditure <- knbs_abstract_table("2.6a")

  a <- by_activity[by_activity$industry == "GDP at market prices", ]
  e <- by_expenditure[
    by_expenditure$expenditure_category == "Gross domestic product at market prices",
  ]
  a <- a[order(a$period), ]
  e <- e[order(e$period), ]
  expect_identical(a$period, e$period)
  expect_equal(a$value, e$value, tolerance = 1e-6)
})

test_that("the abstract's GDP at factor cost matches Gross County Product", {
  # Three independent artefacts must agree: the abstract workbook's income
  # account, and the GCP dataset republished on the africa portal, whose
  # national gross value added for the 2016 base year is the same figure in
  # both constant and current prices.
  local_cache()
  local_abstract_workbook()
  income <- knbs_abstract_table("2.8")

  factor_cost <- income[
    income$account == "Current Prices, KSh Million" &
      income$item == "Gross domestic product at factor cost" &
      income$period == 2016,
  ]
  expect_identical(factor_cost$value, 6926656)

  gcp <- knoema_fixture("gcp-data.json")
  national <- Filter(
    function(s) {
      identical(s$table$id, "T3") &&
        identical(s$`administrative-unit`$RegionId, "KE")
    },
    gcp$data
  )[[1]]
  # 2016 is the fourth value of the 2013-2020 series.
  expect_identical(factor_cost$value, as.numeric(national$values[[4]]))
})

test_that("footnote leaders and markers are trimmed from labels", {
  local_cache()
  local_abstract_workbook()

  expenditure <- knbs_abstract_table("2.6a")
  expect_true("Discrepancy" %in% expenditure$expenditure_category)

  income <- knbs_abstract_table("2.8")
  expect_true(
    "Taxes on production and imports less subsidies" %in% income$item
  )
})

test_that("repeated row labels keep the sheet's own order via line", {
  local_cache()
  local_abstract_workbook()
  saving <- knbs_abstract_table("2.9")

  expect_true("line" %in% names(saving))
  totals <- saving[saving$account == "Financing of capital formation" &
                     saving$item == "Total" & saving$period == 2015, ]
  expect_identical(nrow(totals), 2L)
  expect_false(any(duplicated(
    paste(saving$account, saving$item, saving$line, saving$period)
  )))
})

test_that("a table resolves by id or by enough of its title", {
  local_cache()
  local_abstract_workbook()

  by_title <- knbs_abstract_table("disposable income")
  expect_identical(unique(by_title$table_id), "2.9")

  expect_error(
    knbs_abstract_table("Gross Fixed Capital Formation"),
    class = "knbs_error_ambiguous_resource"
  )
  expect_error(
    knbs_abstract_table("no such table anywhere"),
    class = "knbs_error_resource_not_found"
  )
})

test_that("provenance names the workbook, the sheet and the flags", {
  local_cache()
  local_abstract_workbook()
  tab <- knbs_abstract_table("2.4")

  meta <- knbs_metadata(tab)
  expect_identical(meta$resource_id, "2.4")
  expect_identical(meta$frequency, "annual")
  expect_identical(meta$reference_period, "2015 to 2024")
  expect_match(meta$source_url, "NA-Statistical-Abstract_2025-1[.]xlsx$")
  notes <- paste(meta$notes, collapse = " ")
  expect_match(notes, "2025 Statistical Abstract")
  expect_match(notes, "Table 2.4", fixed = TRUE)
  expect_match(notes, "SHA-256")
  expect_match(notes, "provisional")

  citation <- utils::capture.output(print(knbs_cite(tab)))
  expect_match(paste(citation, collapse = " "), "Kenya National Bureau")
})

test_that("layout drift is refused, not guessed through", {
  spec <- abstract_spec("2.2")
  cells <- abstract_fixture_cells(spec$sheet)

  moved <- spec
  moved$anchor <- "Table 9.9"
  expect_error(extract_abstract_table(cells, moved),
               class = "knbs_error_schema_changed")

  poisoned <- spec
  poisoned$checks$pins[[2]]$value <- 1
  expect_error(extract_abstract_table(cells, poisoned),
               class = "knbs_error_validation_failed")

  short <- spec
  short$checks$through <- 2030
  expect_error(extract_abstract_table(cells, short),
               class = "knbs_error_validation_failed")

  junk <- cells
  junk[[3]][[6]] <- "not a number"
  expect_error(extract_abstract_table(junk, spec),
               class = "knbs_error_schema_changed")
  expect_error(extract_abstract_table(junk, spec), regexp = "Non-numeric")

  gutted <- cells
  for (col in 2:11) {
    gutted[[col]][[6]] <- NA_character_
  }
  expect_error(extract_abstract_table(gutted, spec),
               class = "knbs_error_schema_changed")
  expect_error(extract_abstract_table(gutted, spec), regexp = "value-less")
})

test_that("a missing section or sheet is a schema change", {
  spec <- abstract_spec("2.8")
  cells <- abstract_fixture_cells(spec$sheet)

  demanding <- spec
  demanding$groups <- c(spec$groups, "A section that never existed")
  expect_error(extract_abstract_table(cells, demanding),
               class = "knbs_error_schema_changed")
  expect_error(extract_abstract_table(cells, demanding),
               regexp = "missing section")

  expect_error(
    abstract_read_sheet(abstract_fixture_path(), "No such sheet"),
    class = "knbs_error_schema_changed"
  )
})

test_that("the mid-sheet continuation of Table 2.1 is not data", {
  # The production accounts repeat their title and year header where the
  # print layout breaks; neither repeat may leak into the observations.
  local_cache()
  local_abstract_workbook()
  prod <- knbs_abstract_table("2.1")

  expect_false(any(grepl("^Table", prod$measure)))
  expect_false(any(prod$measure == "Industry"))
  expect_false(any(prod$value %in% 2015:2024 & prod$measure == "Industry"))
})

test_that("a data row of four-digit values is not taken for a year header", {
  # The "Tree, crop and plant resources" row of Tables 2.7a and 2.7c reads
  # 7866, 8269, 8922, 9615, ... - four-digit cells that once passed for a
  # repeated year header, so the row was silently dropped and the parts no
  # longer added up to Total.
  local_cache()
  local_abstract_workbook()
  tree <- "Tree, crop and plant resources yielding repeat products"

  for (id in c("2.7a", "2.7c")) {
    gfcf <- knbs_abstract_table(id)
    expect_identical(length(unique(gfcf$purpose)), 10L, info = id)
    expect_identical(sum(gfcf$purpose == tree), 10L, info = id)
  }
  current <- knbs_abstract_table("2.7a")
  expect_identical(
    current$value[current$purpose == tree & current$period == 2015L],
    7866
  )
})

test_that("tables of totals and parts name the row each item belongs to", {
  local_cache()
  local_abstract_workbook()
  gdp <- knbs_abstract_table("2.2")

  # parent sits beside the item it describes.
  expect_identical(names(gdp)[[match("industry", names(gdp)) + 1L]], "parent")
  parent_of <- function(item) unique(gdp$parent[gdp$industry == item])
  expect_identical(parent_of("Growing of crops"), "Agriculture, forestry and fishing")
  expect_identical(parent_of("Agriculture, forestry and fishing"), "All industries")
  expect_identical(parent_of("All industries"), "GDP at market prices")
  expect_identical(parent_of("GDP at market prices"), NA_character_)

  # Rows sharing a parent add up to it, within rounding, in every year.
  for (year in 2015:2024) {
    in_year <- gdp[gdp$period == year, ]
    parts <- sum(in_year$value[in_year$parent %in% "All industries"])
    total <- in_year$value[in_year$industry == "All industries"]
    expect_lte(abs(parts - total), 11)
  }

  notes <- paste(knbs_metadata(gdp)$notes, collapse = " ")
  expect_match(notes, "parent names the row")
  expect_match(notes, "checked to add up")
})

test_that("subtracted parts are stated and growth tables are not summed", {
  local_cache()
  local_abstract_workbook()

  expenditure <- knbs_abstract_table("2.6a")
  imports <- expenditure$expenditure_category == "Imports of goods and services"
  expect_identical(
    unique(expenditure$parent[imports]),
    "Gross domestic product at market prices"
  )
  expect_match(
    paste(knbs_metadata(expenditure)$notes, collapse = " "),
    "Imports of goods and services enters Gross domestic product at market prices with a negative sign",
    fixed = TRUE
  )

  growth <- knbs_abstract_table("2.5")
  expect_true("parent" %in% names(growth))
  expect_match(paste(knbs_metadata(growth)$notes, collapse = " "),
               "Growth rates do not add")

  # The accounts tables are identities, not parts and totals.
  expect_false("parent" %in% names(knbs_abstract_table("2.1")))
  expect_false("parent" %in% names(knbs_abstract_table("2.8")))
})

test_that("parts that no longer add up, or a missing part, are refused", {
  spec <- abstract_spec("2.2")
  cells <- abstract_fixture_cells(spec$sheet)

  # Nudge one sub-industry's 2018 figure. The pinned reference values are
  # untouched, so only the sum check can notice.
  labels <- trimws(as.character(cells[[1]]))
  header <- which(trimws(as.character(cells[[2]])) == "2015")[[1]]
  col <- which(trimws(as.character(unlist(cells[header, ]))) == "2018")
  row <- which(labels == "Growing of crops")[[1]]
  nudged <- cells
  nudged[[col]][[row]] <- as.character(as.numeric(cells[[col]][[row]]) + 1000)
  expect_error(extract_abstract_table(nudged, spec),
               class = "knbs_error_validation_failed")
  expect_error(extract_abstract_table(nudged, spec), regexp = "do not add up")

  demanding <- spec
  demanding$hierarchy$parents[[3]]$components <- c(
    spec$hierarchy$parents[[3]]$components, "A crop that never existed"
  )
  expect_error(extract_abstract_table(cells, demanding),
               class = "knbs_error_schema_changed")
  expect_error(extract_abstract_table(cells, demanding), regexp = "missing")
})

test_that("a malformed structure fails the registry check", {
  spec <- abstract_spec("2.2")
  expect_true(abstract_hierarchy_valid(spec))
  expect_true(abstract_hierarchy_valid(abstract_spec("2.1")))

  twice <- spec
  twice$hierarchy$parents[[3]]$components <- c(
    spec$hierarchy$parents[[3]]$components, "Mining and quarrying"
  )
  expect_false(abstract_hierarchy_valid(twice))

  stray <- spec
  stray$hierarchy$parents[[1]]$subtract <- "Not one of its parts"
  expect_false(abstract_hierarchy_valid(stray))

  vague <- spec
  vague$hierarchy$rounding <- NULL
  expect_false(abstract_hierarchy_valid(vague))

  sectioned <- abstract_spec("2.8")
  sectioned$hierarchy <- spec$hierarchy
  expect_false(abstract_hierarchy_valid(sectioned))
})
