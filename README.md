
<!-- README.md is generated from README.Rmd. Please edit that file -->

# knbsdata

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/Mustapha-Wasseja/knbsdata/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Mustapha-Wasseja/knbsdata/actions/workflows/R-CMD-check.yaml)
[![R-universe](https://mustapha-wasseja.r-universe.dev/badges/knbsdata)](https://mustapha-wasseja.r-universe.dev/knbsdata)
<!-- badges: end -->

`knbsdata` is an R client and standardisation layer for discovering,
downloading, documenting and analysing official statistics published by
the Kenya National Bureau of Statistics (KNBS).

The package aims to make it straightforward to find the right dataset,
understand its metadata and access conditions, retrieve it in a
consistent tidy shape, keep the provenance attached to the data, and
cite it correctly.

## Scope

**Implemented: surveys and open microdata, publications, and indicators
— census, prices, the economy, Gross County Product, and health and
demography from the KDHS.**

- **One search across everything**: `knbs_search()` ranks indicators,
  Abstract tables, surveys, open microdata and publications together,
  and hands back the call that retrieves each one.
- **Surveys**, against the Kenya National Data Archive: search studies,
  read their full documentation, search their variables, and list their
  data files — with provenance and citations attached throughout.
- **Open survey microdata**, from the FinAccess portal: the anonymised,
  weighted microdata of the FinAccess household surveys (six rounds,
  2006–2024) and the MSE Tracker Survey, published by the Central Bank
  of Kenya, KNBS and FSD Kenya — downloaded with name, size and SHA-256
  verified against a catalogue, and read into R with their labels and a
  citation.
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
- **Health and demography from the KDHS**, against the DHS Program’s
  Indicator Data API: 4,000-odd indicators from the Kenya Demographic
  and Health Surveys (1989–2022) and the Malaria Indicator Surveys —
  stunting, fertility, vaccination, family planning, HIV, malaria — by
  wealth, residence and education, and for the 47 counties from 2014,
  with census county codes so they join the census tables.
- **Statistical Abstract tables as tidy data**: 48 tables of the 2025
  edition across 13 chapters — the whole National Accounts chapter, and
  wage employment, prices, trade, agriculture, energy, manufacturing,
  construction, tourism, transport, education, and registered births and
  deaths — extracted from the official workbooks by hand-verified
  recipes that are re-checked on every read. County tables carry census
  codes, so they join everything else.
- **Geographic reference codes**: Kenya, its 47 counties and their
  sub-counties in the 2019 census frame, with names, parent codes and an
  explicit vintage — the join keys the census tables themselves use —
  and `knbs_county_code()`, which turns county names spelled any way
  (census, Data Portal, Treasury, your own spreadsheet) into those
  codes.

Not implemented:

- **The newest Gross County Product years as data.** The data version is
  the 2021 edition (through 2020); the editions since exist only as PDF
  reports — find and download them through
  `knbs_publications("gross county product")`.
- **Boundary geometries, other geographic vintages, crosswalks and
  classifications** — nothing verified, so nothing served.
- **Microdata from the national data archive.** KeNADA requires an
  account for every download. `knbs_download_microdata()` explains the
  official process and stops; the package does not automate sign-in or
  licence acceptance. (FinAccess, above, is published openly.)
- **Survey documentation files.** The archive publishes no
  machine-readable listing of questionnaires or reports.

`vignette("source-status")` states all of this in full. Findings are in
[`dev/source-discovery/source-audit.md`](dev/source-discovery/source-audit.md).

## Installation

Ready-built for Windows, macOS and Linux from R-universe, so no compiler
or Rtools is needed:

``` r
install.packages(
  "knbsdata",
  repos = c("https://mustapha-wasseja.r-universe.dev", "https://cloud.r-project.org")
)
```

Or the development version from GitHub:

``` r
# install.packages("pak")
pak::pak("Mustapha-Wasseja/knbsdata")
```

## What works today

``` r
library(knbsdata)

# Which sources does the package know about, and how far are they verified?
knbs_sources()
#> # A tibble: 9 × 8
#>   source_id         source_name  source_type operations stability authentication
#>   <chr>             <chr>        <chr>       <list>     <chr>     <chr>         
#> 1 kenada            Kenya Natio… survey_cat… <chr [4]>  experime… none          
#> 2 finaccess         FinAccess H… static_fil… <chr [1]>  experime… none          
#> 3 knbs_publications KNBS Public… publicatio… <chr [3]>  experime… none          
#> 4 knbs_indicators   KNBS Census… indicator_… <chr [4]>  experime… none          
#> 5 knbs_cpi          KNBS CPI Ex… indicator_… <chr [4]>  experime… none          
#> 6 knbs_opendata     KNBS Data P… indicator_… <chr [3]>  experime… none          
#> 7 opendataforafrica Kenya Open … indicator_… <chr [3]>  experime… none          
#> 8 dhs_program       The DHS Pro… indicator_… <chr [3]>  experime… none          
#> 9 fake_source       Offline tes… fake        <chr [6]>  discovery none          
#> # ℹ 2 more variables: last_verified <date>, base_url <chr>
```

``` r
# Is anything answering? This form contacts nothing; knbs_status(live = TRUE) does.
knbs_status()[, c("source_id", "status", "message")]
#> # A tibble: 9 × 3
#>   source_id         status      message                                   
#>   <chr>             <chr>       <chr>                                     
#> 1 kenada            not_checked Set live = TRUE to contact the source.    
#> 2 finaccess         not_checked Set live = TRUE to contact the source.    
#> 3 knbs_publications not_checked Set live = TRUE to contact the source.    
#> 4 knbs_indicators   not_checked Set live = TRUE to contact the source.    
#> 5 knbs_cpi          not_checked Set live = TRUE to contact the source.    
#> 6 knbs_opendata     not_checked Set live = TRUE to contact the source.    
#> 7 opendataforafrica not_checked Set live = TRUE to contact the source.    
#> 8 dhs_program       not_checked Set live = TRUE to contact the source.    
#> 9 fake_source       unverified  Endpoint not verified; nothing to contact.
```

Search everything at once — indicators, Statistical Abstract tables,
surveys and publications. Each result carries the call that retrieves it
(live requests, not run here):

``` r
hits <- knbs_search("consumer price index")
hits$get[[1]]
#> [1] "knbs_get_indicator(\"CPI_ALL_ITEMS\", source = \"knbs_cpi\")"

knbs_search("gdp", type = c("indicator", "table"))
knbs_search("kdhs", type = "survey")
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

Open microdata (live requests, not run here):

``` r
# Every FinAccess file: six household rounds, 2006-2024, and the MSE Tracker
knbs_finaccess_files(content = "data")

# The 2024 household survey (Stata, 160 MB): downloaded once, verified,
# and read with its value labels; re-running reuses the file
fa <- knbs_read_microdata(knbs_download_finaccess("hh2024-stata", "data"))
knbs_cite(fa)

# The 2024 and 2021 questionnaires and manuals
knbs_finaccess_files(content = c("questionnaire", "manual")) |>
  knbs_download_finaccess("data/docs")
```

Publications (also live requests, not run here):

``` r
# Find publications
pubs <- knbs_publications("economic survey", year = 2026)

# Download one: verified, checksummed, with a provenance sidecar
knbs_download_publication(pubs$publication_id[[1]], "data/publications")

# What has KNBS released lately? Series and period read from each title
knbs_releases()                      # last 30 days, tenders and adverts left out
knbs_releases(series = "cpi")[1, ]   # the latest CPI release
```

Indicators and tables (live requests, not run here):

``` r
# The Statistical Abstract's tables, tidy: GDP by activity, county births...
knbs_abstract_tables()
gdp <- knbs_abstract_table("2.2")
births <- knbs_abstract_table("16.11")      # by county, with census codes

# County populations from the 2019 census, leading-zero codes intact
pop <- knbs_get_indicator("POPCEN0001", geo_level = "county")
knbs_cite(pop)

# The matching reference codes, for joins
knbs_geographies(level = "county")

# County names written any way, as census codes - for joining anyone's data
knbs_county_code(c("Murang'a", "MURANGA", "Nairobi City County", "47"))
#> [1] "21" "21" "47" "47"

# GDP, trade, county finance and more from the KNBS Data Portal (SDMX)
gdp_flow <- knbs_get_indicator("DF_NAT_GDPCP", source = "knbs_opendata")

# Monthly CPI and inflation, from 2009, from the CPI Explorer
cpi <- knbs_get_indicator("CPI_ALL_ITEMS", start = "2020-01")
knbs_get_indicator("CPI_INFLATION_YOY", geo_level = "region")

# Gross County Product, all 47 counties, 2013-2020, from Open Data for Africa
gcp <- knbs_get_indicator("jhbzkjc")

# Child stunting from the KDHS, every survey since 1993, counties from 2014
stunting <- knbs_get_indicator("CN_NUTS_C_HA2", geo_level = "county")

# ...joined to 2019 census populations by their shared county codes
pop <- knbs_get_indicator("POPCEN0002", geo_level = "county")
pop <- pop[pop$age_type == "total" & pop$sex == "total", c("geo_code", "value")]
merge(stunting[stunting$period == 2022, ], pop, by = "geo_code",
      suffixes = c("", "_population"))
```

Each source is a separate KNBS (or partner) service, and any of them can
be down for a while. `knbs_status(live = TRUE)` shows which are
answering. A call to a source that is down fails with a clear
`knbs_error_source_unavailable` rather than partial data, and where
another source publishes the same series the error names it: during a
CPI Explorer outage, for instance, it points to the Data Portal’s
`DF_CPI_R` index.

Hand the data to colleagues in Excel, Stata or SPSS without losing where
it came from:

``` r
knbs_write(gdp, "gdp-by-activity.xlsx")  # data sheet + "about" sheet with source and citation
knbs_write(gdp, "gdp-by-activity.dta")   # + gdp-by-activity.dta.metadata.json beside it
```

## Access conditions

`knbsdata` will not circumvent registration requirements, licence
agreements, approval processes, authentication or rate limits. It does
not crawl: it requests only what you ask for, under its own name,
throttled and cached. Robots exclusions are honoured as the rules for
crawlers they are — where a site bars automated clients from one route
and permits another, the package uses the permitted one; where a
publisher’s robots file bars its own API while its documentation invites
applications to use it, as the DHS Program’s does, the package follows
the documentation, and the source audit records why. Datasets that
require authorised access are represented in the catalogue with their
access conditions, but are not downloaded: the package points you at the
official access process instead. Microdata are downloaded only where the
producers publish them for anyone, as FinAccess does, and never bundled
with the package; the terms the producers state travel with each file.

Retrieved data and publications remain subject to their producers’ terms
and licences. The MIT licence in this repository covers the software
only.

## Sources change

Official portals are re-organised from time to time. When a source
changes shape the package should fail with a clear, classed error rather
than return incomplete data. If you hit one, please open a [data source
change
issue](https://github.com/Mustapha-Wasseja/knbsdata/issues/new/choose).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), including the checklist for
adding a new source adapter. Please note that this project is released
with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md).

## Disclaimer

`knbsdata` is an independent open-source software project designed to
facilitate access to publicly available statistics and metadata
published by the Kenya National Bureau of Statistics. It is not an
official KNBS product unless and until KNBS formally adopts or endorses
it. Users should consult the original KNBS source for authoritative
definitions, revisions, access conditions and official releases.
