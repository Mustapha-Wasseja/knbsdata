# What KNBS has released lately

**\[experimental\]**

Lists the documents KNBS has added to its website, newest first, with
each one's release series where it belongs to one — the monthly CPI and
inflation release, Leading Economic Indicators, the quarterly GDP and
balance of payments reports, the Economic Survey and the rest — and the
call that downloads it. Tenders, job adverts and other notices are left
out unless asked for.

    knbs_releases()                    # the last 30 days
    knbs_releases(series = "cpi")      # every CPI release, latest first
    knbs_releases(series = "cpi")[1, ] # has this month's come out?

## Usage

``` r
knbs_releases(
  since = NULL,
  until = NULL,
  series = NULL,
  notices = FALSE,
  cache = knbs_option("cache"),
  refresh = FALSE
)
```

## Arguments

- since, until:

  Keep releases on or after `since` and on or before `until`: dates, or
  `"YYYY-MM-DD"` strings. By default the last 30 days, or, when `series`
  is given, the series' whole history in the library.

- series:

  Keep only these series: ids or names from
  [`knbs_release_series()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_release_series.md),
  matched without regard to case (`"cpi"`, `"lei"`,
  `"Economic Survey"`).

- notices:

  Whether to include tenders, adverts and other notices.

- cache:

  Whether to use the local cache.

- refresh:

  Whether to re-list the library.

## Value

A `knbs_catalogue` tibble: `release_date`, `series`, `period`, `title`,
`format`, `publication_id`, `landing_page`, and `get` — the call that
downloads the document.

## Details

The date is the day the document was uploaded to the website, which is
the day it was released for regular publications. It is not the period
covered, and older releases were uploaded in bulk when the library was
set up in mid-2023. `period` gives the month (`"2026-09"`) or quarter
(`"2026-Q2"`) a title names, and is `NA` where the title names neither.

A document's series is read from its title by a curated list of KNBS's
regular releases, see
[`knbs_release_series()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_release_series.md);
titles vary ("Kenya Residential Proprety Price Index", "Leading Economic
Indicators- March 2026"), so the patterns allow for that. A document
matching no series has `series` `NA`. Notices are titles naming a
tender, procurement, framework agreement, advert, vacancy or employment
form.

The publications library is listed once a day and cached, as for
[`knbs_search()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_search.md).

## See also

[`knbs_release_series()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_release_series.md),
[`knbs_publications()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_publications.md),
[`knbs_search()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_search.md)

## Examples

``` r
if (FALSE) { # \dontrun{
knbs_releases(since = "2026-09-01")
knbs_releases(series = c("cpi", "lei"), since = "2026-01-01")
} # }
```
