# knbsdata implementation status

Update this file after each significant implementation step. It is the single
place where phase progress, open decisions and blockers are recorded.

- **Last updated:** 2026-08-08
- **Current phase:** post-0.1.0 development. Phases 4, 5 and **6** are
  complete — publications, census indicators, and geographic reference codes.
  Every plan phase now has a shipped core, and the plan's headline example —
  `knbs_get_indicator("CPI_ALL_ITEMS", start = "2020-01")` — works: the
  consumer-prices adapter is built on the traced CPI Explorer API (audit 1c),
  with the F-24 region-substitution defence and F-26 empty-province behaviour
  tested, and the unstated licence carried in every result's metadata.
  Retail prices are delivered too (`knbs_retail_prices()`, audit F-27: the
  full national history, no regional data exists). **The biggest open
  opportunity is now audit F-28**: `opendata.knbs.or.ke` is a first-party
  Istat DataBrowser hub carrying 323 SDMX dataflows — GDP, CPI by division
  and region, BoP, trade, county government finance, employment and more —
  found when a direct question exposed that the Phase 5 audit had probed it
  only superficially. An adapter there would convert dozens of
  document-only families into data; its data-query shape and licence remain
  to be characterised first. Gross County Product, however, is PDF-only on
  every official portal (checked exhaustively 2026-08-08); the only data
  route for it would be a registered experimental PDF-table parser per plan
  section 11.12. Other threads: COICOP divisional series (F-25),
  classifications, boundaries, `knbs_search()`.
- **Package version:** 0.1.0.9000
- **Network access implemented:** three live sources — KeNADA, the website
  media library, and the census data API. Every test still runs offline
  against fixtures.

---

## Phase 6: geographies — core complete, extensions honestly absent

| Task | Status |
|---|---|
| Build county reference data | done — read live from the census API's Territory dimension (audit F-20), never shipped as a static snapshot |
| Code-vintage metadata | done — `vintage` column, 2019 throughout; other vintages refused with a clear error |
| `knbs_geographies()` | done — level, vintage and parent filters |
| Add aliases carefully | none added — no verified source for alternative names, so none invented |
| Classification retrieval | **not implemented** — no audited source |
| Boundaries | **not implemented** — plan requires a licence-reviewed official file first; none verified |
| County-data vignette | done |

### Exit criteria

- [x] All county codes remain character — enforced by validation and tested
- [x] Vintage is explicit — a column, not a footnote
- [x] No unverified geographic crosswalk is presented as official — none is
      presented at all; requesting another vintage errors
- [x] Boundary feature-count tests — not applicable, boundaries not included

### Design notes

- Parenthood is structural, not inferred: a sub-county's code embeds its
  county in its first two digits. A sub-county whose county is absent from
  the source, or duplicated codes, fail validation rather than corrupting
  joins downstream.
- The reference is read from the same table family the observations come
  from, so `knbs_geographies()` joins `knbs_get_indicator()` output exactly —
  there is a test that proves the join is lossless.

---

## Phase 5: census indicators — complete

The audit found what the original plan hoped for: a first-party,
machine-readable indicator source. KNBS's own portals page lists the
DataBrowser at `data.knbs.or.ke`; its backend (`api1.knbs.or.ke`) serves 2019
census tables as JSON-stat 2.0 under an explicit CC BY 4.0 statement (audit
section 1b, findings F-15 to F-21).

| Task | Status |
|---|---|
| Select one stable indicator source | done — census data API, tier 2 |
| Build indicator registry | not needed — the source's own ids are stable (`POPCEN0001`…); a package-level alias layer would add churn, not shelter |
| `knbs_indicators()` | done |
| `knbs_get_indicator()` | done |
| Period filtering | not applicable — census tables carry one reference year; `period` = 2019 read from the source statement |
| Dimension filtering | done for geography (`geo_level`, `geo_code`); other dimensions come back as columns to filter in R |
| Release metadata | done — `updated` and source statement in provenance |
| Validation | done — JSON-stat shape, value/size agreement, duplicate keys, character geo codes |
| Indicator vignette | done — `census-indicators` |
| At least three indicator families | **partially met, stated plainly:** Population, Health, ICT and Household themes of one census. Running families (consumer prices, national accounts, labour, trade) remain unavailable — the CPI Explorer's backend resisted static identification (F-21) |

