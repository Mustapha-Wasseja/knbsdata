# knbsdata implementation status

Update this file after each significant implementation step. It is the single
place where phase progress, open decisions and blockers are recorded.

- **Last updated:** 2026-08-03
- **Current phase:** Phase 3 (survey catalogue MVP) complete except for
  documentation download, which the source does not support. Phases 4 and 5
  remain blocked by a site outage.
- **Package version:** 0.0.0.9000
- **Network access implemented:** yes, for the KeNADA survey catalogue. Every
  test still runs offline against fixtures.

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
| Documentation download for public files | **not possible** — see below | — |
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
6. [ ] **Download public documentation — not possible.** The API exposes no
       endpoint for questionnaires, reports or technical documents (audit F-09).
       They exist only on HTML pages, and the plan defers HTML scraping.
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
3. Decide what to do about documentation download (audit F-09): either accept
   the gap for 0.1.0 or accept HTML parsing of the related-materials page as a
   documented exception to the plan's preference order.

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
