# Official county codes for county names written any way

**\[experimental\]**

Turns county names — or county numbers — as they appear in anyone's data
into the official two-digit codes of the 2019 census frame, the codes
[`knbs_geographies()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_geographies.md)
and the census tables use. Built for `mutate()`:

    my_data |> mutate(geo_code = knbs_county_code(county))

KNBS's own sources disagree on names: the census writes "Murang'a",
"Tharaka-Nithi" and "Nairobi City", the Data Portal "MURANGA", "THARAKA
NITHI" and "NAIROBI". Both, and the usual variants elsewhere, resolve to
the same codes.

## Usage

``` r
knbs_county_code(
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

A character vector the length of `x`, holding two-digit codes, and `NA`
where a value did not match.

## Details

A name matches when it is the official name once case, punctuation,
spacing and apostrophes are set aside and the words "County", "City",
"Government", "of" and "the" are dropped: "Taita Taveta", "TAITA/TAVETA"
and "Taita-Taveta County" are all `"06"`, "Nairobi" and "Nairobi City
County" both `"47"`. A number from 1 to 47, written `1`, `"1"` or
`"01"`, is taken as the county number. "Kenya" and "National" give the
census code for the whole country, `"00"`.

Nothing else is matched. There is no list of alternative names, so a
misspelling stays unmatched rather than being guessed at; the warning
names each unmatched value and, where one official name is close, says
which.
[`knbs_match_counties()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_match_counties.md)
shows how every value was matched.

The official names are read from the census frame through
[`knbs_geographies()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_geographies.md),
once, and cached. If the census service cannot be reached, the 47
counties' statutory names and numbers built into the package are used
instead; they are the census frame's own, and the package's tests hold
them identical.

## See also

[`knbs_match_counties()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_match_counties.md),
[`knbs_geographies()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_geographies.md)

## Examples

``` r
if (FALSE) { # \dontrun{
knbs_county_code(c("Murang'a", "MURANGA", "Nairobi", "taita/taveta", "47"))
#> [1] "21" "21" "47" "06" "47"
} # }
```
