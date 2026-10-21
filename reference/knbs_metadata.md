# Inspect the provenance of a knbsdata object

Returns the metadata attached to an object: where it came from, when it
was retrieved, which release it represents and how it should be cited.

## Usage

``` r
knbs_metadata(x, ...)
```

## Arguments

- x:

  A knbsdata object.

- ...:

  Passed to methods.

## Value

A `knbs_metadata` object.

## See also

[`knbs_cite()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cite.md)

## Examples

``` r
# Metadata accompany every object the package returns.
meta <- knbs_metadata(knbs_finaccess_files())
meta$producer
#> [1] "Central Bank of Kenya, Kenya National Bureau of Statistics and FSD Kenya"
meta$licence
#> [1] "Not stated by the source"
```
