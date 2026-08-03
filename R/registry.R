# Source registry -------------------------------------------------------------
#
# Every supported source is declared in inst/extdata/source-registry.yml. The
# registry is the single place where source ownership, access conditions and
# supported operations are recorded (plan section 12). It is read from disk on
# demand rather than cached in the namespace, so edits during development take
# effect immediately and no hidden state accumulates.

# Controlled vocabularies for the source registry.
#' @noRd
knbs_known_operations <- function() {
  c(
    "search_surveys",
    "survey_metadata",
    "variables",
    "files",
    "download_public_files",
    "search_publications",
    "publication_metadata",
    "download_publication",
    "list_indicators",
    "get_indicator",
    "indicator_metadata",
    "geographies",
    "classifications",
    "boundaries"
  )
}

#' @noRd
knbs_stability_levels <- function() {
  c("discovery", "experimental", "beta", "stable", "deprecated")
}

#' @noRd
knbs_authentication_types <- function() {
  c("none", "source_defined", "token", "oauth", "manual_process")
}

#' @noRd
knbs_source_types <- function() {
  c(
    "survey_catalogue",
    "publication_catalogue",
    "indicator_portal",
    "reference_data",
    "static_files",
    "fake"
  )
}

# Base URLs are deliberately unset until the Phase 1 source-discovery audit
# verifies them. The validator enforces that a placeholder source cannot claim a
# stability level above "discovery".
knbs_url_placeholder <- function() {
  "PLACEHOLDER_TO_VERIFY"
}

knbs_registry_path <- function() {
  system.file("extdata", "source-registry.yml", package = "knbsdata", mustWork = TRUE)
}

#' Read and validate the source registry
#'
#' @param path Path to a registry YAML file.
#'
#' @return A list with elements `schema_version` and `sources`.
#' @keywords internal
#' @noRd
read_source_registry <- function(path = knbs_registry_path()) {
  if (!file.exists(path)) {
    knbs_abort(
      c(
        "Source registry not found.",
        "x" = "Expected a YAML file at {.path {path}}."
      ),
      class = "knbs_error_validation_failed"
    )
  }
  registry <- tryCatch(
    yaml::read_yaml(path),
    error = function(cnd) {
      knbs_abort(
        c(
          "Could not parse the source registry.",
          "x" = "{conditionMessage(cnd)}",
          "i" = "File: {.path {path}}."
        ),
        class = "knbs_error_parse_failed"
      )
    }
  )
  validate_source_registry(registry, path = path)
  registry
}

