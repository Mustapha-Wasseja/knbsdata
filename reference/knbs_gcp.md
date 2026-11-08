# Gross County Product: county GDP from the KNBS reports

**\[experimental\]**

The size of each county's economy, from the Gross County Product reports
KNBS publishes each year: GCP at current or constant prices, each
county's share of gross value added, or per-capita GCP, for the 47
counties and Kenya, with the counties' 2019 census codes.

## Usage

``` r
knbs_gcp(
  measure = c("gcp", "share", "per_capita"),
  prices = c("current", "constant"),
  edition = "latest",
  cache = knbs_option("cache"),
  refresh = FALSE
)
```

## Arguments

- measure:

  `"gcp"` (KSh million), `"share"` (percent of gross value added) or
  `"per_capita"` (KSh).

- prices:

  `"current"` or `"constant"`; ignored for shares.

- edition:

  `"latest"`, `"all"`, or edition years such as `2024`.

- cache:

  Whether to use the local cache.

- refresh:

  Whether to re-download the report and re-extract.

## Value

A `knbs_report_table` tibble with columns `geo_code`, `county`,
`period`, `value`, `measure`, `prices`, `base_year`, `unit`, `status`,
`edition`, `table_id` and `source_id`.

## Details

Each edition covers five to eight years and revises the years before it.
`edition = "latest"` (the default) returns the newest edition that has
the measure; `edition = "all"` returns every edition, one block per
edition, so that revisions can be compared; or name the editions wanted.

Constant prices are 2009 prices in the 2019 edition and 2016 prices from
the 2021 edition on, after the national accounts were rebased; the
`base_year` column says which. Figures from editions with different base
years must not be spliced into one series.

Per-capita GCP is published only in the 2019 edition. County shares are
returned for single years; each report's average over its years is in
[`knbs_report_table()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_report_table.md).

## See also

[`knbs_report_table()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_report_table.md)
for any single curated table,
[`knbs_county_population()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_county_population.md)
for the reports' population tables.

## Examples

``` r
if (FALSE) { # interactive()
gcp <- knbs_gcp()
real <- knbs_gcp(prices = "constant")
shares <- knbs_gcp("share", edition = "all")
}
```
