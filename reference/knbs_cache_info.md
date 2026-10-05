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
#> # A tibble: 60 × 8
#>    cache_key     source_id operation resource_id retrieved_at expires_at expired
#>    <chr>         <chr>     <chr>     <chr>       <chr>        <chr>      <lgl>  
#>  1 123a30f800c6… knbs_ope… get_indi… DF_NAT_GDP… 2026-10-05T… 2026-10-1… FALSE  
#>  2 123becb6755c… knbs_cpi  list_ind… NA          2026-10-05T… 2026-10-0… FALSE  
#>  3 144aaeaff2da… knbs_ope… hub_cata… NA          2026-10-05T… 2026-10-0… FALSE  
#>  4 15aaeabc8d44… knbs_ind… list_ind… NA          2026-10-05T… 2026-10-0… FALSE  
#>  5 186bee5917ae… knbs_pub… abstract… 2.2         2026-10-05T… 2026-10-0… FALSE  
#>  6 2007bc8f7c05… knbs_pub… abstract… 2.6d        2026-10-05T… 2026-10-0… FALSE  
#>  7 293b454db529… knbs_pub… abstract… 2.3         2026-10-05T… 2026-10-0… FALSE  
#>  8 295dd9b82791… kenada    search_s… NA          2026-10-05T… 2026-10-0… FALSE  
#>  9 2e636c3bd856… knbs_cpi  list_ind… NA          2026-10-05T… 2026-10-0… FALSE  
#> 10 37c12530feac… knbs_ope… list_ind… NA          2026-10-05T… 2026-10-0… FALSE  
#> # ℹ 50 more rows
#> # ℹ 1 more variable: size_bytes <dbl>
```
