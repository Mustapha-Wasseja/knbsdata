# Cite a knbsdata object

Builds a citation from the object's provenance metadata. Where the
source supplies its own required citation, that text is used and the
package adds only the retrieval information.

## Usage

``` r
knbs_cite(
  x,
  style = c("plain", "bibtex", "ris"),
  include_retrieval_date = TRUE,
  ...
)
```

## Arguments

- x:

  A knbsdata object or a `knbs_metadata` object.

- style:

  `"plain"`, `"bibtex"` or `"ris"`.

- include_retrieval_date:

  Whether to record when the data were retrieved. Retrieval date matters
  for reproducibility whenever a `"latest"` release was requested.

- ...:

  Passed to methods.

## Value

A `knbs_citation` object; print it, or use
[`format()`](https://rdrr.io/r/base/format.html) to get a string.

## See also

[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)

## Examples

``` r
# Any object knbsdata returns can be cited; this catalogue ships with it.
files <- knbs_finaccess_files(year = 2024, content = "data")
knbs_cite(files)
#> Central Bank of Kenya, Kenya National Bureau of Statistics and FSD Kenya. FinAccess survey files. Available at https://finaccess.knbs.or.ke/reports-and-datasets. Retrieved 21 October 2026 using knbsdata version 0.5.0.
knbs_cite(files, style = "bibtex")
#> @misc{FinAccesssurveyfiles,
#>   title = {FinAccess survey files},
#>   author = {{Central Bank of Kenya, Kenya National Bureau of Statistics and FSD Kenya}},
#>   year = {2026},
#>   url = {https://finaccess.knbs.or.ke/reports-and-datasets},
#>   urldate = {2026-10-21},
#> }
```
