# See how county names were matched

**\[experimental\]**

The diagnostic companion to
[`knbs_county_code()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_county_code.md):
one row per distinct value of `x`, saying which county it matched, how,
and — for a value that matched nothing — the official name it most
resembles, if any.

## Usage

``` r
knbs_match_counties(
  x,
  vintage = 2019L,
  cache = knbs_option("cache"),
  refresh = FALSE
)
```

## Arguments

- x:

  County names or numbers: a character, numeric or factor vector.

- vintage:

  The census frame to match against. Only 2019 is available.

- cache:

  Whether to use the local cache for the reference names.

- refresh:

  Whether to re-read the reference names.

## Value

A tibble with columns `input`, `geo_code`, `geo_name` (the official
name), `matched_by` (`"name"`, `"number"`, `"national"`, or `NA`) and
`suggestion` (for unmatched values only).

## See also

[`knbs_county_code()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_county_code.md)

## Examples

``` r
if (FALSE) { # \dontrun{
knbs_match_counties(c("Nairobi City County", "Kakamenga", "12"))
} # }
```
