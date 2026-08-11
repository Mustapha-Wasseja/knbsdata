# Statistical Abstract table extraction ---------------------------------------
#
# Turns one curated sheet of a Statistical Abstract chapter workbook into tidy
# observations, driven entirely by its registry spec (audit F-35, F-36).
# Nothing about the layout is guessed at run time: the spec names the title
# anchor, the section labels and pinned reference values, and every read
# verifies all of them. A sheet whose layout or figures have drifted is
# refused with a classed error rather than silently re-interpreted - wrong
# tidy data is worse than none.
#
# Layout facts these routines encode (audit F-36):
#
#   - Year headers carry the source's own status marks: "2024*" is
#     provisional, "2022+" (or a superscript plus) is revised.
#   - Long tables repeat their title and header mid-sheet where the print
#     layout breaks pages; repeats are recognised and skipped, and a
#     *different* table's title ends the block (several sheets stack tables).
#   - A value-less label row is a section heading only if the spec lists it;
#     otherwise it is an item whose values the source simply does not show
#     ("Less: Subsidies" in Table 2.1), kept with honest NA values.
#   - Row labels may end in footnote digits and dot leaders
#     ("Discrepancy 1 ....."); both are trimmed, and footnote lines
#     themselves ("1 Difference between...", "NPISH: ...") are skipped.

# "2024", "2024*", "2022+", "2012<superscript plus>"
abstract_year_re <- function() "^[0-9]{4}[ ]?[*+\u207a]?$"

abstract_missing_markers <- function() c("", "-", "..", "\u2026", "\u2014")

#' Clean a row label: collapse whitespace, drop leaders and footnote marks
#' @noRd
abstract_clean_label <- function(x) {
  x <- gsub("[\u00a0[:space:]]+", " ", x)
  x <- gsub("[. \u2026]+$", "", x)
  x <- sub(" [0-9]+$", "", x)
  x <- sub("[*+\u207a]+$", "", x)
  trimws(x)
}

#' Numeric cell coercion with the abstract's missing-value markers
#' @noRd
abstract_cell <- function(x) {
  x <- trimws(x %||% "")
  if (is.na(x) || x %in% abstract_missing_markers()) {
    return(NA_real_)
  }
  suppressWarnings(as.numeric(gsub(",", "", x, fixed = TRUE)))
}

#' Rows that are footnotes or page furniture, never data
#' @noRd
abstract_skip_label <- function(label) {
  grepl("^\\*|^\\+|^[0-9]+ |^NPISH|^Source|^NATIONAL ACCOUNTS$", label)
}

