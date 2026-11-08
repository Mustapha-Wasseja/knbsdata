# Report on the health of supported sources

Answers two different questions depending on `live`. With `live = FALSE`
it reports what the package knows about each source without contacting
anything. With `live = TRUE` it asks each verified source to answer a
small request and reports what happened.

## Usage

``` r
knbs_status(source = NULL, live = interactive(), timeout = 10)
```

## Arguments

- source:

  Source ids to check. Defaults to every registered source.

- live:

  Whether to contact the sources. Defaults to
  [`interactive()`](https://rdrr.io/r/base/interactive.html), so that
  automated runs never depend on a live service.

- timeout:

  Request timeout in seconds, applied only to this call.

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
row per source and columns `source_id`, `operation`, `status`,
`http_status`, `response_time_ms`, `checked_at` and `message`.

## Details

A source that does not answer a catalogue search across every source
([`knbs_indicators()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_indicators.md),
[`knbs_search()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_search.md))
is skipped by the later ones in the same session, so that it is not
asked, and warned about, every time. A live check asks it again, and a
source that answers is searched again.

The `status` column is one of:

- `ok`:

  The source answered.

- `unavailable`:

  The source was contacted and did not answer usefully. The `message`
  column says why. With `live = FALSE`, a source that did not answer
  earlier in the session is reported this way, with the time and the
  reason.

- `unverified`:

  The source's endpoint has not been verified, so there is nothing to
  contact. It is never checked live.

- `not_checked`:

  The source could have been checked, but `live` was `FALSE`.

## See also

[`knbs_sources()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_sources.md)
for what each source supports.

## Examples

``` r
# Offline: reports what the registry knows, contacts nothing.
knbs_status(live = FALSE)
#> # A tibble: 9 × 7
#>   source_id    operation status http_status response_time_ms checked_at         
#>   <chr>        <chr>     <chr>        <int>            <dbl> <dttm>             
#> 1 kenada       search_s… not_c…          NA               NA 2026-11-08 18:24:22
#> 2 finaccess    download… not_c…          NA               NA 2026-11-08 18:24:22
#> 3 knbs_public… search_p… not_c…          NA               NA 2026-11-08 18:24:22
#> 4 knbs_indica… list_ind… not_c…          NA               NA 2026-11-08 18:24:22
#> 5 knbs_cpi     list_ind… not_c…          NA               NA 2026-11-08 18:24:22
#> 6 knbs_openda… list_ind… not_c…          NA               NA 2026-11-08 18:24:22
#> 7 opendatafor… list_ind… not_c…          NA               NA 2026-11-08 18:24:22
#> 8 dhs_program  list_ind… not_c…          NA               NA 2026-11-08 18:24:22
#> 9 fake_source  search_s… unver…          NA               NA 2026-11-08 18:24:22
#> # ℹ 1 more variable: message <chr>
if (FALSE) { # interactive()
# Contacts each verified source.
knbs_status(live = TRUE)
}
```
