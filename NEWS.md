# knbsdata (development version)

## Health and demography from the KDHS

KNBS implements the Kenya Demographic and Health Surveys, and the DHS
Program publishes their indicators through its Indicator Data API, now a
source (`"dhs_program"`): 4,115 indicators from the KDHS of 1989 to 2022
and the 2015 and 2020 Malaria Indicator Surveys, through the same
`knbs_indicators()` and `knbs_get_indicator()` as every other source.

* Each indicator comes for every survey that measured it, by background
  characteristic (residence, wealth, education and others), by the former
  provinces, and from 2014 for the 47 counties, with 2019 census county
  codes so they join the census tables:
  `knbs_get_indicator("CN_NUTS_C_HA2", geo_level = "county")`.
* Where the DHS Program gives values for several reference periods, all are
  kept and `preferred` marks its choice. An id the API reuses for two
  indicators, serving two values for one survey and group, is refused
  rather than guessed at (audit F-42).
* `knbs_cite()` gives the citation the API's terms ask for, and no longer
  repeats a URL that a source's own citation already names.
* `knbs_search()` finds them. Search now reads -ing and -ed as endings, so
  "stunting" matches "Children stunted", and "KDHS" finds the survey's
  indicators. Scoring is vectorised, stemming each distinct word once, so
  ranking the 6,000-odd rows it now searches takes about a second rather
  than eight.
* `knbs_county_code()` falls back on the 47 counties' statutory codes, the
  census frame's own and held identical by the tests, when the census
  service cannot be reached.
* The API's robots file bars its own `/rest/dhs/` path to every client,
  while its documentation invites applications to use it. The package reads
  the rule as one for crawlers: it requests only what is asked for, one
  indicator at a time, under its own name, throttled and cached. The README's
  access conditions now say how robots rules are read, and the audit records
  the reasoning.
* The test suite now fails any test that would reach the network.

## Open survey microdata: FinAccess

The FinAccess household survey, Kenya's survey of financial inclusion by the
Central Bank of Kenya, KNBS and FSD Kenya, publishes its anonymised,
weighted microdata for anyone to download. The package now reaches it.

* `knbs_finaccess_files()` lists 22 files: the microdata of six household
  rounds (2006, 2009, 2013, 2016, 2021 and 2024) and two waves of the MSE
  Tracker Survey (2022 and 2023), in Stata, SPSS or Excel, with the
  questionnaires, manuals and reports. The catalogue ships with the package
  and records what each portal link actually serves: four of the portal's
  labels are wrong, and its 2006 and 2009 "Questionnaire" archives hold the
  data (audit F-40).
* `knbs_download_finaccess()` downloads them under their official names. A
  sixteen-byte request checks each file's served name and size before it
  moves; its size and SHA-256 are checked after, against checksums taken
  from full downloads of every file. A file already downloaded and
  identical is reused without a request, so
  `knbs_read_microdata(knbs_download_finaccess("hh2024-stata"))` is safe to
  re-run. The 2013 survey's Stata copy, behind a registration form on
  Harvard Dataverse, is listed and never fetched.
* `knbs_read_microdata()` reads Stata, SPSS and Excel files and the data
  inside a `.zip`, keeping value and variable labels, and attaches the
  provenance in the file's sidecar, so `knbs_cite()` cites the producers.
  It also reads files obtained through the national archive's own process.
* `knbs_search()` has a `"microdata"` type: one result per survey round,
  whose `get` call downloads and reads it.
* Downloads stream to disk instead of through memory, and are abandoned
  only once stalled for the timeout's length rather than when the timeout
  runs out, so a 300 MB file on a slow line completes.
* `knbs_status(live = TRUE)` checks that the portal still links every
  catalogued file.

The portal states no licence. FSD Kenya's terms for the 2013 survey
restrict it to research and forbid redistribution without written
agreement, so assume nothing wider: the terms travel in each file's sidecar
and metadata, the first download of a session names the producers, and no
file is bundled with the package.

## One provenance record per file