Infrastructure added: a generic JSON-stat 2.0 parser (`R/parse-jsonstat.R`)
with no KNBS specifics, and an explicit, validated `http_only` registry flag
for the API host's missing TLS listener (F-16).

Verified live: 32 datasets listed; county extraction returns all 47 counties;
the national age-12+ total (32,508,769) matches the source's own CSV; the
`errore` body maps to not-found; all three verified sources answer `ok` in one
`knbs_status(live = TRUE)` call.

---

## Phase 0: repository bootstrap — complete

| Task | Status | Where |
|---|---|---|
| Package skeleton | done | `DESCRIPTION`, `NAMESPACE`, `R/`, `man/` |
| Licence | done (provisional, see decision 1) | `LICENSE`, `LICENSE.md` |
| `testthat` edition 3 | done | `tests/`, `Config/testthat/edition: 3` |
| `roxygen2` | done | `man/` generated, markdown enabled |
| GitHub Actions | done | `.github/workflows/` (check, lint, pkgdown, source monitor) |
| pkgdown | done | `_pkgdown.yml` |
| Linting | done | `.lintr` |
| Code of conduct | done | `CODE_OF_CONDUCT.md` |
| Contributing guide | done | `CONTRIBUTING.md` (includes adapter checklist) |
| Issue templates | done | `.github/ISSUE_TEMPLATE/` |
| Security policy | done | `SECURITY.md` |
| Package documentation object | done | `R/knbsdata-package.R` |
| Package options | done | `R/options.R`, `R/zzz.R` |
| Condition classes | done | `R/conditions.R` |
| Source registry format | done | `inst/extdata/source-registry.yml` |
| Registry validation | done | `R/registry.R`, `tests/testthat/test-registry.R` |
| Source audit document | started (template only) | `dev/source-discovery/source-audit.md` |

### Exit criteria

- [x] `R CMD check --as-cran`: 0 errors, 0 warnings, 1 note
      ("unable to verify current time" — the check host had no network access;
      environmental, not a package problem)
- [x] Unit tests pass (73 assertions, `devtools::test()`)
- [x] `lintr::lint_package()`: 0 lints
- [x] A minimal pkgdown site builds (`docs/`, git-ignored)
- [x] No test touches the network
- [x] Pushed to `Mustapha-Wasseja/knbsdata` (private) on branch `main`
- [x] CI green on first run: R CMD check passed on all five matrix
      combinations (macOS release, Windows release, Ubuntu release / oldrel-1 /
      devel), lint passed, pkgdown built and deployed to `gh-pages`

### Exported so far

See the Phase 2 section below for the current export list.

---

## Phase 2: core infrastructure — complete

| Task | Status | Where |
|---|---|---|
| `knbs_request()` | done | `R/http.R` |
| Retry and error handling | done | `R/http.R` — status → condition class map |
| Cache | done | `R/cache.R` |
| Registry loader | done in Phase 0 | `R/registry.R` |
| Query object | done | `R/query.R` |
| Base adapter contract | done | `R/source-generic.R` |
| JSON parser | done | `R/parse-json.R` |
| CSV / HTML parsers | deferred | not needed until a source requires them |
| Metadata classes | done | `R/metadata.R`, `R/knbs-data.R` |
| `knbs_cite()` | done | `R/citations.R` — plain, BibTeX, RIS |
| Print methods | done | `R/knbs-data.R`, `R/metadata.R`, `R/query.R` |
| Fixture test helpers | done | `tests/testthat/helper-cache.R` |
| Fake adapter | done | `R/adapter-fake.R`, `inst/extdata/fake/` |

