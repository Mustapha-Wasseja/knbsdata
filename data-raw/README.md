# data-raw

Reproducible build scripts for any data shipped inside the package.

Nothing here is run at install time or by users. Each script must:

- state its official source and the date it was retrieved,
- be re-runnable from scratch,
- write its output with `usethis::use_data()`,
- keep codes as character (never let `001` become `1`),
- record a vintage for anything geographic,
- and fail loudly rather than guess.

Planned scripts (see the implementation plan, section 7):

| Script | Purpose | Phase |
|---|---|---|
| `build_source_registry.R` | Regenerate or validate `inst/extdata/source-registry.yml` | 1 |
| `build_geographies.R` | County and lower-level reference codes | 6 |
| `build_indicator_registry.R` | Stable indicator ids mapped to source ids | 5 |
| `build_topic_dictionary.R` | Topic vocabulary used by search filters | 5 |

None exist yet: the official source for each still has to be identified and its
licence checked in the Phase 1 audit.
