# Kenya's geographic reference codes

**\[experimental\]**

Returns the coded territorial hierarchy used by the 2019 Population and
Housing Census: Kenya, its 47 counties, and their sub-counties, with
names and parent codes. These are the join keys the census tables
themselves use, read live from the same source (CC BY 4.0), never
shipped as a snapshot that could drift from it.

## Usage

``` r
knbs_geographies(
  level = NULL,
  vintage = NULL,
  parent = NULL,
  source = NULL,
  cache = knbs_option("cache"),
  refresh = FALSE
)
```

## Arguments

- level:

  Keep only these levels: `"national"`, `"county"`, `"subcounty"`.

- vintage:

  Reference frame year. Only `2019` is available; the argument exists so
  that code written today keeps meaning the same thing if other vintages
  arrive later.

- parent:

  Keep only units whose `parent_code` is one of these, for example
  `"01"` for Mombasa's sub-counties.

- source:

  Source id.

- cache:

  Whether to use the local cache.

- refresh:

  Whether to bypass any cached response.

## Value

A `knbs_geography` tibble with columns `geo_code`, `geo_name`,
`geo_level`, `parent_code`, `parent_name`, `vintage` and `source_id`.

## Details

Codes are character and keep their leading zeros: `"00"` is Kenya, two
digits are counties, four digits are sub-counties, and a sub-county's
first two digits are its county. `vintage` is `2019` throughout — these
are the census-frame units, and boundaries or units may have changed
since. No other vintage, and no crosswalk to other coding systems, is
offered, because none has been verified.

## See also

[`knbs_get_indicator()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_get_indicator.md),
whose observations carry the same codes.

## Examples

``` r
if (FALSE) { # \dontrun{
counties <- knbs_geographies(level = "county")
knbs_geographies(parent = "01")
} # }
```
