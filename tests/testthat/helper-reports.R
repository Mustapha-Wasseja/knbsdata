# Page text captured on 2026-11-06 from the Gross County Product reports as
# KNBS serves them (audit F-46): the pages of eight curated tables covering
# every layout the engine reads - a county-number column (2019), years
# printed with thousands commas (2021), two panels per line and text printed
# beside a table (2024), a total printed first and provisional years (2025).
# The download and the PDF reader are mocked; no test reads a PDF or the
# network.

report_fixture_pages <- function(report_id) {
  pages <- jsonlite::fromJSON(
    testthat::test_path("fixtures", "reports", paste0(report_id, "-pages.json")),
    simplifyVector = FALSE
  )
  unlist(pages)
}

#' Serve the reports from the fixtures; `edit` may rewrite a report's pages
#' to simulate a changed report. A report read from a supplied file is
#' served from the fixture its file names (see report_copy()).
local_report_pdfs <- function(edit = NULL, env = parent.frame()) {
  testthat::local_mocked_bindings(
    report_fetch_pdf = function(source, report, refresh = FALSE, call = NULL) {
      list(path = report$report_id,
           url = paste0("https://www.knbs.or.ke/wp-content/uploads/", report$file_name),
           sha256 = report$sha256)
    },
    pdf_pages = function(path, pages = NULL, call = NULL) {
      if (file.exists(path)) {
        path <- readLines(path, warn = FALSE)[[2]]
      }
      all <- report_fixture_pages(path)
      if (is.function(edit)) all <- edit(path, all)
      if (is.null(pages)) all else all[names(all) %in% as.character(pages)]
    },
    .package = "knbsdata",
    .env = env
  )
}

#' A stand-in for a user's copy of a report: a file that starts like a PDF
#' and names the fixture to serve.
report_copy <- function(report_id, env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".pdf", .local_envir = env)
  writeLines(c("%PDF-1.4", report_id), path)
  path
}

#' A county table as a report's text: a header, the 47 counties and a total,
#' with `figures(code)` giving each row's figures as printed.
synthetic_county_page <- function(figures, header = "County   A   B   C") {
  statutory <- county_statutory()
  rows <- vapply(seq_len(47), function(i) {
    paste(formatC(statutory$geo_name[[i]], width = -18), paste(figures(statutory$geo_code[[i]]), collapse = "    "))
  }, character(1))
  c(header, rows, paste(formatC("Total", width = -18), paste(figures("00"), collapse = "    ")))
}

#' Rewrite one line of a report's fixture pages
edit_line <- function(report_id, pattern, replacement) {
  function(path, pages) {
    if (identical(path, report_id)) {
      pages[] <- sub(pattern, replacement, pages)
    }
    pages
  }
}
