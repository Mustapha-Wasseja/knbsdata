# Build inst/extdata/county-budget.csv: county budget execution from the
# Office of the Controller of Budget.
#
# Source: the annual County Governments Budget Implementation Review
# Reports, FY 2013/14 to FY 2023/24, published by the Office of the
# Controller of Budget (cob.go.ke). The copies used were curated on
# 2026-11-06; their SHA-256 checksums are in inst/extdata/report-registry.yml.
#
# cob.go.ke answers programs with a bot check, which the package does not get
# past, so the reports cannot be read at run time the way the KNBS reports
# are. Their verified figures ship with the package instead, built here by
# the same recipes and engine that read any curated report table
# (R/pdf-extract.R): every county and the total once each, the row
# identities (total = recurrent + development) on every row, the counties
# against the printed totals, and figures pinned by hand. A table that fails
# any check stops the build.
#
# Run it from the package root after setting the environment variable
# KNBSDATA_COB_DIR to the folder that holds the reports. Each report is
# identified by its checksum, so the files may be named anything.

pkgload::load_all(quiet = TRUE)

dir <- Sys.getenv("KNBSDATA_COB_DIR")
if (!nzchar(dir) || !dir.exists(dir)) {
  stop("Set KNBSDATA_COB_DIR to the folder holding the Controller of Budget reports.")
}

registry <- report_registry()
reports <- Filter(function(r) identical(r$series, "cob"), registry$reports)
files <- list.files(dir, pattern = "\\.pdf$", full.names = TRUE, ignore.case = TRUE)
checksums <- vapply(files, function(f) digest::digest(file = f, algo = "sha256"), "")

rows <- list()
for (report in reports) {
  path <- unname(files[checksums == report$sha256])[1]
  if (is.na(path)) {
    stop("No file in KNBSDATA_COB_DIR has the checksum of ", report$title, ".")
  }
  for (spec in Filter(function(t) identical(t$report_id, report$report_id), registry$tables)) {
    extracted <- report_extract(path, spec)
    t <- extracted$table
    rows[[length(rows) + 1L]] <- tibble::tibble(
      fiscal_year = report$fiscal_year,
      geo_code = t$geo_code,
      measure = t$column,
      value = t$value,
      unit = t$unit,
      status = t$status,
      table_id = spec$table_id,
      printed = spec$printed,
      pages = paste(range(extracted$pages), collapse = "-")
    )
    message(spec$table_id, ": ", nrow(t), " values, pages ", paste(extracted$pages, collapse = ", "))
  }
}
budget <- do.call(rbind, rows)

# One unit for money throughout: KSh million (FY 2014/15 prints shillings).
in_shillings <- budget$unit == "KSh"
budget$value[in_shillings] <- budget$value[in_shillings] / 1e6
budget$unit[in_shillings] <- "KSh million"

# FY 2013/14 splits spending between the County Assembly and the County
# Executive; its recurrent, development and total spending, and overall
# absorption, are derived from that split, and marked so. The Assembly's
# car loans and mortgages count in the total only, as the report has it.
fy13 <- budget[budget$fiscal_year == "2013/14", ]
value_of <- function(code, m) fy13$value[fy13$geo_code == code & fy13$measure == m]
derived <- do.call(rbind, lapply(unique(fy13$geo_code), function(code) {
  rec <- value_of(code, "expenditure_assembly_recurrent") + value_of(code, "expenditure_executive_recurrent")
  dev <- value_of(code, "expenditure_assembly_development") + value_of(code, "expenditure_executive_development")
  tot <- value_of(code, "expenditure_assembly_total") + value_of(code, "expenditure_executive_total")
  tibble::tibble(
    fiscal_year = "2013/14", geo_code = code,
    measure = c("expenditure_recurrent", "expenditure_development", "expenditure_total", "absorption_total"),
    value = c(rec, dev, tot, round(100 * tot / value_of(code, "budget_total"), 1)),
    unit = c("KSh million", "KSh million", "KSh million", "percent"),
    status = "derived",
    table_id = "cob-2013-14-budget", printed = "Table 4", pages = fy13$pages[[1]]
  )
}))
budget <- rbind(budget, derived)
budget <- budget[order(budget$fiscal_year, budget$geo_code == "00", budget$geo_code, budget$measure), ]

stopifnot(
  !anyDuplicated(paste(budget$fiscal_year, budget$geo_code, budget$measure)),
  all(nchar(budget$geo_code) == 2L),
  all(table(budget$fiscal_year[budget$measure == "expenditure_total"]) == 48L)
)
utils::write.csv(budget, "inst/extdata/county-budget.csv", row.names = FALSE, na = "")
message("Wrote ", nrow(budget), " values for ", length(unique(budget$fiscal_year)), " fiscal years.")
