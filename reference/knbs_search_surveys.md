# Search official survey and census studies

**\[experimental\]**

Searches the study catalogue of a supported survey archive and returns
one row per study.

## Usage

``` r
knbs_search_surveys(
  query = NULL,
  year = NULL,
  producer = NULL,
  access = NULL,
  limit = 100,
  source = NULL,
  cache = knbs_option("cache"),
  refresh = FALSE
)
```

## Arguments

- query:

  Free-text search. `NULL` returns the whole catalogue.

- year:

  A single year, or `c(from, to)` for a range. Matched against the
  study's reference years.

- producer:

  Keep only studies whose producing entity contains this text.

- access:

  Keep only these access types; see the `access_type` column.

- limit:

  Maximum number of studies to return.

- source:

  Source id. Defaults to the first verified source that supports survey
  search.

- cache:

  Whether to use the local cache.

- refresh:

  Whether to bypass any cached response.

## Value

A `knbs_catalogue` tibble with columns `survey_id`, `title`, `acronym`,
`reference_years`, `country`, `producer`, `geographic_coverage`,
`unit_of_analysis`, `access_type`, `catalogue_url`, `metadata_updated`
and `source_id`.

## Details

Some catalogue fields — `acronym`, `geographic_coverage` and
`unit_of_analysis` — are not carried in search results and come back as
`NA`. They are held in the study record, which
[`knbs_survey_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_survey_metadata.md)
retrieves. Filling them here would mean one extra request per row.

## See also

[`knbs_survey_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_survey_metadata.md),
[`knbs_variables()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_variables.md),
[`knbs_survey_files()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_survey_files.md)

## Examples

``` r
if (FALSE) { # \dontrun{
knbs_search_surveys("household budget")
knbs_search_surveys(year = c(2015, 2020), access = "public_use")
} # }
```
