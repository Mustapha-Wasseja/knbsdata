# Small internal helpers ------------------------------------------------------

# cli's cli_* functions signal conditions that land on stderr, which is right
# for messages and wrong for print methods: `print()` output belongs on stdout
# where capture.output() and the console expect it. This formats cli inline
# markup and writes the result to stdout.
knbs_cat <- function(text, .envir = parent.frame()) {
  cli::cat_line(cli::format_inline(text, .envir = .envir))
}

# Drop NULL elements from a list, preserving names.
compact_list <- function(x) {
  x[!vapply(x, is.null, logical(1))]
}

is_string <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x)
}

is_bool <- function(x) {
  is.logical(x) && length(x) == 1L && !is.na(x)
}

is_number <- function(x) {
  is.numeric(x) && length(x) == 1L && !is.na(x)
}

# Argument checkers. These deliberately produce knbs_error_invalid_argument so
# that user-facing failures are always classed (plan section 18.1).

check_string <- function(x, arg, call = rlang::caller_env()) {
  if (!is_string(x)) {
    knbs_abort(
      c(
        "{.arg {arg}} must be a single string.",
        "x" = "Got {.obj_type_friendly {x}} of length {length(x)}."
      ),
      class = "knbs_error_invalid_argument",
      call = call
    )
  }
  invisible(x)
}

check_bool <- function(x, arg, call = rlang::caller_env()) {
  if (!is_bool(x)) {
    knbs_abort(
      c(
        "{.arg {arg}} must be {.code TRUE} or {.code FALSE}.",
        "x" = "Got {.obj_type_friendly {x}}."
      ),
      class = "knbs_error_invalid_argument",
      call = call
    )
  }
  invisible(x)
}

check_number <- function(x, arg, min = -Inf, call = rlang::caller_env()) {
  if (!is_number(x) || x < min) {
    requirement <- if (is.finite(min)) paste0("a single number >= ", min) else "a single number"
    knbs_abort(
      c(
        paste0("{.arg {arg}} must be ", requirement, "."),
        "x" = "Got {.obj_type_friendly {x}}."
      ),
      class = "knbs_error_invalid_argument",
      call = call
    )
  }
  invisible(x)
}

check_character <- function(x, arg, call = rlang::caller_env()) {
  if (!is.character(x) || length(x) == 0L || anyNA(x)) {
    knbs_abort(
      c(
        "{.arg {arg}} must be a character vector with no missing values.",
        "x" = "Got {.obj_type_friendly {x}}."
      ),
      class = "knbs_error_invalid_argument",
      call = call
    )
  }
  invisible(x)
}

# Check membership in a controlled vocabulary and report the unknown values.
check_values <- function(x, arg, allowed, call = rlang::caller_env()) {
  check_character(x, arg, call = call)
  unknown <- setdiff(x, allowed)
  if (length(unknown) > 0L) {
    knbs_abort(
      c(
        "{.arg {arg}} contains {cli::qty(length(unknown))} unrecognised value{?s}.",
        "x" = "{.val {unknown}}",
        "i" = "Allowed value{?s}: {.val {allowed}}."
      ),
      class = "knbs_error_invalid_argument",
      call = call
    )
  }
  invisible(x)
}
