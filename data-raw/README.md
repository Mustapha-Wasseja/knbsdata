# data-raw

Reproducible build scripts for any data shipped inside the package.

Nothing here is run at install time or by users. Each script must:

- state its official source and the date it was retrieved,
- be re-runnable from scratch,
- write its output with `usethis::use_data()`,
- keep codes as character (never let `001` become `1`),
- record a vintage for anything geographic,
- and fail loudly rather than guess.

Scripts:

| Script | Output | Source |
|---|---|---|
| `county-budget.R` | `inst/extdata/county-budget.csv`, read by `knbs_county_budget()` | Controller of Budget annual reports, FY 2013/14 to 2023/24, curated 2026-11-06 |

`county-budget.R` writes a plain CSV to `inst/extdata` rather than an `.rda`
through `usethis::use_data()`, so that the figures shipped are readable and
diffable, and are read through a function that attaches their provenance.
It runs the same curated recipes and checks as any report table; a table
that fails a check stops the build.

Planned scripts (see the implementation plan, section 7):

| Script | Purpose | Phase |
|---|---|---|
| `build_source_registry.R` | Regenerate or validate `inst/extdata/source-registry.yml` | 1 |
| `build_geographies.R` | County and lower-level reference codes | 6 |
| `build_indicator_registry.R` | Stable indicator ids mapped to source ids | 5 |
| `build_topic_dictionary.R` | Topic vocabulary used by search filters | 5 |

None exist yet: the official source for each still has to be identified and its
licence checked in the Phase 1 audit.
