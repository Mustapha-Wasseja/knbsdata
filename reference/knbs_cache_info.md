# What is in the cache

What is in the cache

## Usage

``` r
knbs_cache_info()
```

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
row per cached entry: `cache_key`, `source_id`, `operation`,
`resource_id`, `retrieved_at`, `expires_at`, `expired` and `size_bytes`.
Zero rows if nothing is cached.

## See also

[`knbs_cache_dir()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cache_dir.md),
[`knbs_cache_clear()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cache_clear.md)

## Examples

``` r
knbs_cache_info()
#> # A tibble: 0 × 8
#> # ℹ 8 variables: cache_key <chr>, source_id <chr>, operation <chr>,
#> #   resource_id <chr>, retrieved_at <chr>, expires_at <chr>, expired <lgl>,
#> #   size_bytes <dbl>
```
