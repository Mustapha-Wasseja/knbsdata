# knbsdata implementation status

Update this file after each significant implementation step. It is the single
place where phase progress, open decisions and blockers are recorded.

- **Last updated:** 2026-08-03
- **Current phase:** Phase 0 complete → Phase 1 (source discovery) not started
- **Package version:** 0.0.0.9000
- **Network access implemented:** none

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
- [x] Git repository initialised on branch `main` (nothing committed yet)

### Exported so far

`knbs_option()`, `knbs_options()`, `knbs_sources()`. Nothing else is exported;
every other function named in the plan is unimplemented.

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
| 3 | Which indicator source is stable enough | Unknown — Phase 1 |
| 4 | Does the survey catalogue expose a machine-readable API | Unknown — Phase 1 |
| 5 | Which public-use microdata may be downloaded programmatically | Unknown — Phase 1. Default is "none until proven otherwise". |
| 6 | Which geographies and boundaries have clear licences | Unknown — Phase 1/6 |
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

1. **No verified KNBS endpoint.** Nothing in the registry has a real URL. Phases
   3–5 cannot start until Phase 1 establishes at least one usable source, and it
   is possible that some phases turn out not to be feasible (metadata-only, or
   tier 4 "do not automate").
2. **Author identity incomplete.** `DESCRIPTION` lists Mustapha Wasseja
   <muswaseja@gmail.com>; the licence copyright holder is a placeholder.
3. **Repository not yet on GitHub.** Git is initialised locally on `main` with
   nothing committed. Workflows and badges point at
   `Mustapha-Wasseja/knbsdata`; they are inert until the repository is pushed.

---

## Source audit status

| Source | Tier | Base URL verified | Terms reviewed | Fixtures |
|---|---|---|---|---|
| `kenada` (survey catalogue) | not assessed | no | no | no |
| `knbs_publications` | not assessed | no | no | no |
| `knbs_indicators` | not assessed | no | no | no |

See `dev/source-discovery/source-audit.md`.

---

## Next three tasks

1. Phase 1 — audit the KNBS survey catalogue: landing page, catalogue software,
   whether a documented machine-readable endpoint exists, terms of use, robots
   policy, access conditions per study. Record it in the audit template and
   assign a tier.
2. Phase 1 — do the same for the publications catalogue and for whichever system
   publishes aggregate indicators (CPI first).
3. Phase 2 — build the HTTP layer (`knbs_request()`), the cache, and the fake
   adapter, so that a search → metadata → standardise → cite slice can be proven
   end to end against fixtures before any real source is wired in.

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
