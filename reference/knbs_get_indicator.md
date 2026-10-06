# Retrieve an indicator as tidy observations

**\[experimental\]**

Returns one row per observation for a census table or a consumer price
series, depending on the indicator asked for.

## Usage

``` r
knbs_get_indicator(
  indicator,
  start = NULL,
  end = NULL,
  geo_level = NULL,
  geo_code = NULL,
  frequency = NULL,
  source = NULL,
  cache = knbs_option("cache"),
  refresh = FALSE
)
```

## Arguments

- indicator:

  An indicator id (see
  [`knbs_indicators()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_indicators.md)),
  or enough of an indicator name to identify one unambiguously.

- start, end:

  Keep only observations in this period range. A year, a `"YYYY-MM"`
  month, or a date.

- geo_level:

  Keep only these levels. Census tables: `"national"`, `"county"`,
  `"subcounty"`. CPI series: `"national"`, `"region"`.

- geo_code:

  Keep only these codes, as character, in the indicator's own geography.

- frequency:

  Keep only series of this frequency: `"annual"`, `"quarterly"` or
  `"monthly"`. Only the Open Data for Africa source accepts it — its
  datasets may carry annual and sub-annual series side by side, and a
  mixed dataset asks you to choose rather than picking one silently.

- source:

  Source id, to disambiguate an indicator served by more than one
  source.

- cache:

  Whether to use the local cache.

- refresh:

  Whether to bypass any cached response.

## Value

A `knbs_indicator` tibble.
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
returns its provenance;
[`knbs_cite()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cite.md)
cites it.

## Details

The period convention follows the source's own frequency. Monthly series
(the CPI family) carry `period` as a `Date` at the first of the month
plus a `period_label` like `"2026-06"`; census tables carry the census
year as an integer `period`. `start` and `end` accept a year (`2020`), a
month (`"2020-01"`), or a full date, and apply to both conventions.

Geography differs by family and the two systems must not be mixed.
Census tables use territory codes (`geo_level` of `"national"`,
`"county"`, `"subcounty"`) that join
[`knbs_geographies()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_geographies.md).
The CPI series use the CPI collection strata (`geo_level` of
`"national"` or `"region"`: the Nairobi income bands, Rest of Urban, and
the former provinces) — their codes are the source's own and must never
be joined against census territories. Six listed CPI regions, the former
provinces, carry no data in any period; asking for them returns zero
rows because that is the source's answer.

For the CPI family the default is the national series; ask for
`geo_level = "region"` or name `geo_code`s for more. The CPI portal
states no licence and no index base period;
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
on the result says so. If the CPI Explorer is down, the error names the
KNBS Data Portal series that stands in for the one asked for, and how
closely: the portal's index has matched it, its rounded inflation rates
have not always.

Every other dimension of a table becomes a pair of columns, `<name>`
holding the source's labels and `<name>_code` its codes, the way
`geo_name` and `geo_code` pair up. Census tables use short curated names
(`marital_status`, `age`, `religion`, ...); Data Portal flows use their
SDMX dimension id in lower case (`na_indic`, `commodity`); Open Data for
Africa datasets use the portal's dimension id (`table`, `indicator`). A
Sex dimension is always `sex`, in lower case. The census age table mixes
single years with five-year groups, so it carries `age_type` (`"total"`,
`"single_year"`, `"age_group"`, `"other"`): keep one type before
summing.

## See also

[`knbs_indicators()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_indicators.md),
[`knbs_geographies()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_geographies.md)

## Examples

``` r
if (FALSE) { # \dontrun{
cpi <- knbs_get_indicator("CPI_ALL_ITEMS", start = "2020-01")
inflation <- knbs_get_indicator("CPI_INFLATION_YOY", geo_level = "region")
pop <- knbs_get_indicator("POPCEN0001", geo_level = "county")
gcp <- knbs_get_indicator("jhbzkjc") # Gross County Product
} # }
```
