# Empty the cache

Empty the cache

## Usage

``` r
knbs_cache_clear(quiet = knbs_option("quiet"))
```

## Arguments

- quiet:

  Suppress the summary message.

## Value

The number of entries removed, invisibly.

## See also

[`knbs_cache_prune()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cache_prune.md)
to remove only expired entries.

## Examples

``` r
if (FALSE) { # \dontrun{
knbs_cache_clear()
} # }
```
