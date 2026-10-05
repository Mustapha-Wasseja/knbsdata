# Getting started with knbsdata

``` r
library(knbsdata)
```

`knbsdata` is a client for official statistics published by the Kenya
National Bureau of Statistics. It covers six source families: **survey
and census study discovery**, **publications** (statistical releases,
reports and workbooks, downloadable with verification), **census
tables** as tidy observations, **monthly consumer prices** from 2009
onwards, **the economy as SDMX dataflows** (GDP, trade, county finance
and 320 more), and **geographic reference codes** for county-level
joins.

Code that contacts the archive is shown but not run here, so building
this vignette never depends on a live service.

## What is and is not in this version

``` r
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

Six sources are verified and usable: `kenada`, the Kenya National Data
Archive (surveys); `knbs_publications`, the KNBS website’s media
library; `knbs_indicators`, the KNBS census data service (2019 census
tables, CC BY 4.0); `knbs_cpi`, the CPI Explorer (monthly consumer
prices from 2009); `knbs_opendata`, the Data Portal (323 SDMX dataflows:
GDP, trade, county finance and more); and `opendataforafrica`, the
Knoema-operated republisher that fills gaps no first-party portal serves
as data — Gross County Product above all. A source the audit has not
verified stays at stability `discovery` and is never contacted — there
is nothing there to call. The `source-status` vignette says exactly what
is and is not covered, and why.

## Five ideas worth knowing

### 1. Everything carries its provenance

Objects returned by the package know where they came from.

``` r
meta <- knbs_survey_metadata("KEN-KNBS-KIHBS-2015-2016-v01")
knbs_metadata(meta)
```

That record holds the source, the retrieval timestamp, the release date,
the access conditions and the package version — everything needed to say
later what exactly was used.

### 2. Citations come from the data, not from you

``` r
knbs_cite(meta)
knbs_cite(meta, style = "bibtex")
```

Where the archive states a required citation, that text is used verbatim
and the package adds only the retrieval information. It cannot cite a
release the object does not have.

### 3. Access conditions are data, not decoration

Two different questions, two different columns:

- `access_type` is what the **archive** permits. `public_use` means
  public-use files exist.
- `downloadable` is what **this package** will do. For survey microdata
  it is `FALSE` throughout; publications, by contrast, are served openly
  and can be downloaded.

Those differ because the archive requires an account for every download.
The package does not automate sign-in, licence acceptance or approval
workflows, so
[`knbs_download_microdata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_microdata.md)
explains the official route and stops. That is a deliberate boundary,
not a missing feature.

### 4. Failure is explicit

Every failure carries a condition class, and none of them return partial
data dressed up as a result:

``` r
tryCatch(
  knbs_survey_metadata("Kenya"),
  knbs_error_ambiguous_resource = function(cnd) cnd$matches
)
```

Catch `error`, or a specific `knbs_error_*` class — not `condition`,
because httr2 signals a benign condition on every request.

### 5. Everything is a tibble that speaks tidyverse

Every data-carrying result is a tidy tibble — one row per observation,
built on vctrs — so dplyr verbs work directly and keep the provenance
attached: filter, mutate, arrange, join, and
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
still answers on the result. Aggregations (`summarise`) and reshapes
(`pivot_wider`) return plain tibbles, because a derived table is your
data, not the source’s;
[`tibble::as_tibble()`](https://tibble.tidyverse.org/reference/as_tibble.html)
drops the wrapper whenever you want out.

``` r
library(dplyr)
library(tidyr)

knbs_get_indicator("jhbzkjc") |>                    # Gross County Product
  filter(table == "T3", period == 2020) |>
  slice_max(value, n = 5)

knbs_abstract_table("2.2") |>                       # years across, like print
  select(industry, period, value) |>
  pivot_wider(names_from = period, values_from = value)
```

## A first session

``` r
# 1. Find something
studies <- knbs_search_surveys("household budget")

# 2. Read its record
meta <- knbs_survey_metadata(studies$survey_id[[1]])

# 3. See what variables it documents
knbs_variables(meta$resource_id, search = "expenditure")

# 4. See what files exist, and on what terms
knbs_survey_files(meta$resource_id)

# 5. Record what you used
knbs_cite(meta)
```

Publications work the same way, and these files *can* be downloaded —
they are served openly by the KNBS website:

``` r
pubs <- knbs_publications("economic survey", year = 2026)
knbs_download_publication(pubs$publication_id[[1]], "data/publications")
```

The download is verified (a web page arriving where a document was
expected is refused), checksummed with SHA-256, and given a
`<file>.metadata.json` provenance sidecar.

Indicators come back as tidy observations — consumer prices, the
national accounts, Gross County Product, and census tables with
geography down to sub-county:

``` r
cpi <- knbs_get_indicator("CPI_ALL_ITEMS", start = "2020-01")
gdp <- knbs_get_indicator("DF_NAT_GDPCP")            # GDP by activity, SDMX
knbs_get_indicator("DF_PF_CG_REV")                   # county govt revenue
gcp <- knbs_get_indicator("jhbzkjc")                 # Gross County Product

knbs_indicators(topic = "Population")
pop <- knbs_get_indicator("POPCEN0001", geo_level = "county")

# The matching reference codes, for census joins
knbs_geographies(level = "county")
```

## Configuration

Options are ordinary R options under the `knbsdata.` prefix:

``` r
knbs_options()
#> $cache
#> [1] TRUE
#> 
#> $cache_dir
#> NULL
#> 
#> $timeout
#> [1] 30
#> 
#> $retries
#> [1] 3
#> 
#> $user_agent
#> NULL
#> 
#> $quiet
#> [1] FALSE
```

``` r
knbs_options(timeout = 60, retries = 5)
```

## Caching

Catalogue responses are cached for 24 hours, keyed on the source, the
operation, the normalised query and the package’s parser version — so
upgrading the package invalidates anything a new parser would read
differently.

``` r
knbs_cache_info()
knbs_search_surveys("household budget", refresh = TRUE)  # ignore the cache
knbs_cache_clear()
```

Cached values are checksummed. An entry that fails its checksum is
discarded and refetched rather than returned.

## Where to next

- [`vignette("survey-catalogue")`](https://Mustapha-Wasseja.github.io/knbsdata/articles/survey-catalogue.md)
  — the survey workflow in depth
- [`vignette("census-indicators")`](https://Mustapha-Wasseja.github.io/knbsdata/articles/census-indicators.md)
  — indicators: census tables and consumer prices
- [`vignette("county-data")`](https://Mustapha-Wasseja.github.io/knbsdata/articles/county-data.md)
  — county codes, vintages and safe joins
- [`vignette("source-status")`](https://Mustapha-Wasseja.github.io/knbsdata/articles/source-status.md)
  — what each source supports, and the limitations of this release
