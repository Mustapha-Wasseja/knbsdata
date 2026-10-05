# Set knbsdata options

Sets package options for the current session. Arguments left as `NULL`
are unchanged. Called with no arguments, returns the current values.

## Usage

``` r
knbs_options(
  cache = NULL,
  cache_dir = NULL,
  timeout = NULL,
  retries = NULL,
  user_agent = NULL,
  quiet = NULL
)
```

## Arguments

- cache:

  `TRUE` or `FALSE`. Whether retrieval functions may read from and write
  to the local cache.

- cache_dir:

  Path to the cache directory. `NULL` uses
  `tools::R_user_dir("knbsdata", "cache")`.

- timeout:

  Request timeout in seconds.

- retries:

  Maximum number of retries for retryable HTTP failures.

- user_agent:

  Override for the HTTP user agent string. `NULL` uses a transparent
  default identifying the package and version.

- quiet:

  `TRUE` or `FALSE`. Whether to suppress progress messages.

## Value

When setting, the previous values as a named list, invisibly. When
called with no arguments, the current values as a named list.

## Details

To restore an option to its default, use
[`options()`](https://rdrr.io/r/base/options.html) directly, for example
`options(knbsdata.cache_dir = NULL)`, or
[`withr::with_options()`](https://withr.r-lib.org/reference/with_options.html)
for a temporary change.

## See also

[`knbs_option()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_option.md)
to read a single option.

## Examples

``` r
old <- knbs_options(timeout = 60)
knbs_option("timeout")
#> [1] 60

# restore
knbs_options(timeout = old$timeout)
```