Provenance sidecars are now named after the whole file name:
`pop.dta` gets `pop.dta.metadata.json`, where it used to get
`pop.metadata.json`. The old name was shared by every file with the same
stem, so `knbs_write()`-ing a table as `pop.csv` and `pop.dta` into one
folder, or downloading a survey's Stata and SPSS copies side by side, left
only the last file's record. Sidecars written by earlier versions keep their
old names.

## Quieter lookups

`knbs_get_indicator()` resolves an indicator against every source's
catalogue, and warned "Could not reach: …" on every call while any one
portal was down — even for an indicator served by another source. It now
stays silent when the id is found in a source that answered. A name search
still warns, since the unreachable catalogue might hold another match, and a
not-found error names the unreachable source as a possible reason. The
README leads its live examples with the most dependable sources and says
what an outage looks like.

## Twelve more Statistical Abstract chapters

`knbs_abstract_table()` now serves 48 tables of the 2025 Statistical
Abstract, up from Chapter 2's fifteen: 33 more from Chapters 3–16 — wage
employment by sector; the Post Office Savings Bank and insurance business;
principal export commodities; crop sales and producer prices; forest
plantations and wildlife; electricity connections and fuel sales; producer
price indices and production of selected commodities; construction output
by county and cement; visitor arrivals, departures and hotel occupancy;
railway earnings, vehicle registration and inspection, Mombasa port and
aircraft; school enrolment, by county too; and registered births and
deaths by county. Each has a curated recipe, totals checked against their
parts where the table has them, and pinned figures (audit F-39).

* **County tables carry census codes.** Six tables are by county; their
  rows get `geo_code`, the census frame code, through the county matching
  of `knbs_county_code()` (the total row is `"00"`), so registered births
  join the census population in one step. A county table is refused if
  its rows stop accounting for the 47 counties exactly once.
* **Per-row units** come through as a `unit` column where a sheet prints
  them (sugar in tonnes, soft drinks in thousands of litres).
* **Footnotes keep their meaning.** Marks printed against labels
  ("Coffee1,2") are removed, and what they said — auction prices, revised
  years, what a category includes — is in `knbs_metadata()`'s notes, with
  the source each sheet credits.
* **A layout trap is now refused.** Table 3.11 puts Male | Female | Total
  under each year; the engine skipped that unlabelled second header row and
  would have read each year's Male column as the year's value. Any such
  row now stops extraction with `knbs_error_schema_changed`.

A survey of all 267 tables in the chapter workbooks found 38 in the layout
the engine reads; the 33 curated are those, less four tables split across
two sheets and Table 3.11.

## What KNBS has released lately

New `knbs_releases()` lists what KNBS has put on its website, newest first:
the last 30 days by default, any window with `since` and `until`, or one
series' whole history with `series = "cpi"`. Each row carries its release
`series`, the `period` it covers and the call that downloads it.

* Series are KNBS's regular releases, read from titles by a curated list
  (`knbs_release_series()`): the monthly CPI and inflation release and
  Leading Economic Indicators; quarterly GDP, balance of payments and
  trade, producer, construction-input and residential property price
  indices, and labour force reports; the Economic Survey, Facts and
  Figures, national and county Statistical Abstracts, Gross County
  Product and the Advance Release Calendar. Patterns allow for the
  library's own spellings ("Proprety", "Leading Economic Indicators-
  March 2026").
* `period` is the month (`"2026-09"`) or quarter (`"2026-Q2"`) a title
  names, `NA` otherwise. It matters because the date is the upload date:
  years of older releases were uploaded together when the library was
  set up in mid-2023.
* Tenders, adverts, vacancies and other notices — 23 of 2026's first 151
  uploads — are left out unless `notices = TRUE`.

Live: the last 30 days give the September 2026 CPI release and July's
Leading Economic Indicators; the CPI series holds 255 distinct months.

## Fixes

* Citations dated a retrieval in UTC, so anything retrieved between
  midnight and 03:00 in Nairobi was cited as retrieved the day before.
  The plain, BibTeX and RIS citations now use the local date.

