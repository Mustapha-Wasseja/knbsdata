# knbsdata (development version)

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
