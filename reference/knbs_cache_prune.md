# Remove expired cache entries

Remove expired cache entries

## Usage

``` r
knbs_cache_prune(quiet = knbs_option("quiet"))
```

## Arguments

- quiet:

  Suppress the summary message.

## Value

The number of entries removed, invisibly.

## See also

[`knbs_cache_clear()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cache_clear.md)
to remove everything.

## Examples

``` r
if (FALSE) { # \dontrun{
knbs_cache_prune()
} # }
```