#' Extract one curated table from a sheet read as text cells
#'
#' @param cells The sheet as a text tibble (`readxl` with `col_names = FALSE`,
#'   `col_types = "text"`).
#' @param spec One `tables` entry of the abstract registry.
#' @return list(table, title) - the tidy observations and the sheet's own
#'   title, verbatim.
#' @noRd
extract_abstract_table <- function(cells, spec, call = rlang::caller_env()) {
  labels_raw <- trimws(as.character(cells[[1]]))
  n_rows <- nrow(cells)

  is_title <- !is.na(labels_raw) & startsWith(labels_raw, spec$anchor)
  if (!any(is_title)) {
    knbs_abort(
      c(
        "Sheet {.val {spec$sheet}} no longer carries {.val {spec$anchor}}.",
        "i" = "The workbook's layout has changed; please report it."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  first_title <- which(is_title)[[1]]
  title <- labels_raw[[first_title]]

  is_other_title <- !is.na(labels_raw) & grepl("^Table ", labels_raw) & !is_title
  enders <- which(is_other_title & seq_len(n_rows) > first_title)
  block_end <- if (length(enders) > 0L) min(enders) - 1L else n_rows
  if (block_end <= first_title) {
    knbs_abort(
      c("The block under {.val {spec$anchor}} in sheet {.val {spec$sheet}} is empty."),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  region <- seq.int(first_title + 1L, block_end)

  # The header row puts years (with their status marks) in columns 2 onward.
  year_hits <- lapply(region, function(r) {
    row <- trimws(as.character(unlist(cells[r, -1])))
    which(!is.na(row) & grepl(abstract_year_re(), row)) + 1L
  })
  header_at <- vapply(year_hits, length, integer(1)) >= 3L
  if (!any(header_at)) {
    knbs_abort(
      c(
        "No year header found under {.val {spec$anchor}} in sheet {.val {spec$sheet}}.",
        "i" = "The workbook's layout has changed; please report it."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  header_row <- region[header_at][[1]]
  year_cols <- year_hits[[which(header_at)[[1]]]]
  header_cells <- trimws(as.character(unlist(cells[header_row, year_cols])))
  years <- as.integer(substr(header_cells, 1, 4))
  marks <- sub("^[0-9]{4}[ ]?", "", header_cells)
  status <- rep(NA_character_, length(marks))
  status[marks == "*"] <- "provisional"
  status[marks %in% c("+", "\u207a")] <- "revised"

  groups <- as.character(spec$groups %||% character(0))
  sectioned <- length(groups) > 0L
  current_group <- NA_character_
  seen_groups <- character(0)

  out_group <- character(0)
  out_item <- character(0)
  out_line <- integer(0)
  out_value <- list()
  line <- 0L

  data_region <- region[region > header_row]
  later_headers <- region[header_at]
  for (r in data_region) {
    if (is_title[[r]] || r %in% later_headers) {
      next
    }
    label_raw <- labels_raw[[r]]
    row_vals <- as.character(unlist(cells[r, year_cols]))
    values <- vapply(row_vals, abstract_cell, double(1), USE.NAMES = FALSE)
    has_values <- any(!is.na(values))

    if (is.na(label_raw) || !nzchar(label_raw)) {
      if (has_values) {
        knbs_abort(
          c(
            "Row {r} of sheet {.val {spec$sheet}} carries values without a label.",
            "i" = "The workbook's layout has changed; please report it."
          ),
          class = "knbs_error_schema_changed",
          call = call
        )
      }
      next
    }
    if (abstract_skip_label(label_raw)) {
      next
    }
    label <- abstract_clean_label(label_raw)

    if (sectioned && label %in% groups) {
      if (has_values) {
        knbs_abort(
          c(
            "Section row {.val {label}} carries values in sheet {.val {spec$sheet}}.",
            "i" = "The workbook's layout has changed; please report it."
          ),
          class = "knbs_error_schema_changed",
          call = call
        )
      }
      current_group <- label
      seen_groups <- union(seen_groups, label)
      next
    }
    if (!has_values && !sectioned) {
      knbs_abort(
        c(
          "Unexpected value-less row {.val {label}} in sheet {.val {spec$sheet}}.",
          "i" = "The workbook's layout has changed; please report it."
        ),
        class = "knbs_error_schema_changed",
        call = call
      )
    }
    if (sectioned && is.na(current_group)) {
      knbs_abort(
        c(
          "Row {.val {label}} appears before any section of {.val {spec$anchor}}.",
          "i" = "The workbook's layout has changed; please report it."
        ),
        class = "knbs_error_schema_changed",
        call = call
      )
    }

    junk <- !is.na(row_vals) & nzchar(trimws(row_vals)) & is.na(values) &
      !trimws(row_vals) %in% abstract_missing_markers()
    if (any(junk)) {
      knbs_abort(
        c(
          "Non-numeric cell under {.val {label}} in sheet {.val {spec$sheet}}: {.val {row_vals[junk][[1]]}}.",
          "i" = "The workbook's layout has changed; please report it."
        ),
        class = "knbs_error_schema_changed",
        call = call
      )
    }

    line <- line + 1L
    out_group <- c(out_group, current_group)
    out_item <- c(out_item, label)
    out_line <- c(out_line, line)
    out_value[[line]] <- values
  }

  if (sectioned && length(setdiff(groups, seen_groups)) > 0L) {
    knbs_abort(
      c(
        "Sheet {.val {spec$sheet}} is missing section{?s} {.val {setdiff(groups, seen_groups)}}.",
        "i" = "The workbook's layout has changed; please report it."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  if (line == 0L) {
    knbs_abort(
      c("No data rows found under {.val {spec$anchor}} in sheet {.val {spec$sheet}}."),
      class = "knbs_error_schema_changed",
      call = call
    )
  }

  n_years <- length(years)
  long <- tibble::tibble(
    table_id = rep(spec$table_id, line * n_years),
    table_title = rep(title, line * n_years)
  )
  if (sectioned) {
    long[[spec$group_column]] <- rep(out_group, each = n_years)
  }
  long[[spec$item_column]] <- rep(out_item, each = n_years)
  if (isTRUE(spec$line_numbers)) {
    long$line <- rep(out_line, each = n_years)
  }
  long$period <- rep(years, times = line)
  long$status <- rep(status, times = line)
  long$value <- unlist(out_value)
  long$source_id <- rep("knbs_publications", nrow(long))

  key_cols <- c(
    if (sectioned) spec$group_column,
    spec$item_column,
    if (isTRUE(spec$line_numbers)) "line",
    "period"
  )
  keys <- do.call(paste, c(long[key_cols], sep = "\r"))
  if (anyDuplicated(keys) > 0L) {
    knbs_abort(
      c(
        "Extraction of {.val {spec$table_id}} produced duplicate keys.",
        "x" = "Key columns: {.field {key_cols}}.",
        "i" = "The workbook's layout has changed; please report it."
      ),
      class = "knbs_error_validation_failed",
      call = call
    )
  }

  abstract_run_checks(long, spec, call = call)
  list(table = long, title = title)
}

#' Verify the extraction against the spec's curated expectations
#' @noRd
abstract_run_checks <- function(long, spec, call = rlang::caller_env()) {
  checks <- spec$checks %||% list()
  through <- checks$through
  if (!is.null(through) && max(long$period) < as.integer(through)) {
    knbs_abort(
      c(
        "{.val {spec$table_id}} was expected to reach {.val {through}} but stops at {.val {max(long$period)}}.",
        "i" = "The workbook's layout has changed; please report it."
      ),
      class = "knbs_error_validation_failed",
      call = call
    )
  }
  for (pin in checks$pins %||% list()) {
    rows <- long$period == as.integer(pin$period) &
      long[[spec$item_column]] == pin$item
    if (!is.null(pin$group)) {
      rows <- rows & long[[spec$group_column]] == pin$group
    }
    hit <- long$value[rows]
    want <- as.numeric(pin$value)
    ok <- length(hit) == 1L && !is.na(hit) &&
      abs(hit - want) <= 1e-6 * max(1, abs(want))
    if (!ok) {
      knbs_abort(
        c(
          "A pinned reference value of {.val {spec$table_id}} no longer matches.",
          "x" = paste0(
            "{.val {pin$item}} in {.val {pin$period}} was ",
            "{.val {want}} at curation time."
          ),
          "i" = "The workbook has changed since curation; please report it so the registry can be re-verified."
        ),
        class = "knbs_error_validation_failed",
        call = call
      )
    }
  }
  invisible(long)
}
