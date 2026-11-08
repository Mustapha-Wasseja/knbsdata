# County budget execution: public interface --------------------------------------
#
# The Office of the Controller of Budget's annual County Governments Budget
# Implementation Review Reports, FY 2013/14 to 2023/24. cob.go.ke answers
# programs with a bot check, so the reports cannot be read at run time; the
# figures ship with the package, built by data-raw/county-budget.R through
# the same curated recipes and checks as every report table (audit F-47).

#' County budget execution: budgets, spending, revenue and pending bills
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Each county's approved budget and actual spending, its spending by
#' economic classification, its own-source revenue against target, its
#' pending bills and its exchequer issues, from the Office of the Controller
#' of Budget's annual County Governments Budget Implementation Review
#' Reports, FY 2013/14 to FY 2023/24, for the 47 counties and the national
#' total, with the counties' 2019 census codes.
#'
#' @details
#' The Controller of Budget's website answers programs with a bot check,
#' which the package does not get past, so these figures ship with the
#' package rather than being read at run time. They were extracted from the
#' reports by curated recipe and verified as every report table is: each
#' county and the total present once, the row identities the tables print
#' (total = recurrent + development) holding on every row, the counties
#' adding up to the printed totals, and figures checked by hand. A copy of a
#' report can be re-read with [knbs_report_table()] and its `file` argument.
#'
#' Measures (`measure`), money in KSh million:
#'
#' * `budget_recurrent`, `budget_development`, `budget_total`: the approved
#'   budget estimates.
#' * `expenditure_recurrent`, `expenditure_development`,
#'   `expenditure_total`: actual spending.
#' * `absorption_recurrent`, `absorption_development`, `absorption_total`:
#'   spending as a percent of budget, as the reports print them.
#' * FY 2014/15 also has `exchequer_recurrent`, `exchequer_development`,
#'   `exchequer_total` (funds released by the National Treasury) and spending
#'   as a percent of them.
#' * FY 2013/14 splits the budget and spending between the County Assembly
#'   and the County Executive (`budget_assembly`,
#'   `expenditure_executive_total`, ...) and has no recurrent/development
#'   split of the budget; its overall recurrent, development and total
#'   spending and overall absorption are derived from the split and carry
#'   `status = "derived"`.
#' * Spending by economic classification (all years but FY 2014/15):
#'   `expenditure_personnel` and `expenditure_operations_maintenance`, and
#'   for FY 2013/14 `expenditure_debt_pending_bills`.
#' * Own-source revenue: `osr_target`, `osr_actual` (what was collected) and
#'   `osr_performance` (percent of target); by quarter `osr_q1` to `osr_q4`
#'   (FY 2014/15 to 2018/19); and for FY 2019/20 and 2023/24 the split into
#'   `osr_target_ordinary`, `osr_target_aia`, `osr_actual_ordinary` and
#'   `osr_actual_aia`. In FY 2023/24 the totals include the facility
#'   improvement funds and appropriations-in-aid that earlier years leave
#'   out, so use `osr_actual_ordinary` for a like-for-like series. FY
#'   2013/14 also gives `revenue_equitable_share`,
#'   `revenue_conditional_grants` and `revenue_total_budgeted`.
#' * Pending bills at 30 June (FY 2014/15 on): `pending_recurrent`,
#'   `pending_development`, `pending_total`; from FY 2021/22 also by arm of
#'   government (`pending_executive_recurrent`,
#'   `pending_assembly_development`, ...), with the overall recurrent and
#'   development bills derived from them.
#' * Exchequer issues by arm of government (FY 2015/16 to 2018/19):
#'   `exchequer_assembly_recurrent`, `exchequer_executive_total`, ... and
#'   the combined `exchequer_recurrent`, `exchequer_development` and
#'   `exchequer_total`.
#'
#' `status` says how far to trust a figure as it stands:
#'
#' * `NA`: as printed, and consistent with its row and column.
#' * `"derived"`: computed as described above.
#' * `"misprint"`: printed inconsistently with its own row or column, and
#'   kept as printed. FY 2015/16: Busia's total expenditure in the budget
#'   table (5,865.76, where its parts sum to 5,896.98) and its personnel cost
#'   in the classification table (short by 3 million); the national
#'   own-source revenue target (printed 50,539,446 for 50,539,746,840). FY
#'   2022/23: Nairobi's executive recurrent bills (9,000 short).
#' * `"inconsistent"`: a total that does not equal its parts, with nothing
#'   to show which figure is wrong (Laikipia's pending bills, FY 2020/21).
#' * `"not_reported"`: a county the report says did not submit figures,
#'   with `NA` values. Where a report prints a dash for such a county the
#'   value is also `NA`; where a dash means nil it is zero.
#'
#' Reports do not always agree with themselves. In FY 2015/16 the budget
#' table counts 30 million of Turkana's spending as recurrent and the
#' classification table as development; the budget table's figures are the
#' ones given here. In FY 2013/14, recurrent spending summed from the arms
#' of government differs from personnel plus operations and maintenance.
#' The FY 2019/20 budget table is titled "FY 2018/19" by mistake; its
#' figures are FY 2019/20's. The FY 2024/25 report is not yet included.
#'
#' @param fiscal_year Keep only these fiscal years, such as `"2023/24"`.
#' @param county Keep only these counties, by name or census code, as
#'   [knbs_county_code()] reads them; `"00"` or `"Kenya"` for the total.
#' @param measure Keep only these measures.
#'
#' @return A `knbs_data` tibble with columns `fiscal_year`, `geo_code`,
#'   `county`, `measure`, `value`, `unit`, `status`, `table_id`, `printed`
#'   (the report's table number), `pages` and `source_id`.
#'   [knbs_metadata()] gives its provenance; [knbs_cite()] cites it.
#'
#' @seealso [knbs_report_table()] to read one of the reports' tables from
#'   your own copy; [knbs_gcp()] and [knbs_county_population()] for county
#'   output and population.
#'
#' @examples
#' budget <- knbs_county_budget(fiscal_year = "2023/24")
#' spending <- knbs_county_budget(measure = c("expenditure_recurrent", "expenditure_development"))
#' knbs_county_budget(county = "Nairobi City", measure = "absorption_development")
#' @export
knbs_county_budget <- function(fiscal_year = NULL, county = NULL, measure = NULL) {
  data <- county_budget_data()
  if (!is.null(fiscal_year)) {
    check_character(fiscal_year, "fiscal_year")
    unknown <- setdiff(fiscal_year, data$fiscal_year)
    if (length(unknown) > 0L) {
      knbs_abort(
        c("No county budget data for {.val {unknown}}.",
          "i" = "Fiscal years held: {.val {unique(data$fiscal_year)}}."),
        class = "knbs_error_invalid_argument"
      )
    }
    data <- data[data$fiscal_year %in% fiscal_year, ]
  }
  if (!is.null(county)) {
    total <- as.character(county) %in% c("00", "0")
    codes <- c(if (any(total)) "00", knbs_county_code(county[!total]))
    data <- data[data$geo_code %in% stats::na.omit(codes), ]
  }
  if (!is.null(measure)) {
    check_character(measure, "measure")
    unknown <- setdiff(measure, county_budget_data()$measure)
    if (length(unknown) > 0L) {
      knbs_abort(
        c("Unknown measure {.val {unknown}}.",
          "i" = "See {.fn knbs_county_budget} for the measures."),
        class = "knbs_error_invalid_argument"
      )
    }
    data <- data[data$measure %in% measure, ]
  }
  years <- unique(data$fiscal_year)
  new_knbs_data(
    data,
    new_knbs_metadata(
      title = paste0("County budget execution, ",
                     if (length(years) == 1L) paste("FY", years) else
                       paste0("FY ", min(years), " to ", max(years))),
      resource_id = "county_budget",
      resource_type = "table",
      source_id = "controller_of_budget",
      source_name = "Office of the Controller of Budget",
      source_url = "https://cob.go.ke/reports/county-governments-budget-implementation-review-reports/",
      producer = "Office of the Controller of Budget",
      reference_period = if (length(years)) paste(min(years), "to", max(years)) else NULL,
      unit = "KSh million; percent for absorption rates",
      frequency = "annual",
      licence = "Not stated by the source",
      access = "open",
      notes = c(
        paste0("From the Controller of Budget's annual County Governments Budget ",
               "Implementation Review Reports; table and pages on every row."),
        paste0("Extracted by curated recipe and verified: every county and the total ",
               "once, total = recurrent + development on every row, the counties ",
               "against the printed totals, figures pinned by hand."),
        paste0("Shipped with the package: the Controller of Budget's website answers ",
               "programs with a bot check, so the reports cannot be read at run time."),
        "Money is in KSh million throughout; FY 2014/15, printed in shillings, is converted.",
        paste0("status: NA as printed; \"derived\" computed from other figures; ",
               "\"misprint\" and \"inconsistent\" kept as printed; \"not_reported\" no ",
               "figures submitted."),
        "geo_code is each county's 2019 census code; the total row is \"00\"."
      )
    )
  )
}

#' The shipped county budget figures, read once per session
#' @noRd
county_budget_data <- function() {
  if (!is.null(the$county_budget)) {
    return(the$county_budget)
  }
  path <- system.file("extdata", "county-budget.csv", package = "knbsdata")
  if (!nzchar(path)) {
    path <- file.path("inst", "extdata", "county-budget.csv")
  }
  raw <- utils::read.csv(path, colClasses = c(
    fiscal_year = "character", geo_code = "character", measure = "character",
    value = "numeric", unit = "character", status = "character",
    table_id = "character", printed = "character", pages = "character"
  ), na.strings = "", stringsAsFactors = FALSE, encoding = "UTF-8")
  statutory <- county_statutory()
  county <- statutory$geo_name[match(raw$geo_code, statutory$geo_code)]
  county[raw$geo_code == "00"] <- "Kenya"
  data <- tibble::tibble(
    fiscal_year = raw$fiscal_year,
    geo_code = raw$geo_code,
    county = county,
    measure = raw$measure,
    value = raw$value,
    unit = raw$unit,
    status = raw$status,
    table_id = raw$table_id,
    printed = raw$printed,
    pages = raw$pages,
    source_id = "controller_of_budget"
  )
  the$county_budget <- data
  data
}
