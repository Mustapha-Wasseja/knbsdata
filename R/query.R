# Query objects ---------------------------------------------------------------
#
# User arguments are converted into a single normalised object before they reach
# an adapter (plan section 6.2). Normalisation matters twice over: adapters get
# one predictable shape to read, and the cache key is computed from a canonical
# form, so `list(b = 2, a = 1)` and `list(a = 1, b = 2)` are the same query.

#' Create a query
#'
#' @param resource_type One of the supported resource types.
#' @param resource_id Optional resource identifier.
#' @param filters Named list of filters; `NULL` elements are dropped.
#' @param source Source id.
#' @param release Release identifier, or `"latest"`.
#' @param language Language code.
#'
#' @return A `knbs_query` object.
#' @noRd
new_knbs_query <- function(resource_type,
                           resource_id = NULL,
                           filters = list(),
                           source = NULL,
                           release = "latest",
                           language = "en") {
  check_values(resource_type, "resource_type", knbs_resource_types())
  if (!is.null(resource_id)) check_string(resource_id, "resource_id")
  if (!is.null(source)) check_string(source, "source")
  check_string(release, "release")
  check_string(language, "language")

  if (!is.list(filters)) {
    knbs_abort(
      c("{.arg filters} must be a list.", "x" = "Got {.obj_type_friendly {filters}}."),
      class = "knbs_error_invalid_argument"
    )
  }
  filters <- compact_list(filters)
  if (length(filters) > 0L) {
    if (!rlang::is_named(filters)) {
      knbs_abort(
        c("Every filter must be named.", "i" = "For example {.code list(year = 2020)}."),
        class = "knbs_error_invalid_argument"
      )
    }
    # Sorted so that two spellings of the same query share one cache key.
    filters <- filters[order(names(filters))]
  }

  structure(
    list(
      resource_type = resource_type,
      resource_id = resource_id,
      filters = filters,
      source = source,
      release = release,
      language = language
    ),
    class = "knbs_query"
  )
}

knbs_resource_types <- function() {
  c("indicator", "survey", "variable", "publication", "geography", "classification")
}

is_knbs_query <- function(x) inherits(x, "knbs_query")

#' Canonical representation of a query, used for cache keys
#'
#' Filter values are sorted and coerced to character so that `2020` and
#' `"2020"` do not produce two cache entries for one query.
#'
#' @noRd
query_canonical <- function(query) {
  stopifnot(is_knbs_query(query))
  filters <- lapply(query$filters, function(v) sort(as.character(v)))
  list(
    resource_type = query$resource_type,
    resource_id = query$resource_id %||% "",
    filters = filters,
    source = query$source %||% "",
    release = query$release,
    language = query$language
  )
}

#' Reject filters an adapter does not support
#'
#' Silently ignoring an unsupported filter would return more data than the user
#' asked for while looking like it worked (plan section 3.6).
#'
#' @param query A `knbs_query`.
#' @param supported Character vector of supported filter names.
#' @noRd
check_supported_filters <- function(query, supported, call = rlang::caller_env()) {
  unsupported <- setdiff(names(query$filters), supported)
  if (length(unsupported) > 0L) {
    knbs_abort(
      c(
        "{cli::qty(length(unsupported))}Filter{?s} {.field {unsupported}} {?is/are} not supported here.",
        "i" = "Supported filter{?s}: {.field {supported}}."
      ),
      class = "knbs_error_invalid_query",
      call = call
    )
  }
  invisible(query)
}

#' @export
print.knbs_query <- function(x, ...) {
  knbs_cat("{.cls knbs_query} {.strong {x$resource_type}}")
  if (!is.null(x$resource_id)) knbs_cat("Resource: {.val {x$resource_id}}")
  if (!is.null(x$source)) knbs_cat("Source: {.val {x$source}}")
  knbs_cat("Release: {.val {x$release}}")
  if (length(x$filters) > 0L) {
    cli::cat_line("Filters:")
    cli::cat_line(paste0("  ", names(x$filters), " = ", vapply(
      x$filters, function(v) paste(as.character(v), collapse = ", "), character(1)
    )))
  }
  invisible(x)
}
