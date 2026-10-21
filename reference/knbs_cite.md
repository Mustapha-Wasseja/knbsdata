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
# Citations are produced from objects returned by knbsdata.
```
