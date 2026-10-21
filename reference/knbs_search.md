# Search everything the package can retrieve

**\[experimental\]**

One search across the indicator catalogues of every verified source, the
survey catalogue of the Kenya National Data Archive, the open FinAccess
survey microdata, the publications in the KNBS website's media library,
and the curated Statistical Abstract tables. Results come back ranked,
in one schema, each with the exact call that retrieves it — so finding
something and getting it are one copy and paste apart.

## Usage

``` r
knbs_search(
  query,
  type = c("indicator", "table", "survey", "microdata", "publication"),
  limit = 50,
  cache = knbs_option("cache"),
  refresh = FALSE
)
```

## Arguments

- query:

  Words to search for.

- type:

  Which kinds of resource to search: any of `"indicator"`, `"table"`,
  `"survey"`, `"microdata"` and `"publication"`. All by default. A
  `"microdata"` result is one survey round whose data can be downloaded
  openly; its `get` call downloads and reads it.

- limit:

  Maximum number of results.

- cache:

  Whether to use the local cache.

- refresh:

  Whether to bypass any cached catalogue.

## Value

A `knbs_catalogue` tibble with one row per result: `resource_type`,
`resource_id`, `title`, `topic`, `period`, `release_date`, `access`,
`source_id`, `url`, and `get` — the R call that retrieves the resource.

## Details

Matching is done by the package, over each catalogue in full, so that it
means the same thing everywhere: every word of `query` must appear in a
result's title, id or topic. Words match by stem — "index" finds
"Indices", "prices" finds "Price" — and a word of four letters or more
also matches as the start of a longer one ("agric" finds "Agriculture").
A few acronyms common in Kenyan statistics are understood both ways:
CPI, GDP, GCP, GVA, PPI, BOP, KDHS, KIHBS and LEI. Common words such as
"of" and "the" are ignored.

Results are ranked in tiers: an exact id, then an exact title, then the
query as a phrase in the title ("consumer price index" is the phrase in
"Consumer Price Indices and Inflation Rates"), then every word somewhere
in the title, then a match elsewhere. Within a tier, data comes before
documents and newer releases before older ones.

Catalogues are cached for a day. The first search of the day lists the
whole publications library, around 16 requests at the site's polite
rate; later searches are instant. If a source cannot be reached its
results are missing and a warning names it; the error comes only when no
catalogue answers.

Geographic codes are not searched here; see
[`knbs_geographies()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_geographies.md).

## See also

[`knbs_indicators()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_indicators.md),
[`knbs_search_surveys()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_search_surveys.md),
[`knbs_finaccess_files()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_finaccess_files.md),
[`knbs_publications()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_publications.md),
[`knbs_abstract_tables()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_abstract_tables.md)

## Examples

``` r
# The microdata and table catalogues ship with the package: no request
knbs_search("financial inclusion", type = "microdata")
#> <knbs_catalogue>
#> Title: KNBS search results for "financial inclusion"
#> Rows: 8
#> Source: Kenya National Bureau of Statistics
#> 
#> # A tibble: 8 × 10
#>   resource_type resource_id title     topic period release_date access source_id
#>   <chr>         <chr>       <chr>     <chr> <chr>  <date>       <chr>  <chr>    
#> 1 microdata     hh2024      FinAcces… Fina… 2024   NA           open   finaccess
#> 2 microdata     hh2021      FinAcces… Fina… 2021   NA           open   finaccess
#> 3 microdata     hh2016      FinAcces… Fina… 2016   NA           open   finaccess
#> 4 microdata     hh2013      FinAcces… Fina… 2013   NA           open   finaccess
#> 5 microdata     hh2009      FinAcces… Fina… 2009   NA           open   finaccess
#> 6 microdata     hh2006      FinAcces… Fina… 2006   NA           open   finaccess
#> 7 microdata     mse2022     FinAcces… Fina… 2022   NA           open   finaccess
#> 8 microdata     mse2023     FinAcces… Fina… 2023   NA           open   finaccess
#> # ℹ 2 more variables: url <chr>, get <chr>
knbs_search("capital formation", type = "table")
#> <knbs_catalogue>
#> Title: KNBS search results for "capital formation"
#> Rows: 4
#> Source: Kenya National Bureau of Statistics
#> 
#> # A tibble: 4 × 10
#>   resource_type resource_id title     topic period release_date access source_id
#>   <chr>         <chr>       <chr>     <chr> <chr>  <date>       <chr>  <chr>    
#> 1 table         2.7b        Table 2.… Chap… 2015-… NA           open   knbs_pub…
#> 2 table         2.7d        Table 2.… Chap… 2015-… NA           open   knbs_pub…
#> 3 table         2.7a        Table 2.… Chap… 2015-… NA           open   knbs_pub…
#> 4 table         2.7c        Table 2.… Chap… 2015-… NA           open   knbs_pub…
#> # ℹ 2 more variables: url <chr>, get <chr>
if (FALSE) { # interactive()
knbs_search("consumer price index")
knbs_search("gdp", type = c("indicator", "table"))
hits <- knbs_search("county population")
hits$get[[1]] # the call that fetches the top result
}
```
