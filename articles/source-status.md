# Source status and limitations

``` r

library(knbsdata)
```

This page states plainly what this release can and cannot do, and why.
It is worth reading before relying on the package for anything that
matters.

## Registered sources

``` r

knbs_sources()
#> # A tibble: 9 × 8
#>   source_id         source_name  source_type operations stability authentication
#>   <chr>             <chr>        <chr>       <list>     <chr>     <chr>         
#> 1 kenada            Kenya Natio… survey_cat… <chr [4]>  experime… none          
#> 2 finaccess         FinAccess H… static_fil… <chr [1]>  experime… none          
#> 3 knbs_publications KNBS Public… publicatio… <chr [3]>  experime… none          
#> 4 knbs_indicators   KNBS Census… indicator_… <chr [4]>  experime… none          
#> 5 knbs_cpi          KNBS CPI Ex… indicator_… <chr [4]>  experime… none          
#> 6 knbs_opendata     KNBS Data P… indicator_… <chr [3]>  experime… none          
#> 7 opendataforafrica Kenya Open … indicator_… <chr [3]>  experime… none          
#> 8 dhs_program       The DHS Pro… indicator_… <chr [3]>  experime… none          
#> 9 fake_source       Offline tes… fake        <chr [6]>  discovery none          
#> # ℹ 2 more variables: last_verified <date>, base_url <chr>
```

``` r

knbs_status()
#> # A tibble: 9 × 7
#>   source_id    operation status http_status response_time_ms checked_at         
#>   <chr>        <chr>     <chr>        <int>            <dbl> <dttm>             
#> 1 kenada       search_s… not_c…          NA               NA 2026-10-21 18:30:33
#> 2 finaccess    download… not_c…          NA               NA 2026-10-21 18:30:33
#> 3 knbs_public… search_p… not_c…          NA               NA 2026-10-21 18:30:33
#> 4 knbs_indica… list_ind… not_c…          NA               NA 2026-10-21 18:30:33
#> 5 knbs_cpi     list_ind… not_c…          NA               NA 2026-10-21 18:30:33
#> 6 knbs_openda… list_ind… not_c…          NA               NA 2026-10-21 18:30:33
#> 7 opendatafor… list_ind… not_c…          NA               NA 2026-10-21 18:30:33
#> 8 dhs_program  list_ind… not_c…          NA               NA 2026-10-21 18:30:33
#> 9 fake_source  search_s… unver…          NA               NA 2026-10-21 18:30:33
#> # ℹ 1 more variable: message <chr>
```

`knbs_status(live = TRUE)` contacts the verified sources. It never
contacts a source at stability `discovery`, because those have
placeholder endpoints and there is nothing to call.

## What each stability level means

| Level | Meaning |
|----|----|
| `discovery` | The endpoint has not been verified. Unusable, and never contacted. |
| `experimental` | Verified and tested, but not documented by its publisher, so it could change without notice. |
| `beta` | Verified, documented and monitored over time. |
| `stable` | A schema contract the package expects to keep. |
| `deprecated` | Scheduled for removal. |

Nothing in this release is above `experimental`.

## What works

**The survey catalogue**, via the Kenya National Data Archive:
[`knbs_search_surveys()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_search_surveys.md),
[`knbs_survey_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_survey_metadata.md),
[`knbs_variables()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_variables.md)
and
[`knbs_survey_files()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_survey_files.md).
The archive exposes a JSON API that needs no credentials for metadata.
129 studies covering 1969–2022 were catalogued at the time of the audit.

