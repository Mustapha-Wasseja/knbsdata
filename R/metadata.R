# Metadata --------------------------------------------------------------------
#
# Provenance travels with the data (plan section 3.3). Metadata are held in a
# documented S3 object rather than a loose bag of attributes, so that every
# object carries the same fields whether or not the source supplied them.

#' Create a metadata object
#'
#' Unsupplied fields are `NULL` rather than absent, so downstream code can rely
#' on the shape.
#'
#' @param ... Named metadata fields; see the object's own field list.
#' @param raw The unmodified source payload, kept for debugging and for fields
#'   the package does not yet standardise.
#'
#' @return A `knbs_metadata` object.
#' @noRd
new_knbs_metadata <- function(..., raw = NULL) {
  supplied <- rlang::list2(...)
  if (length(supplied) > 0L && !rlang::is_named(supplied)) {
    knbs_abort("Every metadata field must be named.",
               class = "knbs_error_invalid_argument")
  }
  unknown <- setdiff(names(supplied), names(knbs_metadata_fields()))
  if (length(unknown) > 0L) {
    knbs_abort(
      c(
        "{cli::qty(length(unknown))}Unknown metadata field{?s}: {.field {unknown}}.",
        "i" = "Known fields: {.field {names(knbs_metadata_fields())}}."
      ),
      class = "knbs_error_invalid_argument"
    )
  }

  # Assign through `[` with a wrapped value: `out$field <- NULL` would delete the
  # field rather than leave it empty, and the object's shape is part of its
  # contract.
  out <- knbs_metadata_fields()
  for (field in names(supplied)) {
    out[field] <- list(supplied[[field]])
  }
  out["retrieved_at"] <- list(out$retrieved_at %||% Sys.time())
  out["package_version"] <- list(
    out$package_version %||% as.character(utils::packageVersion("knbsdata"))
  )
  out["raw"] <- list(raw)

  structure(out, class = "knbs_metadata")
}

# The canonical field list (plan section 9.8). Order is the print order.
knbs_metadata_fields <- function() {
  list(
    title = NULL,
    resource_id = NULL,
    resource_type = NULL,
    source_id = NULL,
    source_name = NULL,
    source_url = NULL,
    producer = "Kenya National Bureau of Statistics",
    release_date = NULL,
    reference_period = NULL,
    retrieved_at = NULL,
    version = NULL,
    revision_status = NULL,
    unit = NULL,
    frequency = NULL,
    geographic_level = NULL,
    licence = NULL,
    access = NULL,
    citation = NULL,
    checksum = NULL,
    package_version = NULL,
    notes = NULL,
    raw = NULL
  )
}

is_knbs_metadata <- function(x) inherits(x, "knbs_metadata")

#' Inspect the provenance of a knbsdata object
#'
#' Returns the metadata attached to an object: where it came from, when it was
#' retrieved, which release it represents and how it should be cited.
#'
#' @param x A knbsdata object.
#' @param ... Passed to methods.
#'
#' @return A `knbs_metadata` object.
#'
#' @seealso [knbs_cite()]
#'
#' @examples
#' # Metadata accompany every object the package returns.
#' @export
knbs_metadata <- function(x, ...) {
  UseMethod("knbs_metadata")
}

#' @export
knbs_metadata.knbs_metadata <- function(x, ...) x

#' @export
knbs_metadata.knbs_data <- function(x, ...) {
  meta <- attr(x, "knbs_metadata", exact = TRUE)
  if (is.null(meta)) {
    knbs_abort(
      c(
        "This object has lost its metadata.",
        "i" = "Some transformations drop attributes; call {.fn knbs_metadata} before transforming."
      ),
      class = "knbs_error_validation_failed"
    )
  }
  meta
}

#' @export
knbs_metadata.default <- function(x, ...) {
  knbs_abort(
    c(
      "{.fn knbs_metadata} does not know how to describe {.obj_type_friendly {x}}.",
      "i" = "It works on objects returned by knbsdata."
    ),
    class = "knbs_error_invalid_argument"
  )
}

#' @export
print.knbs_metadata <- function(x, ...) {
  knbs_cat("{.cls knbs_metadata}")
  shown <- c(
    "title", "resource_id", "resource_type", "producer", "source_name",
    "source_id", "source_url", "release_date", "reference_period", "version",
    "revision_status", "unit", "frequency", "geographic_level", "access",
    "licence", "checksum", "retrieved_at", "package_version"
  )
  for (field in shown) {
    value <- x[[field]]
    if (is.null(value) || (length(value) == 1L && is.na(value))) {
      next
    }
    knbs_cat("{.field {field}}: {format_metadata_value(value)}")
  }
  if (!is.null(x$notes)) {
    knbs_cat("{.field notes}: {format_metadata_value(x$notes)}")
  }
  if (!is.null(x$raw)) {
    cli::cat_line(cli::col_grey("Raw source payload retained in $raw."))
  }
  invisible(x)
}

format_metadata_value <- function(value) {
  if (inherits(value, "POSIXt")) {
    return(format(value, "%Y-%m-%d %H:%M:%S %Z"))
  }
  if (inherits(value, "Date")) {
    return(format(value, "%Y-%m-%d"))
  }
  paste(as.character(value), collapse = "; ")
}
