# Retrieve the full metadata record for a study

**\[experimental\]**

Retrieves the archive's full descriptive record for one study.

## Usage

``` r
knbs_survey_metadata(
  survey,
  include = c("overview", "scope", "sampling", "collection", "processing", "access",
    "citation"),
  source = NULL,
  cache = knbs_option("cache"),
  refresh = FALSE
)
```

## Arguments

- survey:

  A study identifier, or enough of its title to identify it
  unambiguously.

- include:

  Which descriptive sections to keep. The underlying records are DDI
  documents, in which sampling, collection and processing all live in
  one `method` section, so asking for any of them returns that section.

- source:

  Source id.

- cache:

  Whether to use the local cache.

- refresh:

  Whether to bypass any cached response.

## Value

A `knbs_survey` metadata object. Use
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
to inspect it and
[`knbs_cite()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cite.md)
to cite it.

## See also

[`knbs_search_surveys()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_search_surveys.md),
[`knbs_variables()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_variables.md),
[`knbs_survey_files()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_survey_files.md)

## Examples

``` r
if (FALSE) { # \dontrun{
meta <- knbs_survey_metadata("KEN-KNBS-KIHBS-2015-2016-v01")
knbs_cite(meta)
} # }
```
