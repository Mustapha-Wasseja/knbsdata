
<!-- README.md is generated from README.Rmd. Please edit that file -->

# knbsdata

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/Mustapha-Wasseja/knbsdata/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Mustapha-Wasseja/knbsdata/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

`knbsdata` is an R client and standardisation layer for discovering,
downloading, documenting and analysing official statistics published by
the Kenya National Bureau of Statistics (KNBS).

The package aims to make it straightforward to find the right dataset,
understand its metadata and access conditions, retrieve it in a
consistent tidy shape, keep the provenance attached to the data, and
cite it correctly.

## Status

**Early development. The survey catalogue works; publications and
indicators do not exist yet.**

The package is at Phase 3 of its [implementation
plan](knbsdata_implementation_plan.md). Survey discovery is implemented
against the Kenya National Data Archive: search studies, read their
metadata, search their variables and list their data files.

Microdata downloads are gated behind an account at the archive, so the
package will not fetch them — `knbs_download_microdata()` explains the
official process and stops. Publications and aggregate indicators are
not implemented, because `knbs.or.ke` was unavailable throughout the
source audit. Findings are in
[`dev/source-discovery/source-audit.md`](dev/source-discovery/source-audit.md)
and progress in
[`dev/IMPLEMENTATION_STATUS.md`](dev/IMPLEMENTATION_STATUS.md).

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
#> # A tibble: 4 × 8
#>   source_id         source_name  source_type operations stability authentication
#>   <chr>             <chr>        <chr>       <list>     <chr>     <chr>         
#> 1 kenada            Kenya Natio… survey_cat… <chr [4]>  experime… none          
#> 2 knbs_publications KNBS Public… publicatio… <chr [3]>  discovery none          
#> 3 knbs_indicators   KNBS Aggreg… indicator_… <chr [3]>  discovery none          
#> 4 fake_source       Offline tes… fake        <chr [6]>  discovery none          
#> # ℹ 2 more variables: last_verified <date>, base_url <chr>
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

## What it will look like

These are specified but not yet implemented, and depend on sources that
could not be audited:

``` r
knbs_search("consumer price index")
cpi <- knbs_get_indicator("CPI_ALL_ITEMS", start = "2020-01")
knbs_publications(topic = "economic survey", year = 2026)
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
