# Source health ---------------------------------------------------------------
#
# The only function in the package that contacts a source without being asked
# for data — and it does not do that either unless `live = TRUE` (plan section
# 11.18). The default follows `interactive()`, so package checks, CRAN and CI
# get the offline report and never depend on a live service.

knbs_status_columns <- function() {
  c("source_id", "operation", "status", "http_status", "response_time_ms",
    "checked_at", "message")
}

knbs_status_values <- function() {
  c("ok", "unavailable", "unverified", "not_checked")
}

#' Report on the health of supported sources
#'
#' Answers two different questions depending on `live`. With `live = FALSE` it
#' reports what the package knows about each source without contacting anything.
#' With `live = TRUE` it asks each verified source to answer a small request and
#' reports what happened.
#'
#' The `status` column is one of:
#'
#' \describe{
#'   \item{`ok`}{The source answered.}
#'   \item{`unavailable`}{The source was contacted and did not answer usefully.
#'     The `message` column says why.}
#'   \item{`unverified`}{The source's endpoint has not been verified, so there
#'     is nothing to contact. It is never checked live.}
#'   \item{`not_checked`}{The source could have been checked, but `live` was
#'     `FALSE`.}
#' }
#'
#' @param source Source ids to check. Defaults to every registered source.
#' @param live Whether to contact the sources. Defaults to [interactive()], so
#'   that automated runs never depend on a live service.
#' @param timeout Request timeout in seconds, applied only to this call.
#'
#' @return A [tibble][tibble::tibble] with one row per source and columns
#'   `source_id`, `operation`, `status`, `http_status`, `response_time_ms`,
#'   `checked_at` and `message`.
#'
#' @seealso [knbs_sources()] for what each source supports.
#'
#' @examples
#' # Offline: reports what the registry knows, contacts nothing.
#' knbs_status(live = FALSE)
#' @examplesIf interactive()
#' # Contacts each verified source.
#' knbs_status(live = TRUE)
#' @export
knbs_status <- function(source = NULL, live = interactive(), timeout = 10) {
  check_bool(live, "live")
  check_number(timeout, "timeout", min = 0)

  sources <- read_source_registry()$sources
  if (!is.null(source)) {
    check_character(source, "source")
    # Validate each id through knbs_source(), so an unknown one is reported the
    # same way it would be anywhere else.
    for (id in source) knbs_source(id)
    sources <- Filter(function(s) s$source_id %in% source, sources)
  }

  if (live) {
    old <- options(knbsdata.timeout = timeout)
    on.exit(options(old), add = TRUE)
  }

  rows <- lapply(sources, status_row, live = live)
  do.call(rbind, rows)
}

#' Status for a single source
#' @noRd
status_row <- function(src, live) {
  source <- knbs_source(src$source_id)
  operation <- as.character(src$operations)[[1]]

  # An unverified source has a placeholder endpoint: there is nothing to
  # contact, and pretending to check it would be theatre.
  if (identical(src$stability, "discovery")) {
    return(status_tibble(
      src$source_id, operation, "unverified",
      message = "Endpoint not verified; nothing to contact."
    ))
  }
  if (!live) {
    return(status_tibble(
      src$source_id, operation, "not_checked",
      message = "Set live = TRUE to contact the source."
    ))
  }

  started <- Sys.time()
  health <- tryCatch(
    source_health(source),
    knbs_error = function(cnd) {
      status_tibble(
        src$source_id, operation, "unavailable",
        http_status = cnd$http_status %||% NA_integer_,
        response_time_ms = as.numeric(difftime(Sys.time(), started, units = "secs")) * 1000,
        checked_at = started,
        message = conditionMessage(cnd)
      )
    }
  )
  normalise_status(health, src$source_id, operation)
}

#' Coerce an adapter's health report into the documented shape
#'
#' Adapters return what they can. This makes sure the caller always gets the
#' same columns in the same types, whatever the adapter supplied.
#'
#' @noRd
normalise_status <- function(health, source_id, operation) {
  if (!is.data.frame(health) || nrow(health) == 0L) {
    return(status_tibble(
      source_id, operation, "unavailable",
      message = "The adapter returned no health information."
    ))
  }
  # Read columns by name rather than with `$`, which warns on a tibble that does
  # not have them. An adapter is allowed to report less than the full shape.
  field <- function(name, default) {
    if (!name %in% names(health)) default else health[[name]][[1]]
  }

  status <- as.character(field("status", "unavailable"))
  if (!status %in% knbs_status_values()) {
    status <- "unavailable"
  }

  status_tibble(
    source_id = source_id,
    operation = as.character(field("operation", operation)),
    status = status,
    http_status = as.integer(field("http_status", NA_integer_)),
    response_time_ms = as.numeric(field("response_time_ms", NA_real_)),
    checked_at = field("checked_at", Sys.time()),
    message = as.character(field("message", NA_character_))
  )
}

status_tibble <- function(source_id,
                          operation,
                          status,
                          http_status = NA_integer_,
                          response_time_ms = NA_real_,
                          checked_at = Sys.time(),
                          message = NA_character_) {
  tibble::tibble(
    source_id = source_id,
    operation = operation,
    status = status,
    http_status = http_status,
    response_time_ms = response_time_ms,
    checked_at = checked_at,
    message = message
  )
}
