# County population from the Gross County Product reports

**\[experimental\]**

Each county's 2019 census population and KNBS's projections for the
years since, with land area and 2019 population density, as printed in
the Gross County Product reports - the annual county-year population
denominators for per-capita figures.

## Usage

``` r
knbs_county_population(
  edition = "latest",
  cache = knbs_option("cache"),
  refresh = FALSE
)
```

## Arguments

- edition:

  `"latest"`, `"all"`, or edition years such as `2024`.

- cache:

  Whether to use the local cache.

- refresh:

  Whether to re-download the report and re-extract.

## Value

A `knbs_report_table` tibble with columns `geo_code`, `county`,
`period`, `value`, `measure`, `unit`, `edition`, `table_id` and
`source_id`.

## Details

`measure` says what each row is: `"population_census"` (the 2019 Kenya
Population and Housing Census), `"population_projected"`, `"land_area"`
(square kilometres) and `"population_density"` (persons per square
kilometre, 2019). The 2025 edition projects 2020-2024, the 2024 edition
2020-2023; a newer edition's projections supersede an older one's.

## See also

[`knbs_gcp()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_gcp.md);
[`knbs_get_indicator()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_get_indicator.md)
for the census tables.

## Examples

``` r
if (FALSE) { # interactive()
population <- knbs_county_population()
}
```
