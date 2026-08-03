# Structured conditions -------------------------------------------------------
#
# Every error and warning raised by knbsdata carries a package-specific class so
# that callers can handle failures programmatically. Errors additionally inherit
# from "knbs_error", warnings from "knbs_warning".
#
# Design rule (plan section 18.3): core data problems are errors, never
# downgraded to warnings. Warnings are reserved for degraded-but-usable results.

#' Recognised knbsdata error classes
#'
#' @return A character vector of condition classes.
#' @keywords internal
#' @noRd
knbs_error_classes <- function() {
  c(
    "knbs_error_invalid_argument",
    "knbs_error_invalid_query",
    "knbs_error_ambiguous_resource",
    "knbs_error_resource_not_found",
    "knbs_error_access_restricted",
    "knbs_error_authentication_required",
    "knbs_error_source_unavailable",
    "knbs_error_rate_limited",
    "knbs_error_schema_changed",
    "knbs_error_parse_failed",
    "knbs_error_validation_failed",
    "knbs_error_download_failed",
    "knbs_error_cache_corrupt"
  )
}

#' Recognised knbsdata warning classes
#'
#' @return A character vector of condition classes.
#' @keywords internal
#' @noRd
knbs_warning_classes <- function() {
  c(
    "knbs_warning_partial_failure",
    "knbs_warning_stale_cache",
    "knbs_warning_experimental_source",
    "knbs_warning_provisional_data",
    "knbs_warning_missing_metadata",
    "knbs_warning_latest_release",
    "knbs_warning_ignored_filter"
  )
}

#' Raise a classed knbsdata error
#'
#' @param message A character vector of cli-formatted bullets.
#' @param class A single knbsdata error class, or `NULL` for a bare
#'   `knbs_error`.
#' @param ... Additional data stored on the condition object.
#' @param call The execution environment of the failing user-facing function.
#' @param .envir Environment used for cli string interpolation.
#'
#' @return Never returns; always throws.
#' @keywords internal
#' @noRd
knbs_abort <- function(message,
                       class = NULL,
                       ...,
                       call = rlang::caller_env(),
                       .envir = rlang::caller_env()) {
  check_condition_class(class, knbs_error_classes(), "error")
  cli::cli_abort(
    message,
    class = c(class, "knbs_error"),
    ...,
    call = call,
    .envir = .envir
  )
}

#' Raise a classed knbsdata warning
#'
#' @inheritParams knbs_abort
#' @param class A single knbsdata warning class, or `NULL` for a bare
#'   `knbs_warning`.
#'
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
knbs_warn <- function(message,
                      class = NULL,
                      ...,
                      call = rlang::caller_env(),
                      .envir = rlang::caller_env()) {
  check_condition_class(class, knbs_warning_classes(), "warning")
  cli::cli_warn(
    message,
    class = c(class, "knbs_warning"),
    ...,
    call = call,
    .envir = .envir
  )
}

# An unrecognised class is a package bug, not a user error, so it is reported as
# a plain internal error rather than a knbs_* condition.
check_condition_class <- function(class, allowed, what) {
  if (is.null(class)) {
    return(invisible(NULL))
  }
  if (!is.character(class) || length(class) != 1L || !class %in% allowed) {
    rlang::abort(
      paste0(
        "Internal error: unrecognised knbsdata ", what, " class.\n",
        "Add it to knbs_", what, "_classes() before using it."
      ),
      class = "knbs_error_internal"
    )
  }
  invisible(NULL)
}