### Exit criteria

- [x] A mock source can be searched and fetched end to end — the `fake_source`
      adapter runs search → metadata → files → fetch → cite entirely offline
- [x] Cache behaviour is tested — hit, miss, refresh, disabled, expiry,
      corruption, checksum mismatch, parser-version mismatch, prune, clear
- [x] Metadata survive supported operations — provenance is restored through
      row subsetting via `vec_restore()`
- [x] Errors use package-specific classes throughout
- [x] 297 test assertions pass; 0 lints

### Exported so far

`knbs_option()`, `knbs_options()`, `knbs_sources()`, `knbs_metadata()`,
`knbs_cite()`, `knbs_cache_dir()`, `knbs_cache_info()`, `knbs_cache_clear()`,
`knbs_cache_prune()`.

No retrieval function is exported yet: `knbs_search()`,
`knbs_search_surveys()`, `knbs_get_indicator()` and the rest arrive with their
adapters in Phases 3 to 6.

### Design decisions taken in Phase 2

1. **The auth gate is handled in the HTTP layer, not per adapter.** A `Refresh`
   header naming a login page becomes `knbs_error_authentication_required` for
   every source, so no future adapter can forget it.
2. **`print()` methods write to stdout.** cli's `cli_*()` functions signal
   conditions that land on stderr, which is right for messages and wrong for
   print output; `knbs_cat()` formats cli markup and writes to stdout.
3. **Cache keys include parser and schema version**, so upgrading the package
   invalidates entries a new parser would read differently.
4. **A cache entry that fails its checksum is discarded, not returned.** The
   caller simply refetches.
5. **The registry decides what a source may be asked to do.** `check_operation()`
   refuses any operation a source does not declare, which is what keeps
   KeNADA's undeclared download operation unreachable rather than merely
   discouraged.
6. **CSV and HTML parsers were not built.** Nothing needs them yet; building
   them now would be speculative.

---

## Phase 1: source discovery — partially complete

Full findings in [`dev/source-discovery/source-audit.md`](source-discovery/source-audit.md).

| Task | Status |
|---|---|
| Audit survey catalogue | **done** — KeNADA, tier 2 for metadata |
| Audit publications catalogue | **blocked** — `knbs.or.ke` unavailable |
| Audit aggregate indicator portals | **blocked** — same host |
| Audit geography reference sources | **blocked** — same host |
| Identify APIs and machine-readable downloads | done for KeNADA |
| Record terms and access restrictions | done for KeNADA |
| Build `source-registry.yml` | updated: `kenada` verified |
| Build registry validator | done in Phase 0 |
| Write source audit | done for what could be reached |
| Classify sources by support tier | 1 of 4 |

### Exit criteria

- [x] At least one survey source is implementation-ready — **KeNADA metadata**
- [ ] At least one publication source is implementation-ready — blocked
- [ ] At least one aggregate indicator family is implementation-ready — blocked
- [x] Every chosen source has fixtures and documented legal access — KeNADA has
      7 fixtures in `dev/fixtures/kenada/` and its access conditions recorded

### What the audit established

- The KeNADA NADA JSON API is enabled and needs no credentials for study search,
  study metadata, variables and data-file listings. 129 studies, 1969–2022.
  No HTML scraping is needed for the survey catalogue.
- **Microdata download is gated behind a login** and must not be automated. The
  gate is signalled by a `Refresh` header to `/auth/login`, not a 3xx, so an
  unwary client would read it as a successful empty response.
- `form_model: "public"` means public-use files, **not** freely downloadable.
- Detail endpoints key on the DDI `idno`, not the numeric `id`.
- Variable metadata is missing for some studies, including the most recent one.
- `knbs.or.ke` returned 504 / timed out for the entire audit, and serves an
  incomplete TLS certificate chain that strict clients such as `curl` and
  `httr2` will reject.

