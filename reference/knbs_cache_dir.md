# Where knbsdata stores cached responses

The cache lives in
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html) unless the
`knbsdata.cache_dir` option points elsewhere. Nothing is written until
something is cached.

## Usage

``` r
knbs_cache_dir(create = FALSE)
```

## Arguments

- create:

  Whether to create the directory if it does not exist.

## Value

The cache directory path, invisibly when `create = TRUE`.

## See also

[`knbs_cache_info()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cache_info.md),
[`knbs_cache_clear()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cache_clear.md),
[`knbs_cache_prune()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cache_prune.md)

## Examples

``` r
knbs_cache_dir(create = FALSE)
#> [1] "/home/runner/.cache/R/knbsdata"
```
