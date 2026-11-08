# County budget execution: budgets, spending and absorption by county

**\[experimental\]**

Each county's approved budget and actual spending, recurrent and
development, and its absorption rates, from the Office of the Controller
of Budget's annual County Governments Budget Implementation Review
Reports, FY 2013/14 to FY 2023/24, for the 47 counties and the national
total, with the counties' 2019 census codes.

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

`status` is `NA` for a figure as printed, `"derived"` for one computed
as just described, and `"misprint"` for a figure printed inconsistently
with its own row (FY 2015/16: Busia's total expenditure is printed as
5,865.76 while its recurrent and development spending sum to 5,896.98;
the printed national total uses the latter). Misprints are kept as
printed.

The reports' FY 2019/20 budget table is titled "FY 2018/19" by mistake;
its figures are FY 2019/20's. The FY 2024/25 report is not yet included.

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