---

## Phase 3: survey catalogue MVP — complete bar one task

| Task | Status | Where |
|---|---|---|
| Implement survey adapter | done | `R/adapter-nada.R` |
| `knbs_search_surveys()` | done | `R/surveys.R` |
| `knbs_survey_metadata()` | done | `R/surveys.R` |
| `knbs_variables()` | done | `R/surveys.R` |
| `knbs_survey_files()` | done | `R/surveys.R` |
| Classify access types | done | `R/standardise-surveys.R` |
| Documentation download for public files | **out of scope for 0.1.0** — decided | — |
| Microdata download where explicitly supported | refused, with an explanation | `knbs_download_microdata()` |
| Survey vignette | done | `vignettes/survey-catalogue.Rmd` |

### Exit criteria

A user can:

1. [x] Find a survey — `knbs_search_surveys()`
2. [x] Read its metadata — `knbs_survey_metadata()`
3. [x] Search its variables — `knbs_variables()`
4. [x] List its data files — `knbs_survey_files()`
5. [x] Understand access requirements — `access_type` and `downloadable`
       columns, plus the print method's warning that "public use" does not mean
       "downloadable"
6. [x] **Download public documentation — accepted as out of scope for 0.1.0.**
       The API exposes no endpoint for questionnaires, reports or technical
       documents (audit F-09); the only route is parsing the related-materials
       HTML page, which sits sixth in the plan's preference order. Users reach
       the same documents through the `catalogue_url` column. Revisit if KNBS
       exposes an endpoint.
7. [x] Download public-use data only when legitimately available — it is not
       available anywhere, so `knbs_download_microdata()` refuses and points at
       the official process

### What the adapter defends against

- **F-08, the most consequential finding.** Unknown subpaths return `200` with
  the *study* payload rather than a 404, so a renamed endpoint would deliver
  plausible nonsense. `nada_expect()` checks every response for the fields the
  operation requires and reports a study payload arriving in the wrong place as
  `knbs_error_schema_changed`.
- **F-02.** Detail endpoints key on `idno`; the numeric `id` is a 400.
- **F-03.** `form_model: "public"` is translated to `public_use`, which the
  print method explicitly annotates as "requires an account to download".
- **F-04.** A study with no documented variables returns zero rows.
- **F-10.** `variables?file_id=` is ignored by the source, so file filtering is
  done client-side.

---

## Phase 4: publications — complete (2026-08-08)

The host recovered and the TLS chain was fixed server-side (F-11), so the
missing half was audited and built.

| Task | Status |
|---|---|
| Implement publication adapter | done — `R/adapter-wordpress.R` over `wp/v2/media` |
| `knbs_publications()` | done — free-text, format and title-year filters |
| `knbs_download_publication()` | done — through the Phase 4 download layer |
| Metadata sidecar | done (was already built) |
| Checksums | done (was already built) |
| Citation support | done |
| Publication examples | done — README, `getting-started`, `source-status` |

Exit criterion — "a user can search for a publication by topic and year,
download it, verify it, and generate a citation" — verified **live**: searched
"economic survey" (100 hits), filtered xlsx and year, downloaded a 13,955-byte
workbook whose checksum matched, whose magic bytes were correct, whose sidecar
was written, and cited it. Overwrite protection and the unknown-id path were
exercised live too.

Key audit findings: F-12 (the Download Monitor catalogue is gated and is not
touched; the media library carries the same files openly), F-13 (upload date is
not the reference period — the year comes from the title or is NA), F-14 (the
library also holds speeches and forms; no hand-curated allowlist).

### The original blocked attempt (2026-08-04), kept for the record

`knbs.or.ke` was still returning `504 Gateway Time-out` when Phase 4 was
attempted, roughly four hours after the outage was first recorded. The
publications catalogue lives there, so its endpoints remain unaudited and
unverifiable.

