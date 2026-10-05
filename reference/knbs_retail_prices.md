# National average retail prices of the CPI basket commodities

**\[experimental\]**

Returns the monthly national average retail prices the KNBS CPI Explorer
publishes for the 22 commodities it tracks — maize flour, bread, milk,
petrol, house rent and the rest — one row per commodity per month, in
Kenya Shillings per the stated unit and quantity.

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

  Keep only these commodities, by `CPI001`-style code (exact) or by name
  (matched as text).

- start, end:

  Keep only these months. A year, a `"YYYY-MM"` month, or a date.

- source:

  Source id.

- cache:

  Whether to use the local cache.

- refresh:

  Whether to bypass any cached response.

## Value

A `knbs_prices` tibble with columns `commodity_code`, `commodity`,
`unit`, `quantity`, `period`, `period_label`, `price` and `source_id`.

## Details

These are national averages only: the source holds no regional retail
prices. The portal states no licence;
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
on the result says so. A range query retrieves the full history once (a
few seconds, then cached); an exact single month is fetched directly.

## See also

[`knbs_get_indicator()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_get_indicator.md)
for the price *indices* the same portal serves.

## Examples

``` r
if (FALSE) { # \dontrun{
knbs_retail_prices(commodity = "petrol", start = 2024)
knbs_retail_prices(start = "2026-06", end = "2026-06")
} # }
```
