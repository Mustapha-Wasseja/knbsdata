# Contributing to knbsdata

Thanks for your interest. This project is in early development, so the
most valuable contributions right now are source discovery findings and
corrections to how the package describes access conditions.

## Ground rules

These are not negotiable, and a pull request that breaks one will not be
merged:

1.  **Official sources first.** Data must come from KNBS-controlled or
    KNBS-authorised systems. No third-party mirrors by default.
2.  **Never bypass access controls.** No circumventing registration,
    licences, approval workflows, authentication, rate limits, robots
    exclusions or human verification. A restricted dataset may be listed
    in the catalogue; it must not be downloaded.
3.  **Never commit secrets.** No credentials, tokens or cookies in code,
    fixtures, registry files, manifests or test snapshots.
4.  **Fail explicitly.** Never return silently incomplete data. Use the
    classed conditions in `R/conditions.R`.
5.  **No silent guessing.** Do not infer indicator ids, units,
    geographic vintages, release dates, missing-value meanings or access
    permissions.
6.  **No live network in ordinary tests.** Unit tests use fixtures. Live
    checks belong in the scheduled `test-sources` workflow.

## Development setup

``` r

install.packages("devtools")
devtools::load_all()
devtools::test()
devtools::document()
devtools::check()
```

Style follows the tidyverse style guide: two-space indentation,
`snake_case`, small functions, early validation. `lintr` runs in CI; the
configuration is in `.lintr`.

## Pull requests

- Open an issue first for anything larger than a fix, so the approach
  can be agreed before you write code.
- One vertical slice at a time. The plan sequences work deliberately;
  adding a second source before the first is finished and tested creates
  rework.
- Add tests with fixtures for any new behaviour, including the failure
  paths.
- Run `devtools::document()` if you touched roxygen comments, and commit
  the generated `man/` and `NAMESPACE`.
- Update `NEWS.md` and `dev/IMPLEMENTATION_STATUS.md`.

## Adding a source adapter

A source adapter is complete only when every item below is satisfied.
Please copy this checklist into your pull request.

Official ownership documented

Terms and access reviewed

Supported operations documented

Public endpoints identified and recorded in `dev/source-discovery/`

Registry entry added and validated

Pagination implemented

Errors handled with classed conditions

Rate limiting respected

Fixtures stored (normal, empty, paginated, missing field, changed field,
restricted, error, duplicate, provisional)

Parser implemented

Standardiser implemented

Required schema validated

Metadata preserved

Citation supported

Cache behaviour tested

Live health check available

User documentation added

Source limitations documented

No credentials committed

No access controls bypassed

## Source discovery contributions

You do not need to write R code to help. Documenting a source in
`dev/source-discovery/source-audit.md` — its landing page, whether it
exposes a machine-readable endpoint, its terms of use, its access
conditions and its stability — is the current bottleneck. Record public,
documented endpoints only, and never anything obtained from a session
token or by circumventing a control.

## Code of conduct

Please note that this project is released with a [Contributor Code of
Conduct](https://Mustapha-Wasseja.github.io/knbsdata/CODE_OF_CONDUCT.md).
By contributing you agree to abide by its terms.