**Open survey microdata**, via the FinAccess portal
(`finaccess.knbs.or.ke`):
[`knbs_finaccess_files()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_finaccess_files.md),
[`knbs_download_finaccess()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_finaccess.md)
and
[`knbs_read_microdata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_read_microdata.md).
The Central Bank of Kenya, KNBS and FSD Kenya publish the anonymised,
weighted microdata of the FinAccess household surveys — 2006, 2009,
2013, 2016, 2021 and 2024 — and of two MSE Tracker Survey waves for
anyone to download, with questionnaires, manuals and reports. The portal
is a web page linking Google Drive files, so the package keeps its own
catalogue of them, and holds every download to it: served name and size
before the transfer, size and SHA-256 after. Three properties to keep in
mind:

- **The portal states no licence.** FSD Kenya’s terms for the 2013
  survey restrict the data to research and forbid redistribution without
  written agreement; assume nothing wider. The terms travel in each
  file’s sidecar and metadata, and no file is bundled with the package.
- **Some portal labels are wrong**, and the catalogue records what each
  link actually serves: the MSE Tracker Wave II formats are swapped, and
  the 2006 and 2009 “Questionnaire” archives hold the survey data too.
- **The 2013 survey’s Stata copy sits behind a registration form** on
  Harvard Dataverse. It is listed, never fetched; its SPSS copy is open.

**Publications**, via the KNBS website’s media library:
[`knbs_publications()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_publications.md)
and
[`knbs_download_publication()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_publication.md).
The site’s WordPress REST API lists roughly 1,600 documents —
statistical releases, survey reports, Economic Survey chapters and
workbooks — with direct, ungated file URLs. Downloads are verified,
checksummed and given a provenance sidecar.

Two properties of this source to keep in mind:

- `release_date` is the date a file reached the website, not the
  publication’s reference period. The `year` column is read from the
  title, and is `NA` when the title names none.
- The media library also holds speeches, launch remarks and forms. What
  counts as a publication is your `query`, not a curated list.

**Census tables**, via the KNBS census data service (`data.knbs.or.ke`):
[`knbs_indicators()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_indicators.md)
and
[`knbs_get_indicator()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_get_indicator.md).
Thirty-two tables from the 2019 Population and Housing Census as
JSON-stat, under an explicit CC BY 4.0 statement, with geography down to
sub-county and leading zeros intact. See
[`vignette("census-indicators")`](https://Mustapha-Wasseja.github.io/knbsdata/articles/census-indicators.md).

One property of this source to keep in mind: **its API host is
HTTP-only** — no TLS listener exists — so traffic to it is unencrypted
in transit. It carries public census aggregates and no credentials, and
the registry records the exception explicitly rather than hiding it.

**The economy**, via the KNBS Data Portal (`opendata.knbs.or.ke`): 323
SDMX dataflows across five statistical domains — GDP by activity and
expenditure, GFCF, GNI, production accounts, CPI by division and region,
balance of payments, trade, money and banking, county government
finance, employment, agriculture, tourism, health and justice.
[`knbs_indicators()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_indicators.md)
lists them (`source_id` `"knbs_opendata"`) and
[`knbs_get_indicator()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_get_indicator.md)
fetches one by its SDMX id, for example `"DF_NAT_GDPCP"`. Three
properties to keep in mind: the portal states **no licence**; its
geography codes are **SDMX area codes, not census territories** (never
join them against
[`knbs_geographies()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_geographies.md));
and single-category dimensions fold into
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
notes rather than arriving as constant columns.

**Consumer prices**, via the KNBS CPI Explorer
(`cpiexplorer.knbs.or.ke`): `knbs_get_indicator("CPI_ALL_ITEMS")`,
`"CPI_INFLATION_YOY"` and `"CPI_INFLATION_MOM"` — monthly from January
2009, nationally and by the CPI collection strata (the Nairobi income
bands, Nairobi Combined, Rest of Urban) — plus
[`knbs_retail_prices()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_retail_prices.md),
the monthly national average retail prices of the 22 CPI basket
commodities. See
[`vignette("census-indicators")`](https://Mustapha-Wasseja.github.io/knbsdata/articles/census-indicators.md).

Three properties of this source to keep in mind, all carried in
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
on every result:

- **The portal states no licence**, unlike the census service’s CC BY
  4.0 footer, and does not state the index base period.
- **Its regions are collection strata, not census territories.** Their
  codes must never be joined against
  [`knbs_geographies()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_geographies.md).
- **Six listed regions — the former provinces — carry no data in any
  period.** Asking for them returns zero rows, because that is the
  source’s answer.

