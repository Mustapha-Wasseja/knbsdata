# County codes and joins

``` r

library(knbsdata)
```

County-level work in Kenya lives or dies on join keys. This vignette
covers the reference codes
[`knbs_geographies()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_geographies.md)
provides, the two mistakes that silently corrupt county joins, and what
this package deliberately does not offer.

Chunks that contact the service are shown but not run.

## The reference

``` r

geo <- knbs_geographies()
counties <- knbs_geographies(level = "county")
mombasa_subs <- knbs_geographies(parent = "01")
```

One row per territorial unit of the 2019 Population and Housing Census
frame: Kenya (`"00"`), 47 counties (`"01"`–`"47"`), and their
sub-counties (four digits, the first two being the county). Names,
levels and parent codes come with it, read live from the census service
(CC BY 4.0) rather than shipped as a snapshot that could drift from the
source.

## The two classic corruptions

**Leading zeros.** County codes are character, and `"01"` is not `1`.
The moment a code passes through
[`as.numeric()`](https://rdrr.io/r/base/numeric.html) — or through a CSV
round-trip that guesses types — Mombasa (`"01"`) collides with nothing
and matches nothing. Everything in this package keeps codes as
character; keep them that way in your own pipelines, and if you read
codes from a file, read that column as character explicitly.

**Vintage mixing.** These are the *2019 census frame* units.
Administrative units change: joining 2019 codes against a table coded to
another frame will drop or misassign rows without erroring. The
`vintage` column exists so that the frame travels with the data; check
it before joining anything that did not come from this package.

## A worked join

County population against the reference, giving each county its share:

``` r

pop <- knbs_get_indicator("POPCEN0001", geo_level = "county")
totals <- pop[pop$sex == "total" & pop$marital_status == "Total",
              c("geo_code", "geo_name", "value")]

geo <- knbs_geographies(level = "county")
joined <- merge(totals, geo[, c("geo_code", "parent_code")], by = "geo_code")

joined$share <- joined$value / sum(joined$value)
head(joined[order(-joined$share), ])
```

The join is exact by construction: observations and reference use the
same codes from the same source.

## Gross County Product

The county economy itself is served by the Open Data for Africa
republisher (`source_id` `"opendataforafrica"`), the one source that
carries GCP as data: GVA shares plus constant- and current-price GCP for
all 47 counties, annual 2013–2020.

``` r

gcp <- knbs_get_indicator("jhbzkjc")
latest <- gcp[gcp$table_code == "T3" & gcp$period == 2020 & gcp$geo_code != "KE", ]
head(latest[order(-latest$value), c("geo_name", "value")])
```

Two cautions, both stated in
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md):
this is the **2021 edition** — newer GCP years exist only as PDF reports
(`knbs_publications("gross county product")`) — and its geography codes
are the **portal’s own region codes**, not census territories. To relate
GCP to census-coded data, translate its county names into census codes
with
[`knbs_county_code()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_county_code.md),
as below, rather than joining on its region codes.

## Health by county: the KDHS

The Kenya Demographic and Health Survey has reported its indicators for
all 47 counties since 2014. The DHS Program publishes them (`source_id`
`"dhs_program"`), and the package gives the county rows census codes, so
they join census tables directly:

``` r

stunting <- knbs_get_indicator("CN_NUTS_C_HA2", geo_level = "county")
pop <- knbs_get_indicator("POPCEN0002", geo_level = "county")
pop <- pop[pop$age_type == "total" & pop$sex == "total", c("geo_code", "value")]

joined <- merge(stunting[stunting$period == 2022, ], pop, by = "geo_code",
                suffixes = c("", "_population"))
head(joined[order(-joined$value), c("geo_name", "value", "value_population")], 3)
#>      geo_name value value_population
#> 3      Kilifi  37.0          1440770
#> 24 West Pokot  33.5           618761
#> 25    Samburu  31.4           307946
```

Three things to know. A county appears only where the survey’s sample
supports a county estimate: most indicators cover all 47, some only the
counties where the question applies (malaria treatment in the
lake-endemic counties, for instance). The surveys before 2014 report the
eight former provinces instead, at `geo_level` `"region"` with no code,
since no census code exists for a province. And Nairobi is both a
province and a county: where the survey lists it once, at its county
level, it is a county row.

## Matching county names across sources

County names are not spelled alike even within KNBS: the census writes
“Murang’a”, “Tharaka-Nithi” and “Nairobi City”, the Data Portal
“MURANGA”, “THARAKA NITHI” and “NAIROBI”, under codes of its own
(`KE_200_MU`). Treasury, Controller of Budget and survey data add their
own variants.
[`knbs_county_code()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_county_code.md)
turns any of them into the census codes:

``` r

knbs_county_code(c("Murang'a", "MURANGA", "Nairobi City County",
                   "taita/taveta", "Homabay", "47"))
#> [1] "21" "21" "47" "06" "43" "47"
```

Matching sets aside case, punctuation, spacing, apostrophes and the
words “County”, “City” and “Government”; numbers 1 to 47 are county
numbers; “Kenya” is `"00"`. Nothing else is matched — there is no list
of alternative names to guess from — so a misspelling becomes `NA` with
a warning that names it and suggests the nearest official name:

``` r

knbs_county_code("Kakamenga")
#> Warning: 1 value matched no county and became `NA`:
#> • "Kakamenga" (did you mean "Kakamega"?)

knbs_match_counties(c("Kakamenga", "Uasin-Gishu", "07"))   # how each matched
```

That makes cross-source joins one line. The rural share of each county’s
population, from the Data Portal’s rural table and the census:

``` r

library(dplyr)

rural <- knbs_get_indicator("DF_POP_CENSUS_RUR", source = "knbs_opendata") |>
  filter(indic_phc_code == "POP_TOT", sex == "total", geo_code != "KE") |>
  mutate(county_code = knbs_county_code(geo_name))     # "MURANGA" -> "21"

total <- knbs_get_indicator("POPCEN0002", geo_level = "county") |>
  filter(sex == "total", age_type == "total")

rural |>
  inner_join(total, by = c(county_code = "geo_code"),
             suffix = c("_rural", "_total")) |>
  mutate(rural_share = value_rural / value_total) |>
  arrange(desc(rural_share))
#> Bomet 0.97, Kitui 0.96, Elgeyo/Marakwet 0.96, ... Kiambu 0.30;
#> Nairobi City and Mombasa NA: the portal reports no rural population there.
```

All 48 names the portal uses (47 counties and KENYA) match, to 48
distinct codes.

## What is deliberately absent

- **Other vintages and crosswalks.** Only the 2019 frame has a verified
  source. `knbs_geographies(vintage = 2009)` fails with a clear error
  rather than serving an unverified concordance — a wrong crosswalk is
  worse than none.
- **Boundaries.** `knbs_boundaries()` does not exist. No officially
  licensed, redistributable boundary file has been verified, and the
  plan implements boundaries only after that review.
- **Classifications.** Industry, occupation and product classifications
  have no audited source yet.

If you know an official source for any of these, a [data source change
issue](https://github.com/Mustapha-Wasseja/knbsdata/issues/new/choose)
is the right place to point at it.
