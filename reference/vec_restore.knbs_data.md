# Restore metadata after vctrs operations

Most dplyr verbs round-trip through vctrs, so re-attaching the metadata
here keeps provenance through
[`filter()`](https://rdrr.io/r/stats/filter.html), `arrange()`,
`slice()` and friends.

## Usage

``` r
# S3 method for class 'knbs_data'
vec_restore(x, to, ...)
```

## Arguments

- x:

  The bare data being restored.

- to:

  The object whose class and attributes should be restored.

- ...:

  Passed to methods.

## Value

An object of the same class as `to`.

## Details

This is deliberately not a guarantee. An operation that combines two
objects, or aggregates rows, produces something whose official identity
is no longer the same as the original, and pretending otherwise would be
worse than losing the attribute (plan section 10.3).
