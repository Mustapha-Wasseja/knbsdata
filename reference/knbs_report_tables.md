# List the curated tables of KNBS reports

**\[experimental\]**

KNBS publishes some of its data only as tables printed in PDF reports.
This lists the tables the package has curated: each has a hand-checked
recipe - the report, the title it is found by, its columns, its unit and
figures read by hand - so that
[`knbs_report_table()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_report_table.md)
can return it as tidy observations, or refuse with a clear error if the
report has changed.

Curated so far: the Gross County Product reports of 2019, 2021, 2023,
2024 and 2025 - county GDP at current and constant prices, each county's
share of gross value added, per-capita GCP (2019) and the county
population tables (2024, 2025).

## Usage

``` r
knbs_report_tables(series = NULL)
```

## Arguments

- series:

  Keep only these report series, for example `"gcp"`.

## Value

A `knbs_catalogue` tibble with columns `table_id`, `series`, `edition`,
`publisher`, `printed`, `title`, `measure`, `prices`, `base_year`,
`unit`, `periods` and `report`.

## See also

[`knbs_report_table()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_report_table.md),
[`knbs_gcp()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_gcp.md),
[`knbs_county_population()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_county_population.md)

## Examples

``` r
knbs_report_tables()
#> <knbs_catalogue>
#> Title: KNBS report tables: curated
#> Rows: 30
#> Source: Kenya National Bureau of Statistics
#> 
#> # A tibble: 30 × 12
#>    table_id      series edition publisher printed title measure prices base_year
#>    <chr>         <chr>    <int> <chr>     <chr>   <chr> <chr>   <chr>      <int>
#>  1 gcp-2019-cur… gcp       2019 Kenya Na… Table 4 Gros… gcp     curre…        NA
#>  2 gcp-2019-sha… gcp       2019 Kenya Na… Table 5 Coun… gva_sh… NA            NA
#>  3 gcp-2019-con… gcp       2019 Kenya Na… Table 6 Gros… gcp     const…      2009
#>  4 gcp-2019-per… gcp       2019 Kenya Na… Table 7 Per … gcp_pe… curre…        NA
#>  5 gcp-2019-per… gcp       2019 Kenya Na… Table 8 Per … gcp_pe… const…      2009
#>  6 gcp-2021-cur… gcp       2021 Kenya Na… Table 1 Gros… gcp     curre…        NA
#>  7 gcp-2021-con… gcp       2021 Kenya Na… Table 2 Gros… gcp     const…      2016
#>  8 gcp-2021-sha… gcp       2021 Kenya Na… Table 3 Coun… gva_sh… NA            NA
#>  9 gcp-2023-cur… gcp       2023 Kenya Na… Table 1 Gros… gcp     curre…        NA
#> 10 gcp-2023-sha… gcp       2023 Kenya Na… Table 2 Coun… gva_sh… NA            NA
#> # ℹ 20 more rows
#> # ℹ 3 more variables: unit <chr>, periods <chr>, report <chr>
knbs_report_tables(series = "gcp")
#> <knbs_catalogue>
#> Title: KNBS report tables: curated
#> Rows: 19
#> Source: Kenya National Bureau of Statistics
#> 
#> # A tibble: 19 × 12
#>    table_id      series edition publisher printed title measure prices base_year
#>    <chr>         <chr>    <int> <chr>     <chr>   <chr> <chr>   <chr>      <int>
#>  1 gcp-2019-cur… gcp       2019 Kenya Na… Table 4 Gros… gcp     curre…        NA
#>  2 gcp-2019-sha… gcp       2019 Kenya Na… Table 5 Coun… gva_sh… NA            NA
#>  3 gcp-2019-con… gcp       2019 Kenya Na… Table 6 Gros… gcp     const…      2009
#>  4 gcp-2019-per… gcp       2019 Kenya Na… Table 7 Per … gcp_pe… curre…        NA
#>  5 gcp-2019-per… gcp       2019 Kenya Na… Table 8 Per … gcp_pe… const…      2009
#>  6 gcp-2021-cur… gcp       2021 Kenya Na… Table 1 Gros… gcp     curre…        NA
#>  7 gcp-2021-con… gcp       2021 Kenya Na… Table 2 Gros… gcp     const…      2016
#>  8 gcp-2021-sha… gcp       2021 Kenya Na… Table 3 Coun… gva_sh… NA            NA
#>  9 gcp-2023-cur… gcp       2023 Kenya Na… Table 1 Gros… gcp     curre…        NA
#> 10 gcp-2023-sha… gcp       2023 Kenya Na… Table 2 Coun… gva_sh… NA            NA
#> 11 gcp-2023-con… gcp       2023 Kenya Na… Table 3 Gros… gcp     const…      2016
#> 12 gcp-2024-pop… gcp       2024 Kenya Na… Table 1 Popu… popula… NA            NA
#> 13 gcp-2024-cur… gcp       2024 Kenya Na… Table 5 Gros… gcp     curre…        NA
#> 14 gcp-2024-sha… gcp       2024 Kenya Na… Table 6 Coun… gva_sh… NA            NA
#> 15 gcp-2024-con… gcp       2024 Kenya Na… Table 7 Gros… gcp     const…      2016
#> 16 gcp-2025-pop… gcp       2025 Kenya Na… Table 1 Popu… popula… NA            NA
#> 17 gcp-2025-cur… gcp       2025 Kenya Na… Table 8 Gros… gcp     curre…        NA
#> 18 gcp-2025-sha… gcp       2025 Kenya Na… Table 9 Coun… gva_sh… NA            NA
#> 19 gcp-2025-con… gcp       2025 Kenya Na… Table … Gros… gcp     const…      2016
#> # ℹ 3 more variables: unit <chr>, periods <chr>, report <chr>
```
