# knbs_data and friends -------------------------------------------------------
#
# A tibble subclass carrying provenance (plan section 10). Subclasses such as
# knbs_indicator and knbs_catalogue differ only in their class vector and how
# they print; the data contract is the same.

#' Construct a knbs_data object
#'
#' @param x A tibble.
#' @param metadata A `knbs_metadata` object.
#' @param class Optional subclass names, outermost first.
#'
#' @return An object inheriting from `knbs_data` and `tbl_df`.
#' @noRd
new_knbs_data <- function(x, metadata, class = character()) {
  if (!tibble::is_tibble(x)) {
    x <- tibble::as_tibble(x)
  }
  if (!is_knbs_metadata(metadata)) {
    knbs_abort(
      c("{.arg metadata} must be a {.cls knbs_metadata} object.",
        "x" = "Got {.obj_type_friendly {metadata}}."),
      class = "knbs_error_invalid_argument"
    )
  }
  structure(
    x,
    knbs_metadata = metadata,
    class = c(class, "knbs_data", class(x))
  )
}

new_knbs_catalogue <- function(x, metadata) {
  new_knbs_data(x, metadata, class = "knbs_catalogue")
}

is_knbs_data <- function(x) inherits(x, "knbs_data")

#' @export
print.knbs_data <- function(x, ...) {
  meta <- attr(x, "knbs_metadata", exact = TRUE)
  knbs_cat("{.cls {class(x)[[1]]}}")
  if (!is.null(meta)) {
    if (!is.null(meta$title)) knbs_cat("Title: {meta$title}")
    if (!is.null(meta$resource_id)) knbs_cat("Resource: {.val {meta$resource_id}}")
    knbs_cat("Rows: {nrow(x)}")
    if (!is.null(meta$reference_period)) {
      knbs_cat("Period: {format_metadata_value(meta$reference_period)}")
    }
    if (!is.null(meta$release_date)) {
      knbs_cat("Release: {format_metadata_value(meta$release_date)}")
    }
    if (!is.null(meta$producer)) knbs_cat("Source: {meta$producer}")
    if (identical(meta$access, "restricted")) {
      cli::cat_line(cli::col_yellow("Access: restricted - metadata only"))
    }
  } else {
    cli::cat_line(cli::col_yellow("Metadata were dropped by an earlier operation."))
  }
  cat("\n")
  print(tibble::as_tibble(x), ...)
  invisible(x)
}

#' @export
summary.knbs_data <- function(object, ...) {
  meta <- attr(object, "knbs_metadata", exact = TRUE)
  structure(
    list(
      class = class(object)[[1]],
      rows = nrow(object),
      cols = ncol(object),
      columns = names(object),
      metadata = meta
    ),
    class = "summary.knbs_data"
  )
}

#' @export
print.summary.knbs_data <- function(x, ...) {
  knbs_cat("{.cls {x$class}}: {x$rows} row{?s} x {x$cols} column{?s}")
  knbs_cat("Columns: {.field {x$columns}}")
  if (!is.null(x$metadata)) {
    cat("\n")
    print(x$metadata)
  }
  invisible(x)
}

#' @export
as_tibble.knbs_data <- function(x, ...) {
  attr(x, "knbs_metadata") <- NULL
  class(x) <- setdiff(class(x), c("knbs_data", "knbs_catalogue", "knbs_indicator"))
  tibble::new_tibble(x, nrow = nrow(x))
}

#' Restore metadata after vctrs operations
#'
#' Most dplyr verbs round-trip through vctrs, so re-attaching the metadata here
#' keeps provenance through `filter()`, `arrange()`, `slice()` and friends.
#'
#' This is deliberately not a guarantee. An operation that combines two objects,
#' or aggregates rows, produces something whose official identity is no longer
#' the same as the original, and pretending otherwise would be worse than losing
#' the attribute (plan section 10.3).
#'
#' @param x The bare data being restored.
#' @param to The object whose class and attributes should be restored.
#' @param ... Passed to methods.
#' @return An object of the same class as `to`.
#' @keywords internal
#' @export
vec_restore.knbs_data <- function(x, to, ...) {
  out <- NextMethod()
  attr(out, "knbs_metadata") <- attr(to, "knbs_metadata", exact = TRUE)
  class(out) <- class(to)
  out
}
