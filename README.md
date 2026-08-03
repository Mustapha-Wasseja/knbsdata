
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

**Early development — no data retrieval is implemented yet.**

The package is at Phase 0 of its [implementation
plan](knbsdata_implementation_plan.md): the foundations (options,
structured conditions, source registry, tests, CI) are in place, but no
KNBS endpoint has been verified. Every source in the registry is at
stability `discovery` and no function makes a network request. Endpoint
verification is Phase 1, tracked in
[`dev/source-discovery/source-audit.md`](dev/source-discovery/source-audit.md).

Progress is tracked in
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
#> 1 kenada            Kenya Natio… survey_cat… <chr [5]>  discovery source_defined
#> 2 knbs_publications KNBS Public… publicatio… <chr [3]>  discovery none          
#> 3 knbs_indicators   KNBS Aggreg… indicator_… <chr [3]>  discovery none          
#> 4 fake_source       Offline tes… fake        <chr [4]>  discovery none          
#> # ℹ 2 more variables: last_verified <date>, base_url <chr>
```

``` r
# Session configuration
knbs_option("timeout")
#> [1] 30
```

## What it will look like

These functions are specified but not yet implemented:

``` r
# Search the supported KNBS catalogues
knbs_search("consumer price index")

# Download an indicator, with provenance attached
cpi <- knbs_get_indicator("CPI_ALL_ITEMS", start = "2020-01")
knbs_metadata(cpi)
knbs_cite(cpi)

# Search survey metadata without downloading microdata
knbs_search_surveys("household budget")
knbs_variables(survey = "KIHBS-2015", search = "food expenditure")
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