## Files for Excel, Stata and SPSS, provenance included

New `knbs_write()` saves a result for colleagues who do not use R, and the
provenance goes with it. The format follows the extension:

* `.xlsx` — a `data` sheet and an `about` sheet: title, producer, source
  and URL, release date, reference period, unit, licence, retrieval time,
  package version, the source's notes, and a ready-made citation.
* `.csv`, `.dta` (Stata, the title as dataset label) and `.sav` (SPSS) —
  with a `<file>.metadata.json` sidecar, the one publication downloads
  already write.
* `.rds` — the object whole, metadata inside.

Codes stay text in every format (`"01"`, never 1). Stata's 32-character
limit shortens longer names, keeping their `_code` or `_type` ending and
uniqueness, with the full name as the variable label and every rename
recorded. List columns are written as JSON text and named in the
provenance. A table derived with `summarise()` or a pivot is plain data:
pass `metadata = knbs_metadata(original)` and its file carries the
source's provenance; without it the file is written with a warning and
says no provenance was attached. An existing file is never replaced
unless `overwrite = TRUE`. writexl and haven join Suggests.

## County names, matched across sources

County names are not spelled alike even inside KNBS: the census writes
"Murang'a", "Tharaka-Nithi" and "Nairobi City", the Data Portal "MURANGA",
"THARAKA NITHI" and "NAIROBI", each under its own codes. New
`knbs_county_code()` turns county names — or numbers — written any way into
the census frame's two-digit codes, ready for `mutate()` and a join; new
`knbs_match_counties()` shows how each value matched.

* A name matches once case, punctuation, spacing and apostrophes are set
  aside and "County", "City", "Government", "of" and "the" are dropped:
  "Taita/Taveta", "Taita Taveta" and "TAITA-TAVETA COUNTY" are all `"06"`.
  Numbers 1–47 are county numbers; "Kenya" and "National" are `"00"`.
* Nothing else is matched — no list of alternative names exists to guess
  from. A misspelling becomes `NA` with one `knbs_warning_unmatched`
  warning naming it and, where one official name is close, suggesting it
  ("Kakamenga" → did you mean "Kakamega"?).
* Verified live: all 48 names the Data Portal's county tables use match,
  to 48 distinct codes, and its rural-population table joins the census on
  all 47 counties. The county-data vignette works the example through.

## One search across everything

New `knbs_search()` answers "where does this live?" in one call. It
searches the indicator catalogues of every verified source, the survey
archive, the publications library and the curated Abstract tables, and
returns one ranked table — each row with `get`, the exact call that
retrieves it: `knbs_get_indicator("CPI_ALL_ITEMS", source = "knbs_cpi")`,
`knbs_abstract_table("2.2")`, `knbs_survey_metadata(...)`,
`knbs_download_publication(...)`.

* Matching is the package's own, over each catalogue in full, so it means
  the same everywhere: every word must appear in a title, id or topic.
  Words match by stem — the library's own search is literal, and for
  "consumer price index" returns 2 documents while KNBS publishes a
  "Consumer Price Indices and Inflation Rates" release every month; this
  finds them all — and four-letter prefixes match longer words. CPI, GDP, GCP, GVA, PPI, BOP, KDHS, KIHBS
  and LEI are understood both ways.
* Ranking is by tier — exact id, exact title, the query as a phrase,
  every word in the title, a match elsewhere — then data before documents
  and newer before older, so the CPI series leads a CPI search and the
  latest monthly release follows it.
* Catalogues are cached for a day. The first search of the day lists the
  whole publications library (about 16 requests); later ones take a
  second or two. An unreachable catalogue is a warning naming it; the
  error comes only when nothing answers.

## Rough edges: a silent row loss, readable columns, totals and parts

A live review on 2026-10-05 turned up places where correct data was still
easy to misuse, or where it was not correct at all.

