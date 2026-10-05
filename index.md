# knbsdata

`knbsdata` is an R client and standardisation layer for discovering,
downloading, documenting and analysing official statistics published by
the Kenya National Bureau of Statistics (KNBS).

The package aims to make it straightforward to find the right dataset,
understand its metadata and access conditions, retrieve it in a
consistent tidy shape, keep the provenance attached to the data, and
cite it correctly.

## Scope

**Implemented: surveys, publications, and indicators — census, prices,
the economy, and Gross County Product.**

- **Surveys**, against the Kenya National Data Archive: search studies,
  read their full documentation, search their variables, and list their
  data files — with provenance and citations attached throughout.
- **Publications**, against the KNBS website’s media library: search
  roughly 1,600 statistical releases, reports and workbooks, and
  download them with verification, SHA-256 checksums and a provenance
  sidecar.
- **Census tables**, against the KNBS census data service: the 2019
  Population and Housing Census as tidy observations, with geography
  down to sub-county and an explicit CC BY 4.0 licence.
- **Consumer prices**, against the KNBS CPI Explorer: the monthly index
  and inflation from January 2009, nationally and by the CPI collection
  strata, plus the retail prices of the CPI basket commodities.
- **The economy**, against the KNBS Data Portal: 323 SDMX dataflows —
  GDP by activity and expenditure, trade, balance of payments, county
  government finance, employment and more.
- **Gross County Product and the republished datasets**, against Kenya
  Open Data for Africa: GCP for all 47 counties (2013–2020, constant and
  current prices) plus 200 more datasets from KNBS, the Central Bank of
  Kenya and partner agencies — with republisher provenance stated on
  every result.
- **Statistical Abstract tables as tidy data**: the 2025 edition’s
  National Accounts chapter — production accounts, GDP, expenditure,
  capital formation, income and saving — extracted from the official
  workbooks by hand-verified recipes that are re-checked on every read.
- **Geographic reference codes**: Kenya, its 47 counties and their
  sub-counties in the 2019 census frame, with names, parent codes and an
  explicit vintage — the join keys the census tables themselves use.

Not implemented:

- **The newest Gross County Product years as data.** The data version is
  the 2021 edition (through 2020); the editions since exist only as PDF
  reports — find and download them through
  `knbs_publications("gross county product")`.
- **Boundary geometries, other geographic vintages, crosswalks and
  classifications** — nothing verified, so nothing served.
