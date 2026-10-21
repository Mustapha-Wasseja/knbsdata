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
totals <- pop[pop$sex == "total" & pop$p18_vs1 == "T",
              c("geo_code", "geo_name", "value")]

geo <- knbs_geographies(level = "county")
joined <- merge(totals, geo[, c("geo_code", "parent_code")], by = "geo_code")

joined$share <- joined$value / sum(joined$value)
head(joined[order(-joined$share), ])
```

The join is exact by construction: observations and reference use the
same codes from the same source.

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