* **A Statistical Abstract row was being dropped silently.** The "Tree,
  crop and plant resources yielding repeat products" row of Tables 2.7a and
  2.7c reads 7866, 8269, 8922, … — four-digit cells the extractor took for a
  repeated year header and skipped, so capital formation's parts no longer
  added up to its Total. A header is now recognised only as a run of
  consecutive years, and a repeat only as the same years in the same
  columns. The row is pinned in the registry so it cannot drop out again.

* **Totals and their parts are told apart.** The Abstract prints "GDP at
  market prices", "All industries", each industry and its sub-industries
  in one column, so summing a year counted GDP several times over. Tables
  2.2–2.7d now carry `parent`, the row each item is a component of (`NA`
  for headline totals and memo items): `filter(parent == "All industries")`
  gives the industries and nothing else. The structure is curated in the
  extraction registry and verified on every read — every named row must be
  present, and in the level and share tables the parts must add up to their
  parent in every year within what rounding explains. Had this existed, it
  would have caught the dropped row above. Imports enter GDP with a
  negative sign, and `knbs_metadata()` says so. The accounts tables (2.1,
  2.8, 2.9) are linked by identities, not parts and totals, and carry none.

* **Readable dimension columns — a breaking change.** Indicator dimensions
  were `<id>`/`<id>_label` pairs named by the source's internal ids
  (`p18_vs1`, `NA_INDIC`). Every source now follows the `geo_name`/
  `geo_code` pattern: `<name>` holds the labels and `<name>_code` the codes.
  Census tables use curated names — `marital_status`, `age`, `religion`,
  `household_head_sex` and the rest of the 29 dimensions the 2019 tables
  carry — because the API's own labels are long and sometimes misspelt. Data
  Portal flows use their SDMX id in lower case (`na_indic`), since the
  portal labels ten different dimensions just "Indicator". A Sex
  dimension is `sex`, lower-cased, everywhere. Code that read `p18_vs1 ==
  "T"` now reads `marital_status == "Total"` (or `marital_status_code ==
  "T"`); `table == "T3"` on Gross County Product becomes
  `table_code == "T3"`.

* **Census ages that add up.** The age table mixes single years with
  five-year groups and a total. New `age_type` (`"total"`, `"single_year"`,
  `"age_group"`, `"other"`) lets a pyramid keep one level; the groups are
  checked on every read to add up to the total and the single years to
  their group, which held exactly across all 393 areas when verified.

* **The Data Portal stopped declaring its geography (audit F-37).** By
  October the hub sent an empty geo role where it named `REF_AREA` in
  August, so `geo_code` vanished and geography filters were refused. The
  SDMX reference-area concept now stands in when the role is empty, as
  `TIME_PERIOD` already did for time.

* **A CPI Explorer outage points somewhere useful (audit F-38).** The
  Explorer's data service answered HTTP 500 on 2026-10-05. Its errors now
  name the Data Portal series that stands in, and how closely: the portal's
  `DF_CPI_R` index matched the Explorer to two decimals, but its inflation
  rates (`DF_CPI_YR`, `DF_CPI_MR`) are KNBS's published, rounded figures and
  differed — May 2026 year on year was 6.9 there against 6.68 here. Nothing
  is substituted silently.

The cache moves to parser version 3 and schema version 2 (with the two
source quirks below), so results cached in an older shape are re-fetched
rather than served.

## Two source quirks kept out of results

Both found by live testing on 2026-10-05.

* **Survey years of 0.** KeNADA stores `year_start` and `year_end` as `"0"`
  for the 53 of its 131 studies catalogued without a reference year, and its
  year filter returns all of them for any year: `knbs_search_surveys(year =
  2022)` came back with 54 rows, 53 of them dated `"0"` — the 2013 FinAccess
  National Survey among them. A year of 0 now standardises to `NA`, in
  `reference_years` and in `knbs_survey_metadata()`'s `reference_period`. A
  `year` filter is applied again client-side, matching a study whose years
  overlap the range; a study with no recorded year cannot match, so it is
  excluded, and a `knbs_warning_missing_metadata` warning says how many and
  names them in its `excluded` field. Years are never inferred from titles
  or ids. When the source matches more studies than one page holds, every
  match is fetched before filtering, so `limit` cannot shorten the count.