#' Validate a source registry
#'
#' Enforces the rules in plan section 12.2.
#'
#' @param registry A parsed registry list.
#' @param path Path reported in error messages.
#'
#' @return `registry`, invisibly.
#' @keywords internal
#' @noRd
validate_source_registry <- function(registry, path = "<registry>") {
  # `label` identifies the offending source in the error header, so individual
  # bullets do not have to repeat it.
  bad <- function(label = NULL, ...) {
    header <- if (is.null(label)) {
      "Invalid source registry at {.path {path}}."
    } else {
      "Invalid source registry at {.path {path}}: source {.val {label}}."
    }
    knbs_abort(
      c(header, ...),
      class = "knbs_error_validation_failed",
      call = rlang::caller_env(2)
    )
  }

  if (!is.list(registry) || !all(c("schema_version", "sources") %in% names(registry))) {
    bad(NULL, "x" = "The registry must contain {.field schema_version} and {.field sources}.")
  }
  if (!identical(as.integer(registry$schema_version), 1L)) {
    bad(NULL, "x" = "Unsupported {.field schema_version}: {.val {registry$schema_version}}.")
  }
  sources <- registry$sources
  if (!is.list(sources) || length(sources) == 0L) {
    bad(NULL, "x" = "{.field sources} must be a non-empty list.")
  }

  required <- c(
    "source_id", "source_name", "owner", "source_type",
    "base_url", "adapter", "operations", "authentication", "stability"
  )

  ids <- character(0)
  for (i in seq_along(sources)) {
    src <- sources[[i]]
    label <- src$source_id %||% paste0("sources[[", i, "]]")

    missing_fields <- setdiff(required, names(src))
    if (length(missing_fields) > 0L) {
      bad(
        label,
        "x" = "Missing required {cli::qty(length(missing_fields))}field{?s}: {.field {missing_fields}}."
      )
    }
    if (!is_string(src$source_id) || !grepl("^[a-z][a-z0-9_]*$", src$source_id)) {
      bad(label, "x" = "Source id {.val {src$source_id}} must be lowercase snake case.")
    }
    if (src$source_id %in% ids) {
      bad(label, "x" = "Duplicate source id {.val {src$source_id}}.")
    }
    ids <- c(ids, src$source_id)

    if (!is_string(src$source_type) || !src$source_type %in% knbs_source_types()) {
      bad(
        label,
        "x" = "Unrecognised {.field source_type} {.val {src$source_type}}.",
        "i" = "Allowed: {.val {knbs_source_types()}}."
      )
    }
    if (!is.character(src$operations) || length(src$operations) == 0L) {
      bad(label, "x" = "At least one {.field operation} must be declared.")
    }
    unknown_ops <- setdiff(src$operations, knbs_known_operations())
    if (length(unknown_ops) > 0L) {
      bad(
        label,
        "x" = "Unrecognised operation{?s} {.val {unknown_ops}}.",
        "i" = "Allowed: {.val {knbs_known_operations()}}."
      )
    }
    if (!is_string(src$stability) || !src$stability %in% knbs_stability_levels()) {
      bad(
        label,
        "x" = "Unrecognised {.field stability} {.val {src$stability}}.",
        "i" = "Allowed: {.val {knbs_stability_levels()}}."
      )
    }
    if (!is_string(src$authentication) || !src$authentication %in% knbs_authentication_types()) {
      bad(
        label,
        "x" = "Unrecognised {.field authentication} {.val {src$authentication}}.",
        "i" = "Allowed: {.val {knbs_authentication_types()}}."
      )
    }
    if (!is_string(src$adapter)) {
      bad(label, "x" = "An {.field adapter} must be named.")
    }
    if (!is_string(src$base_url)) {
      bad(label, "x" = "A single {.field base_url} is required.")
    }

    is_placeholder <- identical(src$base_url, knbs_url_placeholder())
    if (!is_placeholder && !grepl("^https://", src$base_url)) {
      bad(
        label,
        "x" = "{.field base_url} must use HTTPS.",
        "i" = "Got {.val {src$base_url}}."
      )
    }
    if (is_placeholder && !identical(src$stability, "discovery")) {
      bad(
        label,
        "x" = "Unverified {.field base_url} but stability {.val {src$stability}}.",
        "i" = "Verify the endpoint in the source-discovery audit before promoting it."
      )
    }

    last_verified <- src$last_verified
    if (!is.null(last_verified)) {
      parsed <- suppressWarnings(as.Date(as.character(last_verified), format = "%Y-%m-%d"))
      if (is.na(parsed)) {
        bad(label, "x" = "Invalid {.field last_verified}: {.val {last_verified}}.")
      }
    }
  }

  invisible(registry)
}

#' Supported KNBS sources
#'
#' Lists the sources declared in the package source registry, together with the
#' operations each one supports and how far it has been verified. No network
#' request is made; this reports what the package believes about each source.
#'
#' Sources whose `base_url` has not yet been verified are shown with stability
#' `"discovery"` and are not usable for retrieval. Endpoint verification is the
#' subject of the source-discovery audit in `dev/source-discovery/`.
#'
#' @param operation Optional. Keep only sources supporting this operation, for
#'   example `"search_surveys"` or `"get_indicator"`.
#' @param status Optional. Keep only sources at these stability levels: one or
#'   more of `"discovery"`, `"experimental"`, `"beta"`, `"stable"` or
#'   `"deprecated"`.
#'
#' @return A [tibble][tibble::tibble] with one row per source and columns
#'   `source_id`, `source_name`, `source_type`, `operations` (a list-column),
#'   `stability`, `authentication`, `last_verified` and `base_url`.
#'
#' @examples
#' knbs_sources()
#' knbs_sources(operation = "search_surveys")
#' @export
knbs_sources <- function(operation = NULL, status = NULL) {
  if (!is.null(operation)) {
    check_values(operation, "operation", knbs_known_operations())
  }
  if (!is.null(status)) {
    check_values(status, "status", knbs_stability_levels())
  }

  sources <- read_source_registry()$sources

  chr <- function(field) {
    vapply(sources, function(s) as.character(s[[field]] %||% NA_character_), character(1))
  }

  out <- tibble::tibble(
    source_id = chr("source_id"),
    source_name = chr("source_name"),
    source_type = chr("source_type"),
    operations = lapply(sources, function(s) as.character(s$operations)),
    stability = chr("stability"),
    authentication = chr("authentication"),
    last_verified = as.Date(vapply(
      sources,
      function(s) as.character(s$last_verified %||% NA_character_),
      character(1)
    )),
    base_url = chr("base_url")
  )

  if (!is.null(operation)) {
    keep <- vapply(out$operations, function(ops) all(operation %in% ops), logical(1))
    out <- out[keep, , drop = FALSE]
  }
  if (!is.null(status)) {
    out <- out[out$stability %in% status, , drop = FALSE]
  }

  out
}