**The adapter was not written.** Writing `source_search()` and
`source_metadata()` for a publications source would mean inventing an endpoint,
a response shape and a file-URL pattern, which is precisely what the plan
forbids ("Do not guess production endpoints"). A guessed adapter would also look
finished, which is worse than an absent one.

| Task | Status |
|---|---|
| Implement publication adapter | **blocked** — source unavailable |
| `knbs_publications()` | **blocked** — needs the adapter |
| `knbs_download_publication()` | **blocked** — needs the file-URL pattern |
| Add metadata sidecar | **done** — `write_sidecar()` |
| Add checksums | **done** — SHA-256 over the written file |
| Add citation support | **done in Phase 2** — `knbs_cite()` works from any metadata |
| Add publication examples | blocked |

### What was delivered: the download layer (`R/download.R`)

Source-independent, so none of it depended on the unavailable site. It is
internal until an adapter produces URLs for it.

- Streams to a temporary file and only moves it into place once the transfer,
  the type check and the checksum have all succeeded, so a failed download
  cannot leave a half-written file that looks complete.
- Refuses a response that is a web page where a document was requested. This is
  the same class of failure as audit F-03: a gate or error page served with
  status 200, which would otherwise be written to disk under a `.pdf` name and
  reported as success.
- SHA-256 over the file as written, not as received.
- `<file>.metadata.json` sidecar, so provenance survives the file being moved
  out of an R session, and a CSV manifest in the plan's section 11.9 schema.
- Refuses archive entries that would escape the destination — `../`, absolute
  unix paths, Windows drive paths — before extracting anything, so a malicious
  archive is rejected whole rather than partly unpacked.
- Will not overwrite an existing file unless asked.

Tested with the single network-touching function mocked, so the suite stays
offline: 40 assertions covering checksums, filename preservation through query
strings, the HTML-instead-of-document refusal, overwrite protection, directory
creation, sidecar contents, manifest schema and five kinds of unsafe archive
entry.

---

## Phase 7: release — 0.1.0

Scope decision: ship what is verified rather than wait indefinitely for a host
that has been down for hours. 0.1.0 is a survey-catalogue package.

### Definition of done (plan section 31)

- [x] Package passes `R CMD check`
- [x] CI passes on major operating systems
- [x] At least one survey catalogue is supported — KeNADA
- [ ] At least one publication catalogue — **explicitly accepted as absent.**
      The source could not be verified; see audit F-05
- [ ] At least three aggregate indicator families — **explicitly accepted as
      absent**, which the plan permits provided the limitation is stated. It is
      stated in the README, `NEWS.md` and `vignette("source-status")`
- [ ] County reference data — **explicitly accepted as absent.** Same host
- [x] Citations work — plain, BibTeX, RIS, honouring a source-supplied citation
- [x] Metadata are attached
- [x] Caching works
- [x] Restricted access is handled safely — the download refusal is a tested,
      documented behaviour rather than an omission
- [x] Documentation is complete — three vignettes, every export documented
- [x] All live-source tests separated from ordinary tests — no test touches the
      network
- [x] Source-status and limitations published — `vignette("source-status")`
- [x] Licences and terms reviewed — MIT, copyright holder Mustapha Wasseja;
      the licence covers the software only, not retrieved data
- [x] Clear maintainer and contact route — DESCRIPTION, SECURITY.md, issue
      templates

### Release tasks

| Task | Status |
|---|---|
| Reverse dependency check | not applicable — nothing depends on it |
| Improve errors | done across phases 2 and 3 |
| Complete documentation | done — `getting-started`, `survey-catalogue`, `source-status` |
| Complete source-status table | done — published as a vignette |
| Add lifecycle badges | done — the five survey functions are marked experimental |
| Add citation file | done — `inst/CITATION` |
| Review licences | done — MIT, real copyright holder |
| Review terms | done — recorded per source in the audit |
| Run security scan | done — no credentials tracked; a contact email was redacted from stored fixtures |
| Run full `R CMD check` | done — 0/0/0 |
| Test fresh installation | done — built, installed to a clean library, exercised live |
| Tag release | done — `v0.1.0` |
| Publish pkgdown | builds in CI; the site stays dark while the repo is private |
| rOpenSci review | not pursued for 0.1.0 |

