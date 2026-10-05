# List the curated Statistical Abstract tables

**\[experimental\]**

The Statistical Abstract publishes its chapter tables as Excel workbooks
on the KNBS website. This function lists the tables the package has
*curated*: each one has a hand-verified extraction recipe — sheet,
layout anchors, section labels, unit and pinned reference values — so
that
[`knbs_abstract_table()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_abstract_table.md)
can return it as clean tidy observations, or refuse with a clear error
if the workbook has changed.

Curated so far: Chapter 2 (National Accounts) of the 2025 edition — the
production accounts, GDP by activity at current and constant prices,
expenditure on GDP, capital formation, national income and saving.

## Usage

``` r
knbs_abstract_tables()
```

## Value

A `knbs_catalogue` tibble with columns `table_id`, `title`, `chapter`,
`unit`, `sheet` and `workbook`.

## See also

[`knbs_abstract_table()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_abstract_table.md),
[`knbs_publications()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_publications.md)

## Examples

``` r
knbs_abstract_tables()
#> <knbs_catalogue>
#> Title: 2025 Statistical Abstract: curated tables
#> Rows: 15
#> Source: Kenya National Bureau of Statistics
#> 
#> # A tibble: 15 × 6
#>    table_id title                                   chapter unit  sheet workbook
#>    <chr>    <chr>                                   <chr>   <chr> <chr> <chr>   
#>  1 2.1      Annual Production Accounts by Industry… Chapte… KSh … Tabl… NA-Stat…
#>  2 2.2      Gross Domestic Product by Activity, 20… Chapte… KSh … Tabl… NA-Stat…
#>  3 2.3      Contribution to Gross Domestic Product… Chapte… per … Tabl… NA-Stat…
#>  4 2.4      Gross Domestic Product by Activity, 20… Chapte… KSh … Tabl… NA-Stat…
#>  5 2.5      Growth of Gross Domestic Product by Ac… Chapte… per … Tabl… NA-Stat…
#>  6 2.6a     Expenditure on the Gross Domestic Prod… Chapte… KSh … Tabl… NA-Stat…
#>  7 2.6b     Expenditure on the Gross Domestic Prod… Chapte… per … Tabl… NA-Stat…
#>  8 2.6c     Expenditure on the Gross Domestic Prod… Chapte… KSh … Tabl… NA-Stat…
#>  9 2.6d     Growth in Expenditure on the Gross Dom… Chapte… per … Tabl… NA-Stat…
#> 10 2.7a     Gross Fixed Capital Formation, 2015 - … Chapte… KSh … Tabl… NA-Stat…
#> 11 2.7b     Share of Gross Fixed Capital Formation… Chapte… per … Tabl… NA-Stat…
#> 12 2.7c     Gross Fixed Capital Formation, 2015 - … Chapte… KSh … Tabl… NA-Stat…
#> 13 2.7d     Growth in Gross Fixed Capital Formatio… Chapte… per … Tabl… NA-Stat…
#> 14 2.8      Gross Domestic Product and Gross Natio… Chapte… KSh … Tabl… NA-Stat…
#> 15 2.9      National Disposable Income and Saving,… Chapte… KSh … Tabl… NA-Stat…
```
