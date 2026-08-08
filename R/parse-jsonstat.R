# JSON-stat parsing -----------------------------------------------------------
#
# JSON-stat 2.0 (https://json-stat.org) is the format the KNBS census API
# serves. A dataset is a dense (or sparse) value array over a cross-product of
# dimensions; the spec fixes the order: the LAST dimension varies fastest.
#
# The parser is deliberately generic - nothing KNBS-specific lives here - so it
# can serve any future JSON-stat source unchanged.

#' Parse a JSON-stat 2.0 dataset into a long table
#'
#' @param payload A parsed JSON list.
#' @param source_id Source id, for error messages.
#'
#' @return A list with `table` (a tibble: one `<dim_id>` code column and one
#'   `<dim_id>_label` column per dimension, plus `value` and, when the payload
#'   carries one, `status`), and `meta` (label, source, updated, dimension
#'   labels, extension).
#' @noRd
parse_jsonstat <- function(payload, source_id = NULL, call = rlang::caller_env()) {
  required <- c("id", "size", "dimension", "value")
  missing_fields <- setdiff(required, names(payload))
  if (!identical(payload[["class"]], "dataset") || length(missing_fields) > 0L) {
    knbs_abort(
      c(
        "The response is not a JSON-stat dataset.",
        "x" = if (length(missing_fields) > 0L) {
          "Missing: {.field {missing_fields}}."
        } else {
          "Its class is {.val {payload[['class']]}}."
        },
        "i" = "Source: {.val {source_id %||% 'unknown'}}."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }

  dim_ids <- as.character(unlist(payload$id))
  sizes <- as.integer(unlist(payload$size))
  if (length(dim_ids) != length(sizes) || any(is.na(sizes)) || any(sizes < 1L)) {
    knbs_abort(
      c("The dataset's {.field id} and {.field size} do not agree."),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  n <- prod(sizes)

  values <- jsonstat_values(payload$value, n, source_id = source_id, call = call)
  status <- jsonstat_status(payload$status, n)

  # Codes for each dimension, in index order.
  categories <- lapply(dim_ids, function(d) {
    dimension <- payload$dimension[[d]]
    if (is.null(dimension)) {
      knbs_abort(
        c("Dimension {.val {d}} is declared but not described."),
        class = "knbs_error_schema_changed",
        call = call
      )
    }
    jsonstat_codes(dimension, d, expected = sizes[[match(d, dim_ids)]], call = call)
  })
  names(categories) <- dim_ids

  # Row-major expansion: last dimension fastest. expand.grid varies its FIRST
  # factor fastest, so feed it the reversed list and reverse the columns back.
  grid <- expand.grid(rev(categories), stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
  grid <- grid[, rev(seq_along(grid)), drop = FALSE]
  names(grid) <- dim_ids

  # Columns interleaved per dimension - code then label - so related columns
  # sit together however many dimensions a table has.
  columns <- list()
  for (d in dim_ids) {
    labels <- jsonstat_labels(payload$dimension[[d]])
    resolved <- unname(labels[grid[[d]]])
    columns[[d]] <- grid[[d]]
    columns[[paste0(d, "_label")]] <- ifelse(is.na(resolved), grid[[d]], resolved)
  }
  out <- tibble::as_tibble(columns)
  out$value <- values
  if (!is.null(status)) {
    out$status <- status
  }

  meta <- list(
    label = json_chr(payload, "label"),
    source = json_chr(payload, "source"),
    updated = json_date(payload, "updated"),
    dimension_labels = vapply(
      dim_ids,
      function(d) json_chr(payload$dimension[[d]], "label", default = d),
      character(1)
    ),
    extension = payload$extension
  )

  list(table = out, meta = meta)
}

#' Coerce one JSON value cell to numeric
#'
#' Producers put strings, empty strings and symbols like "-" where numbers
#' should be; all of those are missing values, reported as NA without console
#' noise.
#' @noRd
jsonstat_cell <- function(v) {
  if (is.null(v)) {
    return(NA_real_)
  }
  suppressWarnings(as.numeric(v))
}

#' The value array, dense or sparse
#' @noRd
jsonstat_values <- function(value, n, source_id = NULL, call = rlang::caller_env()) {
  if (is.list(value) && !is.null(names(value))) {
    # Sparse: an object keyed by 0-based position.
    out <- rep(NA_real_, n)
    positions <- suppressWarnings(as.integer(names(value)))
    if (anyNA(positions) || any(positions < 0L) || any(positions >= n)) {
      knbs_abort(
        c("The dataset's sparse {.field value} keys are out of range."),
        class = "knbs_error_schema_changed",
        call = call
      )
    }
    out[positions + 1L] <- vapply(value, jsonstat_cell, numeric(1))
    return(out)
  }

  out <- vapply(value, jsonstat_cell, numeric(1))
  if (length(out) != n) {
    knbs_abort(
      c(
        "The dataset's values do not fill its dimensions.",
        "x" = "{length(out)} value{?s} for {n} cell{?s}.",
        "i" = "Source: {.val {source_id %||% 'unknown'}}."
      ),
      class = "knbs_error_validation_failed",
      call = call
    )
  }
  out
}

#' The optional status array, aligned to the values
#' @noRd
jsonstat_status <- function(status, n) {
  if (is.null(status)) {
    return(NULL)
  }
  if (is.list(status) && !is.null(names(status))) {
    out <- rep(NA_character_, n)
    positions <- suppressWarnings(as.integer(names(status)))
    keep <- !is.na(positions) & positions >= 0L & positions < n
    out[positions[keep] + 1L] <- as.character(unlist(status[keep], use.names = FALSE))
    return(out)
  }
  flat <- as.character(unlist(status, use.names = FALSE))
  if (length(flat) == 1L) {
    return(rep(flat, n))
  }
  if (length(flat) == n) {
    return(flat)
  }
  NULL
}

#' A dimension's codes, ordered by index position
#' @noRd
jsonstat_codes <- function(dimension, dim_id, expected, call = rlang::caller_env()) {
  index <- dimension$category$index
  codes <- if (is.null(index)) {
    # A dimension with a single category may omit the index; codes then come
    # from the label object.
    names(dimension$category$label)
  } else if (is.list(index) && !is.null(names(index))) {
    names(index)[order(unlist(index))]
  } else {
    as.character(unlist(index))
  }

  if (length(codes) != expected) {
    knbs_abort(
      c(
        "Dimension {.val {dim_id}} declares {expected} categor{?y/ies} but describes {length(codes)}."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  codes
}

#' A dimension's code -> label map
#' @noRd
jsonstat_labels <- function(dimension) {
  labels <- dimension$category$label
  if (is.null(labels)) {
    return(character(0))
  }
  vapply(labels, as.character, character(1))
}
