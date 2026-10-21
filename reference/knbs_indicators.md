# List available aggregate indicators

**\[experimental\]**

Lists the indicators served by every verified indicator source: the 2019
Population and Housing Census tables (CC BY 4.0), the monthly consumer
price series from the KNBS CPI Explorer, the KNBS Data Portal's SDMX
dataflows, the datasets republished by Kenya Open Data for Africa, and
the Kenya Demographic and Health Survey and Malaria Indicator Survey
indicators published by the DHS Program. The `source_id` column says
which source serves each row.

## Usage

``` r
knbs_indicators(
  topic = NULL,
  search = NULL,
  source = NULL,
  cache = knbs_option("cache"),
  refresh = FALSE
)
```

## Arguments

- topic:

  Keep only these topics, for example `"Population"` or `"prices"`.

- search:

  Free text matched against indicator names.

- source:

  Source id. Defaults to every verified source that lists indicators.

- cache:

  Whether to use the local cache.

- refresh:

  Whether to bypass any cached response.

## Value

A `knbs_catalogue` tibble with columns `indicator_id`, `indicator_name`,
`topic`, `frequency`, `unit` and `source_id`.

## Details

`frequency` and `unit` are filled only where the source states them: the
CPI series are monthly, in index points or percent; a census table is
not a recurring series, so its `frequency` and `unit` are `NA` rather
than invented.

If one source cannot be reached, its rows are missing and a warning says
so; the error comes only when no source answers.

## See also

[`knbs_get_indicator()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_get_indicator.md)

## Examples

``` r
if (FALSE) { # interactive()
knbs_indicators()
knbs_indicators(topic = "prices")
knbs_indicators(search = "marital")
}
```
