# knbsdata 0.0.0.9000

Early development. No KNBS data retrieval is exposed yet: the package has
infrastructure and one audited source contract, but no public retrieval
functions.

## Phase 2: core infrastructure

* HTTP layer (`knbs_request()`, `knbs_perform()`) on httr2, with a transparent
  user agent, configurable timeout, retries limited to genuinely transient
  failures, and every HTTP status mapped onto a specific `knbs_error_*` class.
* Login gates that arrive as a `Refresh` header rather than a 3xx redirect are
  detected and raised as `knbs_error_authentication_required`. KeNADA answers
  gated requests that way, and without this check an unwary client reads the
  gate as a successful empty response.
* Cache (`knbs_cache_dir()`, `knbs_cache_info()`, `knbs_cache_clear()`,
  `knbs_cache_prune()`) keyed on source, operation, normalised query, release
  and parser/schema version, with checksum verification and atomic writes.
  Damaged entries are discarded and refetched rather than returned.
* Query objects, normalised so that equivalent queries share a cache key, and
  rejecting unsupported filters rather than ignoring them.
* Metadata (`knbs_metadata()`) and citation (`knbs_cite()`, in plain, BibTeX and
  RIS) built from provenance, with a source-supplied citation taking precedence.
* `knbs_data` tibble subclass carrying provenance through row subsetting, with
  print and summary methods.
* Adapter contract (`source_search()`, `source_metadata()`, `source_fetch()`,
  `source_files()`, `source_health()`) dispatching on the adapter named in the
  registry, and enforcing that a source is only asked to do what it declares.
* An offline `fake` adapter serving package fixtures, proving the whole path
  from search to citation without a network.

## Phase 1: source discovery

* Audited the Kenya National Data Archive: its NADA JSON API is enabled and
  needs no credentials for study search, study metadata, variables and
  data-file listings. Registered as `experimental` with verified endpoints.
* Established that KeNADA microdata downloads are gated behind a login, so the
  registry entry does not declare a download operation and the package will not
  fetch them.
* Publications, indicators and geography could not be audited: `knbs.or.ke` was
  unavailable throughout, and separately serves an incomplete TLS chain.

## Phase 0: repository bootstrap

* Package skeleton, MIT licence, `testthat` edition 3, `roxygen2`, GitHub
  Actions (R CMD check, lint, pkgdown, weekly source monitor) and pkgdown
  configuration.
* Package options (`knbs_options()`, `knbs_option()`) backed by ordinary R
  options under the `knbsdata.` prefix.
* The structured condition system (`knbs_error_*` and `knbs_warning_*` classes)
  used for all package errors and warnings.
* The YAML source registry, its validator, and `knbs_sources()`.
