# Search everything the package can retrieve

**\[experimental\]**

One search across the indicator catalogues of every verified source, the
survey catalogue of the Kenya National Data Archive, the publications in
the KNBS website's media library, and the curated Statistical Abstract
tables. Results come back ranked, in one schema, each with the exact
call that retrieves it — so finding something and getting it are one
copy and paste apart.

## Usage

``` r
knbs_search(
  query,
  type = c("indicator", "table", "survey", "publication"),
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
  `"survey"` and `"publication"`. All by default.

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
[`knbs_publications()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_publications.md),
[`knbs_abstract_tables()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_abstract_tables.md)

## Examples

``` r
if (FALSE) { # \dontrun{
knbs_search("consumer price index")
knbs_search("gdp", type = c("indicator", "table"))
hits <- knbs_search("county population")
hits$get[[1]] # the call that fetches the top result
} # }
```
