# Search the variables described by a study

**\[experimental\]**

Returns variable metadata only. No microdata are downloaded, and none
can be: the package does not fetch gated files.

## Usage

``` r
knbs_variables(
  survey,
  search = NULL,
  file = NULL,
  name = NULL,
  concept = NULL,
  limit = Inf,
  details = FALSE,
  source = NULL,
  cache = knbs_option("cache"),
  refresh = FALSE
)
```

## Arguments

- survey:

  A study identifier, or enough of its title to identify it.

- search:

  Free text matched against variable names and labels.

- file:

  Keep only variables from this file, by file id or file name.

- name:

  Exact variable name.

- concept:

  Keep only variables with this concept. Requires `details = TRUE`,
  since concepts are only in the per-variable records.

- limit:

  Maximum number of variables to return.

- details:

  Whether to retrieve the full record for each variable. This costs one
  request per variable, so it is capped at 100 rows.

- source:

  Source id.

- cache:

  Whether to use the local cache.

- refresh:

  Whether to bypass any cached response.

## Value

A tibble of variable metadata. A study catalogued without variable
documentation returns zero rows, which is a normal answer rather than an
error.

## Details

Question text, universe, concept and value labels each require one
request per variable, so they are `NA` unless `details = TRUE`.

## See also

[`knbs_survey_files()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_survey_files.md),
[`knbs_survey_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_survey_metadata.md)

## Examples

``` r
if (FALSE) { # interactive()
knbs_variables("KEN-KNBS-KIHBS-2015-2016-v01", search = "consumption")
}
```
