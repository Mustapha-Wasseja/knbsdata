# Adapter contract ------------------------------------------------------------
#
# Every source is reached through the same small set of generics (plan section
# 6.4). Dispatch is on the source object, whose class comes from the `adapter`
# field in the registry, so adding a source means adding methods and a registry
# entry — never a branch in a user-facing function.

#' Build a source object from the registry
#'
#' @param source_id A registered source id.
#'
#' @return An object of class `knbs_source_<adapter>` / `knbs_source`.
#' @noRd
knbs_source <- function(source_id, call = rlang::caller_env()) {
  check_string(source_id, "source_id")
  sources <- read_source_registry()$sources
  hit <- Filter(function(s) identical(s$source_id, source_id), sources)

  if (length(hit) == 0L) {
    knbs_abort(
      c(
        "Unknown source {.val {source_id}}.",
        "i" = "Registered sources: {.val {vapply(sources, function(s) s$source_id, character(1))}}.",
        "i" = "See {.fn knbs_sources}."
      ),
      class = "knbs_error_resource_not_found",
      call = call
    )
  }

  src <- hit[[1]]
  structure(src, class = c(paste0("knbs_source_", src$adapter), "knbs_source"))
}

#' Does a source declare an operation?
#' @noRd
source_supports <- function(source, operation) {
  operation %in% as.character(source$operations)
}

#' Require that a source declares an operation
#'
#' The registry is the authority on what a source may be asked to do. KeNADA,
#' for instance, deliberately does not declare `download_public_files` because
#' its downloads are gated (source audit F-03); this is where that declaration
#' is enforced rather than merely documented.
#'
#' @noRd
check_operation <- function(source, operation, call = rlang::caller_env()) {
  if (source_supports(source, operation)) {
    return(invisible(source))
  }
  knbs_abort(
    c(
      "Source {.val {source$source_id}} does not support {.field {operation}}.",
      "i" = "It declares: {.field {as.character(source$operations)}}.",
      "i" = "See {.fn knbs_sources} for what each source can do."
    ),
    class = "knbs_error_invalid_query",
    call = call
  )
}

#' Refuse to act on a source that has not been verified
#'
#' A source still at stability `discovery` has an unverified endpoint. Calling it
#' would mean guessing, which the package does not do.
#'
#' @noRd
check_source_verified <- function(source, call = rlang::caller_env()) {
  if (!identical(source$stability, "discovery")) {
    return(invisible(source))
  }
  knbs_abort(
    c(
      "Source {.val {source$source_id}} has not been verified yet.",
      "x" = "Its endpoint is still a placeholder, so there is nothing to call.",
      "i" = "Progress is tracked in the package's source-discovery audit."
    ),
    class = "knbs_error_source_unavailable",
    call = call
  )
}

# Generics --------------------------------------------------------------------

#' Search a source
#' @noRd
source_search <- function(source, query, ...) UseMethod("source_search")

#' Retrieve resource metadata from a source
#' @noRd
source_metadata <- function(source, resource_id, ...) UseMethod("source_metadata")

#' Retrieve data from a source
#' @noRd
source_fetch <- function(source, query, ...) UseMethod("source_fetch")

#' List the files belonging to a resource
#' @noRd
source_files <- function(source, resource_id, ...) UseMethod("source_files")

#' List the variables described by a resource
#' @noRd
source_variables <- function(source, resource_id, ...) UseMethod("source_variables")

#' Retrieve one variable's full record
#'
#' Optional: not every source documents variables individually, so this is not
#' part of the contract every adapter must satisfy.
#'
#' @noRd
source_variable_detail <- function(source, resource_id, variable_id, ...) {
  UseMethod("source_variable_detail")
}

#' Retrieve geographic reference codes from a source
#' @noRd
source_geographies <- function(source, ...) UseMethod("source_geographies")

#' Retrieve retail commodity prices from a source
#' @noRd
source_retail_prices <- function(source, ...) UseMethod("source_retail_prices")

