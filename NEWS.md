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
