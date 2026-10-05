# Get a knbsdata option

Retrieves a single package option. Options are stored as ordinary R
options prefixed with `knbsdata.`, so `knbs_option("timeout")` reads
`getOption("knbsdata.timeout")` and falls back to the package default.

## Usage

``` r
knbs_option(name)
```

## Arguments

- name:

  Option name, without the `knbsdata.` prefix. One of `"cache"`,
  `"cache_dir"`, `"timeout"`, `"retries"`, `"user_agent"` or `"quiet"`.

## Value

The option value. `NULL` for options that are unset and have no default
(`cache_dir`, `user_agent`).

## See also

[`knbs_options()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_options.md)
to set options.

## Examples

``` r
knbs_option("timeout")
#> [1] 30
knbs_option("cache")
#> [1] TRUE
```