- **Microdata downloads.** The survey archive requires an account for
  every download.
  [`knbs_download_microdata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_microdata.md)
  explains the official process and stops; the package does not automate
  sign-in or licence acceptance.
- **Survey documentation files.** The archive publishes no
  machine-readable listing of questionnaires or reports.

[`vignette("source-status")`](https://Mustapha-Wasseja.github.io/knbsdata/articles/source-status.md)
states all of this in full. Findings are in
[`dev/source-discovery/source-audit.md`](https://Mustapha-Wasseja.github.io/knbsdata/dev/source-discovery/source-audit.md).

## Installation

``` r

# install.packages("pak")
pak::pak("Mustapha-Wasseja/knbsdata")
```

## What works today

``` r

library(knbsdata)

# Which sources does the package know about, and how far are they verified?
knbs_sources()
#> # A tibble: 7 × 8
#>   source_id         source_name  source_type operations stability authentication
#>   <chr>             <chr>        <chr>       <list>     <chr>     <chr>         
#> 1 kenada            Kenya Natio… survey_cat… <chr [4]>  experime… none          
#> 2 knbs_publications KNBS Public… publicatio… <chr [3]>  experime… none          
#> 3 knbs_indicators   KNBS Census… indicator_… <chr [4]>  experime… none          
#> 4 knbs_cpi          KNBS CPI Ex… indicator_… <chr [4]>  experime… none          
#> 5 knbs_opendata     KNBS Data P… indicator_… <chr [3]>  experime… none          
#> 6 opendataforafrica Kenya Open … indicator_… <chr [3]>  experime… none          
#> 7 fake_source       Offline tes… fake        <chr [6]>  discovery none          
#> # ℹ 2 more variables: last_verified <date>, base_url <chr>
```

``` r

# Is anything answering? This form contacts nothing; knbs_status(live = TRUE) does.
knbs_status()[, c("source_id", "status", "message")]
#> # A tibble: 7 × 3
#>   source_id         status      message                                   
#>   <chr>             <chr>       <chr>                                     
#> 1 kenada            not_checked Set live = TRUE to contact the source.    
#> 2 knbs_publications not_checked Set live = TRUE to contact the source.    
#> 3 knbs_indicators   not_checked Set live = TRUE to contact the source.    
#> 4 knbs_cpi          not_checked Set live = TRUE to contact the source.    
#> 5 knbs_opendata     not_checked Set live = TRUE to contact the source.    
#> 6 opendataforafrica not_checked Set live = TRUE to contact the source.    
#> 7 fake_source       unverified  Endpoint not verified; nothing to contact.
```

Surveys (these contact the archive, so they are not run here):

``` r

# Find a study
studies <- knbs_search_surveys("household budget")

# Read its documentation
meta <- knbs_survey_metadata("KEN-KNBS-KIHBS-2015-2016-v01")
knbs_cite(meta)

# Search its variables without downloading any microdata
knbs_variables("KEN-KNBS-KIHBS-2015-2016-v01", search = "expenditure")

# See what it holds, and on what terms
knbs_survey_files("KEN-KNBS-KIHBS-2015-2016-v01")
```

Publications (also live requests, not run here):

``` r

# Find publications
pubs <- knbs_publications("economic survey", year = 2026)

# Download one: verified, checksummed, with a provenance sidecar
knbs_download_publication(pubs$publication_id[[1]], "data/publications")
```

Indicators (live requests, not run here):

``` r

# Monthly CPI and inflation, from 2009
cpi <- knbs_get_indicator("CPI_ALL_ITEMS", start = "2020-01")
knbs_get_indicator("CPI_INFLATION_YOY", geo_level = "region")

# Gross County Product, all 47 counties, 2013-2020
gcp <- knbs_get_indicator("jhbzkjc")

# The Statistical Abstract's National Accounts tables, tidy
knbs_abstract_tables()
gdp <- knbs_abstract_table("2.2")

# County populations from the 2019 census, leading-zero codes intact
pop <- knbs_get_indicator("POPCEN0001", geo_level = "county")
knbs_cite(pop)

# The matching reference codes, for joins
knbs_geographies(level = "county")
```

## What it will look like

Specified but not yet implemented:

``` r

knbs_search("consumer price index")
```

## Access conditions

`knbsdata` will not circumvent registration requirements, licence
agreements, approval processes, authentication, rate limits or robots
exclusions. Datasets that require authorised access are represented in
the catalogue with their access conditions, but are not downloaded: the
package points you at the official access process instead.

Retrieved data and publications remain subject to KNBS terms and
licences. The MIT licence in this repository covers the software only.

## Sources change

Official portals are re-organised from time to time. When a source
changes shape the package should fail with a clear, classed error rather
than return incomplete data. If you hit one, please open a [data source
change
issue](https://github.com/Mustapha-Wasseja/knbsdata/issues/new/choose).

## Contributing

See
[CONTRIBUTING.md](https://Mustapha-Wasseja.github.io/knbsdata/CONTRIBUTING.md),
including the checklist for adding a new source adapter. Please note
that this project is released with a [Contributor Code of
Conduct](https://Mustapha-Wasseja.github.io/knbsdata/CODE_OF_CONDUCT.md).

## Disclaimer

`knbsdata` is an independent open-source software project designed to
facilitate access to publicly available statistics and metadata
published by the Kenya National Bureau of Statistics. It is not an
official KNBS product unless and until KNBS formally adopts or endorses
it. Users should consult the original KNBS source for authoritative
definitions, revisions, access conditions and official releases.
