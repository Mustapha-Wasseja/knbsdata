# County budget execution: budgets, spending, revenue and pending bills

**\[experimental\]**

Each county's approved budget and actual spending, its spending by
economic classification, its own-source revenue against target, its
pending bills and its exchequer issues, from the Office of the
Controller of Budget's annual County Governments Budget Implementation
Review Reports, FY 2013/14 to FY 2023/24, for the 47 counties and the
national total, with the counties' 2019 census codes.

## Usage

``` r
knbs_county_budget(fiscal_year = NULL, county = NULL, measure = NULL)
```

## Arguments

- fiscal_year:

  Keep only these fiscal years, such as `"2023/24"`.

- county:

  Keep only these counties, by name or census code, as
  [`knbs_county_code()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_county_code.md)
  reads them; `"00"` or `"Kenya"` for the total.

- measure:

  Keep only these measures.

## Value

A `knbs_data` tibble with columns `fiscal_year`, `geo_code`, `county`,
`measure`, `value`, `unit`, `status`, `table_id`, `printed` (the
report's table number), `pages` and `source_id`.
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
gives its provenance;
[`knbs_cite()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cite.md)
cites it.

## Details

The Controller of Budget's website answers programs with a bot check,
which the package does not get past, so these figures ship with the
package rather than being read at run time. They were extracted from the
reports by curated recipe and verified as every report table is: each
county and the total present once, the row identities the tables print
(total = recurrent + development) holding on every row, the counties
adding up to the printed totals, and figures checked by hand. A copy of
a report can be re-read with
[`knbs_report_table()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_report_table.md)
and its `file` argument.

Measures (`measure`), money in KSh million:

- `budget_recurrent`, `budget_development`, `budget_total`: the approved
  budget estimates.

- `expenditure_recurrent`, `expenditure_development`,
  `expenditure_total`: actual spending.

- `absorption_recurrent`, `absorption_development`, `absorption_total`:
  spending as a percent of budget, as the reports print them.

- FY 2014/15 also has `exchequer_recurrent`, `exchequer_development`,
  `exchequer_total` (funds released by the National Treasury) and
  spending as a percent of them.

- FY 2013/14 splits the budget and spending between the County Assembly
  and the County Executive (`budget_assembly`,
  `expenditure_executive_total`, ...) and has no recurrent/development
  split of the budget; its overall recurrent, development and total
  spending and overall absorption are derived from the split and carry
  `status = "derived"`.

- Spending by economic classification (all years but FY 2014/15):
  `expenditure_personnel` and `expenditure_operations_maintenance`, and
  for FY 2013/14 `expenditure_debt_pending_bills`.

- Own-source revenue: `osr_target`, `osr_actual` (what was collected)
  and `osr_performance` (percent of target); by quarter `osr_q1` to
  `osr_q4` (FY 2014/15 to 2018/19); and for FY 2019/20 and 2023/24 the
  split into `osr_target_ordinary`, `osr_target_aia`,
  `osr_actual_ordinary` and `osr_actual_aia`. In FY 2023/24 the totals
  include the facility improvement funds and appropriations-in-aid that
  earlier years leave out, so use `osr_actual_ordinary` for a
  like-for-like series. FY 2013/14 also gives `revenue_equitable_share`,
  `revenue_conditional_grants` and `revenue_total_budgeted`.

- Pending bills at 30 June (FY 2014/15 on): `pending_recurrent`,
  `pending_development`, `pending_total`; from FY 2021/22 also by arm of
  government (`pending_executive_recurrent`,
  `pending_assembly_development`, ...), with the overall recurrent and
  development bills derived from them.

- Exchequer issues by arm of government (FY 2015/16 to 2018/19):
  `exchequer_assembly_recurrent`, `exchequer_executive_total`, ... and
  the combined `exchequer_recurrent`, `exchequer_development` and
  `exchequer_total`.

`status` says how far to trust a figure as it stands:

- `NA`: as printed, and consistent with its row and column.

- `"derived"`: computed as described above.

- `"misprint"`: printed inconsistently with its own row or column, and
  kept as printed. FY 2015/16: Busia's total expenditure in the budget
  table (5,865.76, where its parts sum to 5,896.98) and its personnel
  cost in the classification table (short by 3 million); the national
  own-source revenue target (printed 50,539,446 for 50,539,746,840). FY
  2022/23: Nairobi's executive recurrent bills (9,000 short).

- `"inconsistent"`: a total that does not equal its parts, with nothing
  to show which figure is wrong (Laikipia's pending bills, FY 2020/21).

- `"not_reported"`: a county the report says did not submit figures,
  with `NA` values. Where a report prints a dash for such a county the
  value is also `NA`; where a dash means nil it is zero.

Reports do not always agree with themselves. In FY 2015/16 the budget
table counts 30 million of Turkana's spending as recurrent and the
classification table as development; the budget table's figures are the
ones given here. In FY 2013/14, recurrent spending summed from the arms
of government differs from personnel plus operations and maintenance.
The FY 2019/20 budget table is titled "FY 2018/19" by mistake; its
figures are FY 2019/20's. The FY 2024/25 report is not yet included.

## See also

[`knbs_report_table()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_report_table.md)
to read one of the reports' tables from your own copy;
[`knbs_gcp()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_gcp.md)
and
[`knbs_county_population()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_county_population.md)
for county output and population.

## Examples

``` r
budget <- knbs_county_budget(fiscal_year = "2023/24")
spending <- knbs_county_budget(measure = c("expenditure_recurrent", "expenditure_development"))
knbs_county_budget(county = "Nairobi City", measure = "absorption_development")
#> <knbs_data>
#> Title: County budget execution, FY 2014/15 to 2023/24
#> Resource: "county_budget"
#> Rows: 10
#> Period: 2014/15 to 2023/24
#> Source: Office of the Controller of Budget
#> 
#> # A tibble: 10 × 11
#>    fiscal_year geo_code county measure value unit  status table_id printed pages
#>    <chr>       <chr>    <chr>  <chr>   <dbl> <chr> <chr>  <chr>    <chr>   <chr>
#>  1 2014/15     47       Nairo… absorp…  33.5 perc… NA     cob-201… Annex 1 303-…
#>  2 2015/16     47       Nairo… absorp…  52.9 perc… NA     cob-201… Table … 31-33
#>  3 2016/17     47       Nairo… absorp…  33.4 perc… NA     cob-201… Table … 32-34
#>  4 2017/18     47       Nairo… absorp…  26.1 perc… NA     cob-201… Table … 29-31
#>  5 2018/19     47       Nairo… absorp…  79.7 perc… NA     cob-201… Table … 30-32
#>  6 2019/20     47       Nairo… absorp…  24.5 perc… NA     cob-201… Table … 26-28
#>  7 2020/21     47       Nairo… absorp…  66.4 perc… NA     cob-202… Table … 28-29
#>  8 2021/22     47       Nairo… absorp…  29.3 perc… NA     cob-202… Table … 29-31
#>  9 2022/23     47       Nairo… absorp…  49.9 perc… NA     cob-202… Table … 32-34
#> 10 2023/24     47       Nairo… absorp…  38.7 perc… NA     cob-202… Table … 28-29
#> # ℹ 1 more variable: source_id <chr>
```
