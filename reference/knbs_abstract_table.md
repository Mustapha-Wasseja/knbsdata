# Retrieve one Statistical Abstract table as tidy observations

**\[experimental\]**

Downloads the table's chapter workbook from the KNBS website (cached
locally), extracts the table by its curated recipe, verifies the layout
anchors and pinned reference values, and returns one row per cell of the
printed table.

## Usage

``` r
knbs_abstract_table(table, cache = knbs_option("cache"), refresh = FALSE)
```

## Arguments

- table:

  A table id from
  [`knbs_abstract_tables()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_abstract_tables.md)
  (for example `"2.2"`), or enough of a table title to identify one
  unambiguously.

- cache:

  Whether to use the local cache.

- refresh:

  Whether to re-download the workbook and re-extract.

## Value

A `knbs_abstract_table` tibble.
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
returns its provenance, including the workbook file and its SHA-256;
[`knbs_cite()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cite.md)
cites it.

## Details

`period` is the integer year. `status` carries the source's own year
flags, `"provisional"` (`*`) or `"revised"` (`+`), and is `NA` for final
years. Sectioned tables (the production accounts, the income accounts)
carry their section as an extra column named for what it is — `industry`
or `account`. A row the source prints without figures (such as "Less:
Subsidies" in the production accounts) is kept with `NA` values, because
that is what the source shows.

The extraction is deliberately strict: if the workbook's layout,
sections or pinned reference values no longer match what was verified at
curation time, the function stops with `knbs_error_schema_changed` or
`knbs_error_validation_failed` rather than guessing — wrong tidy data
would be worse than an honest error.

## See also

[`knbs_abstract_tables()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_abstract_tables.md)

## Examples

``` r
if (FALSE) { # \dontrun{
gdp <- knbs_abstract_table("2.2")
expenditure <- knbs_abstract_table("expenditure on the gross domestic")
} # }
```
