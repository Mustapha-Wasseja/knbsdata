# Package options -------------------------------------------------------------
#
# Options are ordinary R options under the "knbsdata." prefix (plan section
# 11.20). Nothing is persisted to disk and no mutable state is kept in the
# package namespace, so a session's configuration is always inspectable with
# options().

knbs_option_defaults <- function() {
  list(
    cache = TRUE,
    cache_dir = NULL,
    timeout = 30,
    retries = 3,
    user_agent = NULL,
    quiet = FALSE
  )
}

knbs_option_names <- function() {
  names(knbs_option_defaults())
}

#' Get a knbsdata option
#'
#' Retrieves a single package option. Options are stored as ordinary R options
#' prefixed with `knbsdata.`, so `knbs_option("timeout")` reads
#' `getOption("knbsdata.timeout")` and falls back to the package default.
#'
#' @param name Option name, without the `knbsdata.` prefix. One of `"cache"`,
#'   `"cache_dir"`, `"timeout"`, `"retries"`, `"user_agent"` or `"quiet"`.
#'
#' @return The option value. `NULL` for options that are unset and have no
#'   default (`cache_dir`, `user_agent`).
#'
#' @seealso [knbs_options()] to set options.
#'
#' @examples
#' knbs_option("timeout")
#' knbs_option("cache")
#' @export
knbs_option <- function(name) {
  check_string(name, "name")
  defaults <- knbs_option_defaults()
  if (!name %in% names(defaults)) {
    knbs_abort(
      c(
        "Unknown knbsdata option {.val {name}}.",
        "i" = "Available options: {.val {names(defaults)}}."
      ),
      class = "knbs_error_invalid_argument"
    )
  }
  getOption(paste0("knbsdata.", name), default = defaults[[name]])
}

#' Set knbsdata options
#'
#' Sets package options for the current session. Arguments left as `NULL` are
#' unchanged. Called with no arguments, returns the current values.
#'
#' To restore an option to its default, use [options()] directly, for example
#' `options(knbsdata.cache_dir = NULL)`, or [withr::with_options()] for a
#' temporary change.
#'
#' @param cache `TRUE` or `FALSE`. Whether retrieval functions may read from and
#'   write to the local cache.
#' @param cache_dir Path to the cache directory. `NULL` uses
#'   `tools::R_user_dir("knbsdata", "cache")`.
#' @param timeout Request timeout in seconds.
#' @param retries Maximum number of retries for retryable HTTP failures.
#' @param user_agent Override for the HTTP user agent string. `NULL` uses a
#'   transparent default identifying the package and version.
#' @param quiet `TRUE` or `FALSE`. Whether to suppress progress messages.
#'
#' @return When setting, the previous values as a named list, invisibly. When
#'   called with no arguments, the current values as a named list.
#'
#' @seealso [knbs_option()] to read a single option.
#'
#' @examples
#' old <- knbs_options(timeout = 60)
#' knbs_option("timeout")
#'
#' # restore
#' knbs_options(timeout = old$timeout)
#' @export
knbs_options <- function(cache = NULL,
                         cache_dir = NULL,
                         timeout = NULL,
                         retries = NULL,
                         user_agent = NULL,
                         quiet = NULL) {
  new <- compact_list(list(
    cache = cache,
    cache_dir = cache_dir,
    timeout = timeout,
    retries = retries,
    user_agent = user_agent,
    quiet = quiet
  ))

  if (length(new) == 0L) {
    values <- lapply(knbs_option_names(), knbs_option)
    names(values) <- knbs_option_names()
    return(values)
  }

  if (!is.null(cache)) check_bool(cache, "cache")
  if (!is.null(cache_dir)) check_string(cache_dir, "cache_dir")
  if (!is.null(timeout)) check_number(timeout, "timeout", min = 0)
  if (!is.null(retries)) check_number(retries, "retries", min = 0)
  if (!is.null(user_agent)) check_string(user_agent, "user_agent")
  if (!is.null(quiet)) check_bool(quiet, "quiet")

  old <- lapply(names(new), knbs_option)
  names(old) <- names(new)

  names(new) <- paste0("knbsdata.", names(new))
  options(new)

  invisible(old)
}
