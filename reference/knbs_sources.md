# Supported KNBS sources

Lists the sources declared in the package source registry, together with
the operations each one supports and how far it has been verified. No
network request is made; this reports what the package believes about
each source.

## Usage

``` r
knbs_sources(operation = NULL, status = NULL)
```

## Arguments

- operation:

  Optional. Keep only sources supporting this operation, for example
  `"search_surveys"` or `"get_indicator"`.

- status:

  Optional. Keep only sources at these stability levels: one or more of
  `"discovery"`, `"experimental"`, `"beta"`, `"stable"` or
  `"deprecated"`.

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
row per source and columns `source_id`, `source_name`, `source_type`,
`operations` (a list-column), `stability`, `authentication`,
`last_verified` and `base_url`.

## Details

Sources whose `base_url` has not yet been verified are shown with
stability `"discovery"` and are not usable for retrieval. Endpoint
verification is the subject of the source-discovery audit in
`dev/source-discovery/`.

## Examples

``` r
knbs_sources()
#> # A tibble: 8 × 8
#>   source_id         source_name  source_type operations stability authentication
#>   <chr>             <chr>        <chr>       <list>     <chr>     <chr>         
#> 1 kenada            Kenya Natio… survey_cat… <chr [4]>  experime… none          
#> 2 finaccess         FinAccess H… static_fil… <chr [1]>  experime… none          
#> 3 knbs_publications KNBS Public… publicatio… <chr [3]>  experime… none          
#> 4 knbs_indicators   KNBS Census… indicator_… <chr [4]>  experime… none          
#> 5 knbs_cpi          KNBS CPI Ex… indicator_… <chr [4]>  experime… none          
#> 6 knbs_opendata     KNBS Data P… indicator_… <chr [3]>  experime… none          
#> 7 opendataforafrica Kenya Open … indicator_… <chr [3]>  experime… none          
#> 8 fake_source       Offline tes… fake        <chr [6]>  discovery none          
#> # ℹ 2 more variables: last_verified <date>, base_url <chr>
knbs_sources(operation = "search_surveys")
#> # A tibble: 2 × 8
#>   source_id   source_name        source_type operations stability authentication
#>   <chr>       <chr>              <chr>       <list>     <chr>     <chr>         
#> 1 kenada      Kenya National Da… survey_cat… <chr [4]>  experime… none          
#> 2 fake_source Offline test sour… fake        <chr [6]>  discovery none          
#> # ℹ 2 more variables: last_verified <date>, base_url <chr>
```
