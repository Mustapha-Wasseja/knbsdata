# Working with the survey catalogue

``` r

library(knbsdata)
```

This vignette covers finding a survey, reading its documentation and
understanding what you are and are not allowed to do with it.

Every code chunk that contacts the archive is shown but not run, so that
building this vignette never depends on a live service.

## What is supported

[`knbs_sources()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_sources.md)
reports what the package knows about each source and how far it has been
verified. Nothing here makes a request:

``` r

knbs_sources(operation = "search_surveys")
#> # A tibble: 2 × 8
#>   source_id   source_name        source_type operations stability authentication
#>   <chr>       <chr>              <chr>       <list>     <chr>     <chr>         
#> 1 kenada      Kenya National Da… survey_cat… <chr [4]>  experime… none          
#> 2 fake_source Offline test sour… fake        <chr [6]>  discovery none          
#> # ℹ 2 more variables: last_verified <date>, base_url <chr>
```

The survey catalogue is the Kenya National Data Archive, which exposes a
JSON API. It is registered as `experimental`: the endpoints are verified
and covered by tests, but the archive does not document the API, so it
could change without notice. If it does, the package raises a
`knbs_error_schema_changed` rather than returning something plausible.

## Finding a survey

``` r

studies <- knbs_search_surveys("household budget")
studies
```

You can filter by reference year, by producer and by access type:

``` r

knbs_search_surveys(year = c(2015, 2020))
knbs_search_surveys(access = "public_use", limit = 10)
```

Three columns come back as `NA` from a search: `acronym`,
`geographic_coverage` and `unit_of_analysis`. They live in the study
record rather than the catalogue index, and filling them in would mean
one extra request per row.
[`knbs_survey_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_survey_metadata.md)
retrieves them.

## Reading a study’s documentation

``` r

meta <- knbs_survey_metadata("KEN-KNBS-KIHBS-2015-2016-v01")
meta
```

The printed record shows the title, reference period, producer,
geographic coverage, unit of analysis and access type. The full
descriptive sections are in `meta$sections`; `include` narrows them:

``` r

knbs_survey_metadata("KEN-KNBS-KIHBS-2015-2016-v01", include = c("scope", "access"))
```

These records are DDI documents, in which sampling, data collection and
processing all live in a single `method` section, so asking for any one
of those returns that section.

You do not have to know the exact identifier. Give it something
recognisable and it will search the catalogue; if more than one study
matches you get an error listing the candidates rather than a silently
chosen “best” match.

## Searching variables

Variable metadata are available without downloading any microdata:

``` r

knbs_variables("KEN-KNBS-KIHBS-2015-2016-v01", search = "expenditure")
knbs_variables("KEN-KNBS-KIHBS-2015-2016-v01", file = "HH_Information")
```

`search` matches variable names and labels, and matches nothing else. If
a concept you expect is missing, it is worth listing all the variables
and looking at the labels the study actually uses before concluding the
search is broken.

Question text, universe, concept and value labels each cost one request
per variable, so they are empty unless you ask:

``` r

knbs_variables(
  "KEN-KNBS-KIHBS-2015-2016-v01",
  search = "county",
  details = TRUE
)
```

That is capped at 100 variables. Narrow the selection first rather than
raising the cap.

Some studies are catalogued with no variable documentation at all —
including, at the time of writing, the most recent one. That returns
zero rows, which is an answer rather than a failure.

## Files, and what you may do with them

``` r

knbs_survey_files("KEN-KNBS-KIHBS-2015-2016-v01")
```

Two columns matter most:

- `access_type` describes the archive’s terms. `public_use` means
  public-use files exist. It does **not** mean they can be downloaded
  without an account.
- `downloadable` describes what this package will do. At present it is
  `FALSE` for every file from every supported source.

This lists **data files only**. Questionnaires, reports and technical
documents are not covered: the archive publishes no machine-readable
listing of them, so retrieving them would mean parsing a web page, which
this package does not do. Use the `catalogue_url` column from
[`knbs_search_surveys()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_search_surveys.md)
to open the study on the archive’s own site, where the documentation is
linked.

## Downloading microdata

You cannot do this through `knbsdata`, and that is deliberate:

``` r

knbs_download_microdata("KEN-KNBS-KIHBS-2015-2016-v01")
#> Error: Microdata from "kenada" cannot be downloaded programmatically.
#> x Every download requires an account with the archive.
#> i Register and request access at <https://statistics.knbs.or.ke/nada/index.php/home>.
#> i knbsdata does not automate sign-in, licence acceptance or approval workflows.
```

The archive puts every download behind a login. The package does not
automate sign-in, licence acceptance or approval workflows, so the
function exists purely to fail clearly and point you at the official
process. Complete that process, download the files yourself, and read
them with `readr`, `haven` or whatever suits the format.

This matters for a subtler reason too. The gate is signalled by an HTTP
`Refresh` header rather than a redirect status, so a client that only
checks the status code sees `200 OK` and an empty body — and could
report “no data” where the honest answer is “you need an account”. The
package treats that as an authentication error.

## Handling errors

Every failure carries a specific condition class, so you can react to
the particular problem rather than matching on message text:

``` r

result <- tryCatch(
  knbs_survey_metadata("Kenya"),
  knbs_error_ambiguous_resource = function(cnd) {
    message("Several studies match; using the first.")
    knbs_survey_metadata(cnd$matches[[1]])
  },
  knbs_error_resource_not_found = function(cnd) NULL,
  knbs_error_source_unavailable = function(cnd) NULL
)
```

The classes you are most likely to want are
`knbs_error_ambiguous_resource` (which carries the candidates in
`$matches`), `knbs_error_resource_not_found`,
`knbs_error_authentication_required` (which carries `$access_url`),
`knbs_error_source_unavailable` and `knbs_error_schema_changed`. All of
them inherit from `knbs_error`, so you can catch that instead to handle
any package failure at once.

One practical note: catch `error`, not `condition`. httr2 signals a
benign `httr2_perform` condition on every request, so a
`tryCatch(..., condition = )` handler will catch that first and never
see your error.

## Citing what you used

``` r

knbs_cite(meta)
```

Where the archive states a required citation, that text is used and the
package adds the retrieval date and its own version.
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
shows the full provenance record behind any object.

## Caching

Catalogue responses are cached for 24 hours by default:

``` r

knbs_cache_info()
knbs_search_surveys("household budget", refresh = TRUE)  # bypass the cache
knbs_cache_clear()
```

Cache entries are checksummed and keyed partly on the package’s parser
version, so upgrading the package invalidates anything a new parser
would read differently.
