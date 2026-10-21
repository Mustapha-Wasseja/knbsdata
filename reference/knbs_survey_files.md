# List the data files belonging to a study

**\[experimental\]**

Reports what the archive holds and whether the package may retrieve it.
At present no supported source permits programmatic download of
microdata, so `downloadable` is `FALSE` throughout; use `catalogue_url`
from
[`knbs_search_surveys()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_search_surveys.md)
to reach the official access process.

## Usage

``` r
knbs_survey_files(
  survey,
  type = NULL,
  access = NULL,
  source = NULL,
  cache = knbs_option("cache"),
  refresh = FALSE
)
```

## Arguments

- survey:

  A study identifier, or enough of its title to identify it.

- type:

  Keep only files of this type.

- access:

  Keep only files with these access types.

- source:

  Source id.

- cache:

  Whether to use the local cache.

- refresh:

  Whether to bypass any cached response.

## Value

A tibble with columns `survey_id`, `file_id`, `file_name`, `file_type`,
`format`, `size`, `case_count`, `var_count`, `access_type`,
`downloadable`, `download_url`, `checksum` and `source_id`.

## Details

This lists data files only. Questionnaires, reports and technical
documents are out of scope: the archive publishes no machine-readable
listing of them, and retrieving them would mean parsing a web page. They
are linked from the study's page on the archive, which `catalogue_url`
points to.

## See also

[`knbs_variables()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_variables.md),
[`knbs_download_microdata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_microdata.md)

## Examples

``` r
if (FALSE) { # interactive()
knbs_survey_files("KEN-KNBS-KIHBS-2015-2016-v01")
}
```