**Gross County Product and the republished datasets**, via Kenya Open
Data for Africa (`kenya.opendataforafrica.org`): 202 datasets — 169
sourced from KNBS, the rest from the Central Bank of Kenya, ministries
and agencies — including the one thing no first-party portal serves as
data: Gross County Product (`knbs_get_indicator("jhbzkjc")` — GVA shares
plus constant- and current-price GCP for all 47 counties, 2013–2020).
[`knbs_indicators()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_indicators.md)
lists them (`source_id` `"opendataforafrica"`).

This source is different in kind from the others, and its honesty
caveats are correspondingly heavier:

- **It is a republisher, not the publisher.** The portal is operated on
  the Knoema data platform and is listed on KNBS’s own portals page;
  every result’s
  [`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
  names the portal and points at the original producer. Where a
  first-party portal serves the same data, prefer the first-party
  portal.
- **Its vintage can lag the PDFs.** The GCP dataset is the 2021 edition;
  KNBS has since published newer GCP years as PDF reports only. The
  metadata carries the portal’s own publication and update dates so the
  lag is visible, not hidden.
- **Licence labels vary by dataset** and are carried verbatim — most
  KNBS-sourced datasets say “Public Domain”; datasets without a label
  say “Not stated by the source”.
- **Its geography codes are the portal’s own region codes** (`KE`,
  `KE-700-BA`, …), not census territories; never join them against
  [`knbs_geographies()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_geographies.md).
- **A dataset may mix frequencies** — annual, quarterly and monthly
  series side by side under one id. Annual periods are integer years and
  sub-annual ones are Dates, which cannot share a column, so a mixed
  dataset asks you to choose (`frequency = "annual"`) rather than
  picking one silently.
- **Its edge sometimes challenges automated clients.** The package
  identifies itself transparently and speaks plain HTTP/1.1, which the
  portal serves; if a challenge page comes back anyway, that is an
  access gate and you get `knbs_error_access_restricted` — the package
  never solves or retries a challenge. Trying again later usually
  suffices.

**Health and demography**, via the DHS Program’s Indicator Data API
(`api.dhsprogram.com`): the indicators of the Kenya Demographic and
Health Surveys (1989–2022), which KNBS implements, and of the 2015 and
2020 Malaria Indicator Surveys — 4,115 of them, listed by
[`knbs_indicators()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_indicators.md)
with `source_id` `"dhs_program"` and fetched by id, for example
`knbs_get_indicator("CN_NUTS_C_HA2")` (children stunted). Each comes for
every survey that measured it, by background characteristic, by the
former provinces, and from 2014 by county. KNBS’s own KDHS portal is a
dashboard with no data API, and answered with an error when checked.
Properties to keep in mind:

- **County rows carry census codes**; province and malaria-zone rows
  carry none, since no census code exists for them.
- **Several values can describe one group.** Where the DHS Program
  reports more than one reference period, every value is kept and
  `preferred` marks the one it prefers.
- **A few ids are reused.** The API lists 27 indicator ids twice; where
  one serves two different values for the same survey and group, the
  package refuses it with `knbs_error_validation_failed` rather than
  choose.
- **The terms ask for a citation**, which
  [`knbs_cite()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cite.md)
  gives in the form the API specifies. No licence is stated.
- **Its robots file bars `/rest/dhs/`**, the API itself, to every
  client, while its documentation invites applications to use it. The
  package reads the rule as addressed to crawlers: it asks only for what
  you request, one indicator at a time, under its own name, throttled
  and cached, and never walks the API.

**Statistical Abstract tables**, via the KNBS website’s chapter
workbooks:
[`knbs_abstract_tables()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_abstract_tables.md)
and
[`knbs_abstract_table()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_abstract_table.md).
48 tables of the 2025 edition, across 13 chapters — the whole National
Accounts chapter and 33 tables from twelve more — extract into tidy
observations by hand-verified recipes. Extraction is deliberately
strict: layout anchors, section labels and pinned reference values are
re-checked on every read, and a workbook that has drifted is refused
with a classed error rather than re-interpreted. Tables not yet curated
remain verified *downloads*
([`knbs_download_publication()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_publication.md)).
See
[`vignette("statistical-abstract")`](https://Mustapha-Wasseja.github.io/knbsdata/articles/statistical-abstract.md).

## What does not, and why

### The archive’s microdata cannot be downloaded

The archive requires an account for every download.
[`knbs_download_microdata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_microdata.md)
explains the official access process and stops. The package does not
automate sign-in, licence acceptance or approval workflows. Microdata
are downloaded only where the producers publish them for anyone, as the
FinAccess surveys are.

This is worth understanding rather than working around: `access_type` of
`public_use` describes the archive’s *terms* — public-use files exist —
not whether a program may fetch them.

### Documentation files are not listed

Questionnaires, reports and technical documents have no machine-readable
listing at the archive. Reaching them would mean parsing a web page,
which this package does not do. The `catalogue_url` column from
[`knbs_search_surveys()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_search_surveys.md)
opens the study on the archive’s own site, where they are linked.

### The newest Gross County Product years are still documents

GCP is data now — but only the 2021 edition (2013–2020), through the
Open Data for Africa republisher above; no first-party KNBS portal
serves it as data (checked exhaustively). The editions published since
extend the series past 2020 as PDF reports only, reachable through
`knbs_publications("gross county product")`. If the newest county
figures matter, read the PDF; the metadata on the data version dates its
vintage precisely so the gap is never invisible.

### Geography: one vintage, no boundaries, no classifications

[`knbs_geographies()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_geographies.md)
serves the 2019 census frame — Kenya, 47 counties, sub-counties, with
names and parent codes, read from the census service’s own Territory
dimension. What it does not serve, because nothing has been verified:
other vintages, crosswalks between coding systems, boundary geometries
(`knbs_boundaries()` does not exist) and statistical classifications.

### Variable documentation is uneven

Some studies are catalogued with no variable metadata at all, including
the most recent one at the time of the audit.
[`knbs_variables()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_variables.md)
returns zero rows for those. That is the archive’s answer, not a
failure.

## How you will know if something changes

The package checks the *shape* of every response, not just its status
code. The archive answers unknown paths with `200` and a study record
rather than a 404, so a renamed endpoint would otherwise deliver the
wrong object convincingly. When a payload lacks the fields its operation
requires, you get `knbs_error_schema_changed` and a note that the
endpoint has probably moved.

A scheduled job runs `knbs_status(live = TRUE)` weekly against the
verified sources.

## Reporting a change

If a source has moved, changed shape or changed its access rules, please
open a [data source change
issue](https://github.com/Mustapha-Wasseja/knbsdata/issues/new/choose).
Public URLs only — never session-bound URLs, tokens or cookies.

## Disclaimer

`knbsdata` is an independent open-source project. It is not an official
KNBS product unless and until KNBS formally adopts or endorses it.
Consult the original KNBS source for authoritative definitions,
revisions, access conditions and official releases.
