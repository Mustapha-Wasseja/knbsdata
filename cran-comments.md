## Resubmission

This is a resubmission. In response to the review of 3 November 2026:

* The Description no longer starts with "An R client".
* References: the package implements no statistical methods, so there is no
  methods reference to cite. The Description now links each data source the
  package reads, in the form <https:...>.
* Writing files: no function writes by default.
  `knbs_download_finaccess()` and `knbs_download_publication()` have no
  default destination and stop with an informative error if none is given;
  `knbs_write()` requires a path. The examples, vignettes, README and tests
  write only to `tempdir()`, and the download calls that `knbs_search()`
  suggests name `destination = tempdir()`. The one write without a path
  argument is the response cache in `tools::R_user_dir()`, as the policy
  allows for R >= 4.0 (the package depends on R >= 4.1). It is now actively
  managed: the first write of each session removes expired entries and
  those written by earlier versions, and it can be switched off with
  `options(knbsdata.cache = FALSE)`.

## Submission

knbsdata is a client for the public web services of the Kenya National
Bureau of Statistics (KNBS) and partner publishers: the national data archive,
the KNBS website's publications library, the census, CPI and SDMX data
portals, the FinAccess survey portal and the DHS Program's indicator API.

## Test environments

* Local: Windows 11, R 4.5.2 (`R CMD check --as-cran`)
* win-builder: R-devel (2026-10-20 r90728 ucrt)
* GitHub Actions: ubuntu-latest (R-devel, R-release, R-oldrel-1),
  macos-latest (R-release), windows-latest (R-release)

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.
* Possibly misspelled words in DESCRIPTION: KNBS is the acronym of the Kenya
  National Bureau of Statistics, spelled out in the same sentence;
  "checksums" and "schemas" are correct.

## Notes for the reviewer

* Words such as KNBS, KDHS, FinAccess, KeNADA and SDMX are the names of
  organisations, surveys and standards, not misspellings.
* Internet resources. Every function that contacts a service fails with an
  informative, classed error when the service is unavailable or has changed
  shape; nothing returns partial data silently. Examples that need a service
  run only in interactive sessions (`@examplesIf interactive()`); the rest
  run everywhere. Tests never touch the network: they run against stored
  responses, and a suite-wide guard fails any test that would make a real
  request.
* Files. Downloads are written only to a directory the user names; there is
  no default destination. Responses are cached in `tools::R_user_dir()`,
  with expiry and `knbs_cache_clear()` / `knbs_cache_prune()` to manage it.
  Examples and tests use temporary directories only.
* Data. No survey microdata are bundled. Tests use small synthetic files,
  trimmed public API responses and small excerpts of public KNBS workbooks.
