# National average retail prices of the CPI basket commodities

**\[experimental\]**

Returns the monthly national average retail prices KNBS publishes for
the 22 commodities tracked for the CPI basket — maize flour, bread,
milk, petrol, house rent and the rest — one row per commodity per month
from February 2019, in Kenya Shillings per the stated unit and quantity.

## Usage

``` r
knbs_retail_prices(
  commodity = NULL,
  start = NULL,
  end = NULL,
  source = NULL,
  cache = knbs_option("cache"),
  refresh = FALSE
)
```

## Arguments

- commodity:

  Keep only these commodities, by `CPI001`-style code or COICOP code
  (exact), or by name (matched as text).

- start, end:

  Keep only these months. A year, a `"YYYY-MM"` month, or a date.

- source:

  Ask only this source: `"knbs_opendata"` (the KNBS Data Portal) or
  `"knbs_cpi"` (the CPI Explorer). By default the Data Portal is asked
  first and the CPI Explorer if it does not answer.

- cache:

  Whether to use the local cache.

- refresh:

  Whether to bypass any cached response.

## Value

A `knbs_prices` tibble with columns `commodity_code`, `coicop_code`,
`commodity`, `unit`, `quantity`, `period`, `period_label`, `price` and
`source_id`.

## Details

Two KNBS sources publish these prices, and they publish the same
figures: the KNBS Data Portal (dataflow `DF_CPI_NA`) and the CPI
Explorer. The Data Portal is asked first; if it does not answer, the CPI
Explorer is, and a message says so. The `source_id` column and
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
name the source that answered. Commodities carry the CPI Explorer's
codes, names and units whichever source answered, and `coicop_code` is
the international COICOP item code.

These are national averages only: neither source holds regional retail
prices. Neither states a licence;
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
on the result says so. The full history is retrieved once (a few
seconds, then cached).

## See also

[`knbs_get_indicator()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_get_indicator.md)
for the price *indices*: the CPI by region (`"CPI_ALL_ITEMS"`, or
`"DF_CPI_R"` on the Data Portal) and by division (`"DF_CPI_IX"`).

## Examples

``` r
if (FALSE) { # interactive()
knbs_retail_prices(commodity = "petrol", start = 2024)
knbs_retail_prices(start = "2026-06", end = "2026-06")
}
```
