# knbsdata 0.0.0.9000

Phase 0: repository bootstrap. No data retrieval is implemented yet and no
function makes a network request.

* Package skeleton, MIT licence, `testthat` edition 3, `roxygen2`, GitHub
  Actions (R CMD check, lint, pkgdown, weekly source monitor) and pkgdown
  configuration.
* Added package options (`knbs_options()`, `knbs_option()`), backed by ordinary
  R options under the `knbsdata.` prefix.
* Added the structured condition system (`knbs_error_*` and `knbs_warning_*`
  classes) used for all package errors and warnings.
* Added the YAML source registry format, its validator, and `knbs_sources()`.
  All source base URLs are placeholders pending the Phase 1 source-discovery
  audit; the validator refuses to let an unverified source claim a stability
  level above `discovery`.