* **Census table titles.** The census API labels every table "Census 2019 -
  Population by sex and marital status" (POPCEN0002, POPCEN0003 and
  POPCEN0004 all carry it), whatever the table holds. `indicator_name` and
  the metadata title now come from the dataset list — POPCEN0002 is
  "Population by Single and Grouped Ages, Sex and sub County" — and the
  source's own label is recorded in `knbs_metadata()$notes`. Where the
  dataset list gives no name, the label stands and the notes say so.

## The tidyverse contract, locked in tests

Every data-carrying result has always been a vctrs-backed tidy tibble; the
behaviour is now guaranteed rather than incidental. Tests pin that dplyr
verbs — `filter()`, `mutate()`, `arrange()`, `select()`, `slice_max()`,
joins, `bind_rows()` — keep both the class and the provenance metadata
(`knbs_metadata()` still answers on the result); that `group_by()` +
`summarise()` and the tidyr pivots return plain tibbles, since a derived
table is the caller's data rather than the source's; and that
`tibble::as_tibble()` strips the wrapper cleanly. dplyr and tidyr join
Suggests for these tests, and the getting-started and statistical-abstract
vignettes now show the piped workflows, including `pivot_wider()`
recreating the printed-table look.

## The Statistical Abstract as tidy tables

The 2025 Statistical Abstract ships its chapter tables as Excel workbooks
on the KNBS website (audit F-35). New `knbs_abstract_tables()` and
`knbs_abstract_table()` turn the curated ones into clean tidy
observations — starting with all fifteen tables of Chapter 2, National
Accounts: the production accounts, GDP by activity at current and constant
prices, expenditure on GDP, capital formation, national income and saving.

* Extraction is **curated, never guessed** (audit F-36). Each table has a
  hand-verified recipe — sheet, title anchor, section labels, unit, pinned
  reference values — and every read re-verifies all of it. A workbook whose
  layout or figures have drifted is refused with a classed error;
  plausible-but-wrong tidy data is the one outcome the design rules out.
* The tidy shape keeps the table's meaning: `period` (integer year),
  `status` carrying the source's own provisional (`*`) and revised (`+`)
  year flags, the row dimension as a named column (`industry`,
  `expenditure_category`, `purpose`), sections as a second named column
  where the sheet has them, and rows the source prints without figures
  ("Less: Subsidies") kept with honest `NA` values.
* The workbook is fetched once through the existing verify-and-checksum
  layer, cached, and hashed; `knbs_metadata()` names the edition, sheet
  and workbook SHA-256 on every result, and `knbs_cite()` cites it.
* The extraction registry (`inst/extdata/abstract-registry.yml`) is the
  extension point: further chapters and the legacy annex sheets can be
  curated without touching the engine. Requires the new `readxl`
  dependency.

## Gross County Product, via the Open Data for Africa republisher

The county economy arrives as data — from the one portal that serves it.
`knbs_indicators()` and `knbs_get_indicator()` now also serve
`kenya.opendataforafrica.org` (`opendataforafrica` in the registry), the
Knoema-operated portal listed on KNBS's own portals page, which republishes
202 Kenyan datasets: 169 from KNBS under a "Public Domain" licence label,
the rest from the Central Bank of Kenya, ministries and agencies (audit
F-30). Chief among them: **Gross County Product**
(`knbs_get_indicator("jhbzkjc")`) — GVA shares plus constant- and
current-price GCP for all 47 counties, annual 2013–2020, which no
first-party KNBS portal serves as data.

* This is a **republisher**, and the package says so: every result's
  `knbs_metadata()` names the portal, the original producer, the dataset's
  own licence label (verbatim; "Not stated by the source" where there is
  none) and the portal's publication and update dates — so a vintage that
  lags the producer's newest PDFs is visible, never hidden. The GCP dataset
  is the 2021 edition; newer GCP years remain PDF-only.