### Why three phases were skipped rather than deferred quietly

Phases 4, 5 and 6 all depend on `knbs.or.ke`, which returned `504 Gateway
Time-out` on every check across roughly six hours: at the start of the Phase 1
audit, twice during Phase 2, at the start of Phase 4, throughout a 50-minute
monitor, and at a final check before release. Writing adapters against a source
whose endpoints, response shapes and file-URL patterns are all unknown would
have meant inventing them. The resulting code would have looked complete and
failed silently, which is worse for a user than a stated gap.

---

## Deviations from the plan

Recorded so they are visible rather than silent.

1. **`knbs_options()` signature.** The plan (section 11.20) shows defaults in the
   signature, which would reset every option whenever one is changed. Implemented
   instead as: arguments default to `NULL` meaning "leave unchanged"; calling with
   no arguments returns current values; setting returns previous values invisibly.
2. **Registry rule added.** A source whose `base_url` is `PLACEHOLDER_TO_VERIFY`
   must have `stability: discovery`. The example registry in section 12.1 gives
   `kenada` stability `beta` and `knbs_publications` `experimental` while their
   URLs are still placeholders; that combination is now rejected. All four
   registry entries are therefore at `discovery`.
3. **`fake_source` registry entry.** Added ahead of the fake adapter required by
   step 4 of the implementation sequence, so that public functions can be tested
   entirely offline.
4. **Warning classes.** The plan enumerates error classes (section 18.1) but not
   warning classes; a matching `knbs_warning_*` vocabulary was defined in
   `R/conditions.R`.
5. **Deferred to Phase 7:** `inst/CITATION`, `cran-comments.md`. **Deferred to
   Phase 3+:** vignettes (`vignettes/` does not exist yet).

---

## Open decisions

Section 35 of the plan. Do not resolve these silently in code.

| # | Decision | Current stance |
|---|---|---|
| 1 | Package licence | **MIT, provisionally.** Chosen as the plan's default so Phase 0 could complete; not confirmed by the maintainer. Copyright holder currently reads "knbsdata authors" — set a real holder before any release. |
| 2 | Formal KNBS affiliation | None. Disclaimer in README and DESCRIPTION states the package is independent. |
| 3 | Which indicator source is stable enough | Still unknown — the candidate host was down for the whole audit |
| 4 | Does the survey catalogue expose a machine-readable API | **Resolved: yes.** KeNADA exposes the NADA JSON API, unauthenticated for metadata (audit F-01) |
| 5 | Which public-use microdata may be downloaded programmatically | **Resolved: none.** KeNADA gates every download behind a login (audit F-03). `knbs_download_microdata()` must refuse and point at the official process |
| 6 | Which geographies and boundaries have clear licences | Still unknown. KeNADA exposes `nation` only, so this depends on the main site |
| 7 | `sf` as Import or Suggest | Neither yet. Plan recommends Suggest until boundaries are implemented. |
| 8 | Indicator period class | Undecided. Plan's practical first release: integer for annual, `Date` at period start for monthly/quarterly, plus `period_label` and explicit `frequency`. |
| 9 | All dimensions as columns vs a `dimensions` list-column | Undecided. Plan recommends stable core columns plus recognised dimensions, list-column only when necessary. |
| 10 | Source citation vs package-generated citation | Undecided |
| 11 | Catalogue cache validity | Provisional default 24 hours; not implemented |
| 12 | Retain explicit historical releases indefinitely | Undecided |
| 13 | Swahili metadata support | Undecided; depends on what sources expose |
| 14 | First release target: CRAN or GitHub | Undecided. Package is set up to satisfy CRAN either way. |
| 15 | rOpenSci software review | Undecided |

