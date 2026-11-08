# Retrieve one curated table of a KNBS report as tidy observations

**\[experimental\]**

Downloads the report from the KNBS publications library (cached
locally), reads the pages the table is on, extracts it by its curated
recipe and verifies it, and returns one row per county per column of the
printed table.

## Usage

``` r
knbs_report_table(table, cache = knbs_option("cache"), refresh = FALSE)
```

## Arguments

- table:

  A table id from
  [`knbs_report_tables()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_report_tables.md),
  such as `"gcp-2025-current"`, or enough of its title to identify one
  table.

- cache:

  Whether to use the local cache.

- refresh:

  Whether to re-download the report and re-extract.

## Value

A `knbs_report_table` tibble with columns `table_id`, `geo_code`,
`county`, `period`, `column`, `measure`, `prices`, `base_year`, `unit`,
`status`, `value`, `edition` and `source_id`.
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
gives its provenance, including the report file, its SHA-256 and the
pages read;
[`knbs_cite()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cite.md)
cites it.

## Details

Every read verifies the table: all 47 counties and the total are present
exactly once (matched to their 2019 census codes, whatever the spelling
or line wrapping in the report); the counties add up to the printed
total within what rounding to the printed precision can explain - shares
to 100; and figures read by hand at curation time are unchanged. A table
that fails any of these is refused with `knbs_error_schema_changed` or
`knbs_error_validation_failed` rather than returned - wrong tidy data
would be worse than an honest error.

`geo_code` is each county's census code, so these tables join
[`knbs_geographies()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_geographies.md),
the census tables, the county Statistical Abstract tables and the DHS
county indicators; the total row is `"00"`. `period` is the year a
column describes, `NA` for columns that are not one year (an average).
`status` carries the report's own marks: `"provisional"` for a year
printed with an asterisk.

Reports revise earlier years, and the Gross County Product reports
changed base year with the 2016 rebasing of the national accounts: the
2019 edition's constant prices are 2009 prices, later editions' 2016
prices. Each table keeps its edition and `base_year`; never splice
constant-price figures across base years.

## See also

[`knbs_report_tables()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_report_tables.md),
[`knbs_gcp()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_gcp.md)

## Examples

``` r
if (FALSE) { # interactive()
gcp <- knbs_report_table("gcp-2025-current")
population <- knbs_report_table("gcp-2025-population")
}
```