* New `frequency` argument to `knbs_get_indicator()`. A portal dataset may
  mix annual, quarterly and monthly series under one id (audit F-33);
  annual periods are integer years and sub-annual ones are `Date`s, which
  cannot share a column, so a mixed dataset asks you to choose
  (`frequency = "annual"`) instead of picking one silently. Sources where
  the filter means nothing refuse it.
* Every series' timeline is expanded from its own start date and verified
  against its own stated end date; a mismatch is refused as a schema change
  rather than shifting values onto wrong years. Geography codes are the
  portal's own region codes (`geo_level` `NA`) and must never be joined
  against `knbs_geographies()`; the listing's structural fields are not
  trusted (audit F-32), and the portal's 200-with-a-string error answers
  are classed as missing resources (audit F-31).
* Unstated `start`/`end` bounds no longer imply a default window: previously
  observations before 2000 (and, for sub-annual series, after the current
  month) were silently trimmed even when no bounds were asked for. No
  verified source served such observations until now, so no earlier result
  changes; the bounds you *do* state behave exactly as before.

## The KNBS Data Portal: 323 dataflows

The economy arrives as data. `knbs_indicators()` and `knbs_get_indicator()`
now also serve the KNBS Data Portal (`knbs_opendata` in the registry) — an
SDMX hub carrying 323 dataflows across five statistical domains: GDP by
activity and by expenditure, GFCF, GNI, production accounts, CPI by division
and by region, balance of payments, trade, money and banking, county
government finance, employment, agriculture, tourism, health and justice
(audit F-28).

* Dataflow ids are the SDMX ids, e.g.
  `knbs_get_indicator("DF_NAT_GDPCP")` for GDP by activity at current
  prices. Annual flows carry integer-year periods; monthly and quarterly
  flows carry first-of-period `Date`s — the same conventions as everywhere
  else, and `start`/`end` work unchanged.
* The payload's own `role` field names the time and geography dimensions, so
  neither is guessed. Hub geography codes are SDMX area codes, not census
  territories, and `geo_level` is `NA` rather than invented; do not join
  them against `knbs_geographies()`.
* Dimensions with a single category are facts about the whole dataflow —
  "Prices = Current prices", "Unit = Kenya Shillings" — and fold into
  `knbs_metadata()` notes instead of arriving as constant columns.
* Data queries are POSTs with a JSON criteria body (a GET answers 405); the
  responses are JSON-stat with sparse values, parsed by the same generic
  parser the census adapter uses. The portal states no licence, and the
  metadata say so.

# knbsdata 0.4.0

Retail prices join the CPI family: what a kilogram of maize flour, a litre of
petrol or a month's single-room rent actually costs, monthly back to 2019.

* New `knbs_retail_prices()`: the monthly national average retail prices of
  the 22 commodities tracked for the CPI basket — maize flour, milk, petrol,
  house rent and the rest — in Kenya Shillings per stated unit, with the full
  history the CPI Explorer holds (audit F-27). Filter by commodity code or
  name and by period; a single month is fetched directly, a range walks the
  paginated listing once and caches it. National only: the source holds no
  regional retail prices, so no region argument exists. The portal's
  unstated licence is carried in the result's metadata, as for the CPI
  series.

# knbsdata 0.3.0

Consumer prices arrive as data, completing the plan's headline example:
`knbs_get_indicator("CPI_ALL_ITEMS", start = "2020-01")`.

## Consumer prices

* Three new indicators from the KNBS CPI Explorer (`knbs_cpi` in the
  registry): `CPI_ALL_ITEMS` (index points), `CPI_INFLATION_YOY` and
  `CPI_INFLATION_MOM` (percent) — monthly from January 2009, nationally and
  by the CPI collection strata (the Nairobi income bands, Nairobi Combined,
  Rest of Urban). Monthly observations carry `period` as a first-of-month
  `Date` plus a `period_label`; `start` and `end` accept a year, a month or a
  date, and now also bound census tables by their year.