---

## Blockers

1. **`knbs.or.ke` was unavailable throughout the Phase 1 audit** (504 from the
   origin; `curl` timed out). It hosts publications, indicators and reference
   data, so three of the four source families could not be assessed. Phase 4
   (publications) and Phase 5 (indicators) cannot start until it is reachable.
   Phase 3 (survey catalogue) is unblocked and can proceed now.
   Secondary risk on the same host: the TLS chain is incomplete (audit F-06),
   so even once it is up, `httr2` may fail certificate verification.
2. **Author identity incomplete.** `DESCRIPTION` lists Mustapha Wasseja
   <muswaseja@gmail.com>; the licence copyright holder is a placeholder.
3. **Repository is private.** Pushed to `Mustapha-Wasseja/knbsdata` on `main`.
   The pkgdown workflow deploys to a `gh-pages` branch, which GitHub Pages will
   not serve from a private repository on a free plan, so the documentation site
   badge and URL stay dark until the repository is made public.

---

## Source audit status

| Source | Tier | Base URL verified | Terms reviewed | Fixtures |
|---|---|---|---|---|
| `kenada` — metadata | 2 | yes (2026-08-03) | yes — no site-wide terms page; per-study `data_access` | 7 files |
| `kenada` — microdata download | 3 (metadata only) | n/a — gated | yes — login required | n/a |
| `knbs_publications` | not assessed | no | no | no |
| `knbs_indicators` | not assessed | no | no | no |
| geography | not assessed | no | no | no |

See `dev/source-discovery/source-audit.md`.

---

## Priority 5 progress

- [x] `knbs_status()` — offline by default (`live = interactive()`), live only
      when asked. Unverified sources are never contacted. Wired into the weekly
      `test-sources` workflow, which now fails only when a source that ought to
      answer does not.
- [x] Live verification against KeNADA: search, metadata, variables (including
      `details = TRUE`), files, the download refusal, ambiguous-identifier
      handling and `knbs_status(live = TRUE)` were all exercised against the
      real service. Status reports `ok`, HTTP 200, ~1.4s.
- [ ] Progress indicators for downloads — nothing downloads yet
- [ ] Remaining vignettes
- [ ] Source-status page in the pkgdown site

## Next three tasks

1. Phase 1 (resume) — when `knbs.or.ke` is reachable, check `/wp-json/wp/v2/`
   first (audit F-07), then the publications listing, the CPI release format and
   `/data-portals/`. Re-test the TLS chain at the same time. Phases 4 and 5
   cannot start before this.
2. Decide open decision 8 (indicator period class) before Phase 5, since it
   shapes the indicator schema and cannot easily be changed afterwards.
3. Add the remaining vignettes (`getting-started`, `reproducible-citations`)
   and a source-status page for the pkgdown site.

Decided: documentation download is out of scope for 0.1.0 (audit F-09).

A 25-minute poll of `knbs.or.ke` during Phase 2 never succeeded, so the outage
outlasted the session in which it was found.

---

## Known risks

| Risk | Mitigation in place |
|---|---|
| Source websites change | Adapter isolation, registry, weekly `test-sources` workflow, classed errors |
| No documented API exists | Prefer official file downloads; be willing to ship metadata-only support |
| Access restrictions misunderstood | Explicit `authentication` and access fields; conservative default of no download |
| Geographic codes lose leading zeros | Codes read as character; validation tests required from Phase 6 |
| Data revisions break reproducibility | Preserve release date and vintage; checksum downloads; immutable version cache |
| Package appears officially endorsed | Disclaimer in README, DESCRIPTION and licence file |
| Scope creep | Strict 0.1.0 scope; one vertical slice at a time |