#' Check whether a source is answering
#' @noRd
source_health <- function(source, ...) UseMethod("source_health")

# Defaults --------------------------------------------------------------------
#
# A missing method is a package bug, not a user error: the registry named an
# adapter that does not implement the contract.

adapter_not_implemented <- function(source, generic, call = rlang::caller_env()) {
  knbs_abort(
    c(
      "The {.val {source$adapter}} adapter does not implement {.fn {generic}}.",
      "i" = "Every adapter must implement the operations its registry entry declares."
    ),
    class = "knbs_error_invalid_argument",
    call = call
  )
}

#' @export
source_search.default <- function(source, query, ...) {
  adapter_not_implemented(source, "source_search")
}

#' @export
source_metadata.default <- function(source, resource_id, ...) {
  adapter_not_implemented(source, "source_metadata")
}

#' @export
source_fetch.default <- function(source, query, ...) {
  adapter_not_implemented(source, "source_fetch")
}

#' @export
source_files.default <- function(source, resource_id, ...) {
  adapter_not_implemented(source, "source_files")
}

#' @export
source_variables.default <- function(source, resource_id, ...) {
  adapter_not_implemented(source, "source_variables")
}

#' @export
source_variable_detail.default <- function(source, resource_id, variable_id, ...) {
  adapter_not_implemented(source, "source_variable_detail")
}

#' @export
source_geographies.default <- function(source, ...) {
  adapter_not_implemented(source, "source_geographies")
}

#' @export
source_retail_prices.default <- function(source, ...) {
  adapter_not_implemented(source, "source_retail_prices")
}

#' @export
source_health.default <- function(source, ...) {
  adapter_not_implemented(source, "source_health")
}

#' The generics an adapter must satisfy
#'
#' Used by the adapter contract test.
#'
#' @noRd
adapter_contract <- function() {
  c(
    "source_search", "source_metadata", "source_fetch", "source_files",
    "source_variables", "source_health"
  )
}

#' Which sources can carry out an operation?
#'
#' Discovery-stability sources are excluded: their endpoints are unverified, so
#' there is nothing to call. The offline fixture source is excluded for the same
#' reason, which keeps it out of the public functions.
#'
#' @param operation Operation name.
#' @param source Optional explicit source id.
#' @noRd
resolve_source <- function(operation, source = NULL, call = rlang::caller_env()) {
  if (!is.null(source)) {
    src <- knbs_source(source, call = call)
    check_operation(src, operation, call = call)
    check_source_verified(src, call = call)
    return(src)
  }

  sources <- read_source_registry()$sources
  usable <- Filter(
    function(s) {
      operation %in% as.character(s$operations) && !identical(s$stability, "discovery")
    },
    sources
  )

  if (length(usable) == 0L) {
    knbs_abort(
      c(
        "No verified source supports {.field {operation}} yet.",
        "i" = "See {.fn knbs_sources} for what each source can do.",
        "i" = "Sources stay unusable until their endpoints are verified."
      ),
      class = "knbs_error_source_unavailable",
      call = call
    )
  }
  knbs_source(usable[[1]]$source_id, call = call)
}

#' Which generics have a method for this adapter?
#'
#' @param adapter Adapter name, for example `"fake"`.
#' @return A named logical vector.
#' @noRd
adapter_methods <- function(adapter) {
  vapply(
    adapter_contract(),
    function(generic) {
      !is.null(utils::getS3method(generic, paste0("knbs_source_", adapter),
                                  optional = TRUE, envir = asNamespace("knbsdata")))
    },
    logical(1)
  )
}

# The standard catalogue columns every source_search() must return
# (plan section 5.2).
knbs_catalogue_columns <- function() {
  c(
    "resource_id", "resource_type", "title", "description", "topic", "frequency",
    "geography", "reference_start", "reference_end", "release_date", "access",
    "source_id", "source_url"
  )
}