* `knbs_indicators()` aggregates every verified indicator source, with a
  `source_id` column; one unreachable source degrades the catalogue with a
  warning, and a single requested source that fails keeps its own error class
  instead of a generic "unreachable".
* Honesty, carried in `knbs_metadata()` on every CPI result: the portal
  states no licence and no index base period, and its regions are collection
  strata that must never be joined against `knbs_geographies()`. Six listed
  regions — the former provinces — carry no data in any period (audit F-26);
  asking for them returns zero rows because that is the source's answer.
* Defences from the audit: a requested region is validated against the
  source's own region list before any data request, and a returned series
  that was not asked for is refused — the endpoint otherwise substitutes the
  national series for unknown regions silently (F-24). Date bounds are
  enforced client-side even though the server honoured them when traced.

## Other

* `knbs_publications()` with a `format` filter now pages back through older
  uploads until it has `limit` matches, instead of filtering only the most
  recent page. The live server ignores its file-type parameter (audit F-22),
  so a run of recent PDFs used to hide every workbook behind them —
  `knbs_publications(format = "xlsx")` could return nothing while dozens of
  Excel files existed. A record repeated across a page boundary by a mid-scan
  upload is kept once, running one page past the end is treated as the end,
  and a 5,000-document scan cap warns rather than trailing off silently.

# knbsdata 0.2.0

Three new source families join the survey catalogue: publications, census
tables as tidy indicators, and geographic reference codes. Every family is
audited, adapter-built, tested offline against fixtures and verified live;
`vignette("source-status")` states what each supports and what remains absent.

## Geographic reference codes (Phase 6)

* `knbs_geographies()` returns the 2019 census frame: Kenya, its 47 counties
  and their sub-counties, with names, structural parent codes and an explicit
  `vintage` column. Codes are character with leading zeros intact, read live
  from the census service's own Territory dimension (CC BY 4.0) rather than
  shipped as a snapshot that could drift from the source.
* A sub-county referencing a county the source did not list, or duplicate
  codes, are refused as validation failures rather than passed into joins.
* Asking for any vintage other than 2019 fails with a clear error: no other
  vintage, no crosswalk and no boundary file has a verified source, and a
  wrong crosswalk is worse than none. Classifications remain unimplemented for
  the same reason. New vignette, `county-data`.

## Census indicators (Phase 5)

The Phase 5 audit found a first-party machine-readable source: the KNBS census
data service behind `data.knbs.or.ke`, built with Istat and serving 2019
Population and Housing Census tables as JSON-stat 2.0 under an explicit
CC BY 4.0 statement.

* `knbs_indicators()` lists the 32 tables across their themes (Population,
  Health, ICT, Household Farming).
* `knbs_get_indicator()` returns a table as tidy observations: geography down
  to sub-county with leading zeros intact and a documented `geo_level`, `sex`
  in the source's own categories, and every other dimension as a
  `<dim_id>`/`<dim_id>_label` column pair. Provenance carries the licence and
  the release date; citations work as everywhere else.
* A generic JSON-stat 2.0 parser (dense and sparse values, status arrays,
  shape validation) with no KNBS specifics, ready for any future JSON-stat
  source.
* The registry gains an explicit `http_only` flag: the census API host has no
  TLS listener, and the exception is declared and validated rather than
  slipped past the HTTPS rule. Traffic to it is unencrypted in transit; it
  carries public aggregates and no credentials.
* Honesty notes: `frequency` and `unit` are `NA` — a census table is not a
  recurring series and the source states no units. Running indicators (CPI,
  GDP) are still not available as data: the CPI Explorer's backend could not
  be identified (audit F-21), so monthly releases remain available as
  documents via `knbs_publications()`. The API answers unknown ids with
  HTTP 200 and the body `errore`; the package reports not-found.

## Publications (Phase 4 completed)

