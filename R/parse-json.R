# JSON parsing ----------------------------------------------------------------
#
# Parsing is kept separate from retrieval so that adapters can be tested against
# stored fixtures without a network (plan sections 16.1 and 21.1).
#
# simplifyVector = FALSE throughout: automatic simplification silently turns a
# one-element list into a scalar and a ragged list into something else again,
# which is exactly the kind of quiet shape change that later breaks a parser in
# a way nobody notices.

#' Parse JSON text into an R list
#'
#' @param text A JSON string.
#' @param source_id Source id, for error messages.
#'
#' @return A list.
#' @noRd
parse_json <- function(text, source_id = NULL, call = rlang::caller_env()) {
  tryCatch(
    jsonlite::fromJSON(text, simplifyVector = FALSE),
    error = function(cnd) {
      knbs_abort(
        c(
          "Could not parse the response as JSON.",
          "x" = "{conditionMessage(cnd)}",
          "i" = "Source: {.val {source_id %||% 'unknown'}}."
        ),
        class = "knbs_error_parse_failed",
        call = call
      )
    }
  )
}

#' Parse a JSON response body
#'
#' @param resp An `httr2_response`.
#' @noRd
parse_json_response <- function(resp, source_id = NULL, call = rlang::caller_env()) {
  body <- httr2::resp_body_string(resp)
  if (!nzchar(trimws(body))) {
    knbs_abort(
      c(
        "The source returned an empty response body.",
        "i" = "Source: {.val {source_id %||% 'unknown'}}.",
        "i" = "An empty body is never treated as an empty result set."
      ),
      class = "knbs_error_parse_failed",
      call = call
    )
  }
  parse_json(body, source_id = source_id, call = call)
}

#' Read a JSON fixture from disk
#'
#' @param path Path to a `.json` file.
#' @noRd
parse_json_file <- function(path, source_id = NULL, call = rlang::caller_env()) {
  if (!file.exists(path)) {
    knbs_abort(
      c("Fixture not found.", "x" = "No file at {.path {path}}."),
      class = "knbs_error_resource_not_found",
      call = call
    )
  }
  parse_json(
    paste(readLines(path, warn = FALSE), collapse = "\n"),
    source_id = source_id,
    call = call
  )
}

# Field accessors -------------------------------------------------------------
#
# Source payloads are ragged: fields appear, disappear and change between NULL,
# "" and absent. These helpers make "missing" mean one thing.

#' Pull a scalar character field out of a parsed payload
#'
#' @param x A list.
#' @param field Field name.
#' @param default Value when the field is absent, NULL or empty.
#' @noRd
json_chr <- function(x, field, default = NA_character_) {
  v <- x[[field]]
  if (is.null(v) || length(v) == 0L) {
    return(default)
  }
  if (is.list(v)) {
    v <- unlist(v, use.names = FALSE)
    if (length(v) == 0L) {
      return(default)
    }
  }
  v <- as.character(v[[1]])
  if (!nzchar(v)) default else v
}

#' Pull a scalar integer field
#' @noRd
json_int <- function(x, field, default = NA_integer_) {
  v <- json_chr(x, field, default = NA_character_)
  if (is.na(v)) {
    return(default)
  }
  suppressWarnings(as.integer(v))
}

#' Pull a character vector field
#' @noRd
json_chr_vec <- function(x, field) {
  v <- x[[field]]
  if (is.null(v) || length(v) == 0L) {
    return(character(0))
  }
  as.character(unlist(v, use.names = FALSE))
}

#' Parse an ISO 8601 date or datetime into a Date
#'
#' Sources mix `2024-09-10` with `2024-09-10T08:29:10+03:00`. Only the date part
#' is retained; a value that cannot be parsed becomes `NA` rather than an error,
#' because a malformed timestamp should not lose the whole record.
#'
#' @noRd
json_date <- function(x, field) {
  v <- json_chr(x, field)
  if (is.na(v)) {
    return(as.Date(NA))
  }
  suppressWarnings(as.Date(substr(v, 1L, 10L), format = "%Y-%m-%d"))
}