The host that blocked Phase 4 recovered, its TLS chain fixed. The audit found
the WordPress core REST API open over the site's media library — roughly 1,600
documents with direct, ungated file URLs — while the Download Monitor catalogue
remains gated and untouched.

* `knbs_publications()` searches statistical releases, reports and workbooks,
  with free-text, format and reference-year filters.
* `knbs_download_publication()` downloads one publication through the verifying
  download layer: official filename preserved, a web page arriving in place of
  a document refused, SHA-256 recorded, provenance sidecar written.
* Honesty notes, both from the audit: `release_date` is the site's upload date,
  not the publication's reference period — the `year` column is read from the
  title and is `NA` when the title names none. And the media library also holds
  speeches and forms; narrowing to what you mean is the caller's query.
* The `format` filter is applied client-side even when the source also filtered,
  after the survey audit showed this family of APIs can silently ignore query
  parameters.

# knbsdata 0.1.0

First release. It covers **survey and census study discovery** through the Kenya
National Data Archive, and nothing else — see `vignette("source-status")` for
what that excludes and why.

## Survey catalogue

* `knbs_search_surveys()` searches the study catalogue, with filters for free
  text, reference year, producer and access type.
* `knbs_survey_metadata()` retrieves a study's full descriptive record. An
  identifier it does not recognise falls back to searching the catalogue: one
  match is used, several are reported so you can choose, none is a plain
  not-found.
* `knbs_variables()` searches variable metadata without downloading microdata,
  optionally retrieving each variable's full record.
* `knbs_survey_files()` lists a study's data files with their access conditions.
* `knbs_download_microdata()` refuses, explains that the archive requires an
  account, and points at the official access process. It exists so the refusal
  is explicit rather than looking like an oversight.

## Provenance

* `knbs_metadata()` returns the provenance record attached to every object: the
  source, the retrieval time, the release date, the access conditions and the
  package version.
* `knbs_cite()` builds a citation in plain, BibTeX or RIS form. Where the
  archive states a required citation, that text wins and the package adds only
  the retrieval information.
* Provenance survives row subsetting.

## Sources and health

* `knbs_sources()` reports what the package knows about each source and how far
  it has been verified.
* `knbs_status()` reports source health. Offline by default in any
  non-interactive session, so checks and CI never depend on a live service.
  Sources with unverified endpoints are never contacted, even when a live check
  is requested.

## Configuration and caching

* `knbs_options()` and `knbs_option()`, backed by ordinary R options under the
  `knbsdata.` prefix.
* `knbs_cache_dir()`, `knbs_cache_info()`, `knbs_cache_clear()` and
  `knbs_cache_prune()`. Entries are keyed on the source, operation, normalised
  query and parser version, checksummed, and written atomically. An entry that
  fails its checksum is discarded and refetched rather than returned.

## Behaviour worth knowing

* Every failure carries a `knbs_error_*` class. Nothing returns partial data
  dressed up as a result.
* A login gate signalled by an HTTP `Refresh` header — which is how the archive
  gates downloads — is raised as `knbs_error_authentication_required`, not
  mistaken for an empty but successful response.
* Responses are checked for the fields their operation requires, because the
  archive answers unknown paths with `200` and a study record rather than a 404.
  A payload arriving from the wrong place raises `knbs_error_schema_changed`.
* Access types are translated into a canonical vocabulary. `public_use` means
  public-use files exist; it does not mean they can be downloaded.
* No test touches the network.

## Known limitations

* **Publications, aggregate indicators and geographic reference data are not
  implemented.** All three live on a host that was unavailable throughout the
  source audit and every re-check, so its endpoints were never verified and no
  adapter was written.
* **Microdata cannot be downloaded**, by design.
* **Documentation files are not listed**: the archive publishes no
  machine-readable listing of questionnaires, reports or technical documents.
* Variable documentation is missing for some studies, which returns zero rows.

## Internal

* A download layer — streaming, type verification, SHA-256, provenance sidecars,
  manifests and archive path-traversal protection — is built and tested but not
  yet reachable, since no supported source permits a download.
