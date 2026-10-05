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

#' Drop footnote digits printed against a label's last word
#'
#' Some chapters print footnote marks without a space: "Coffee1,2",
#' "Teachers Training3,4 ,", "Total Estimated Consumption1". Only digits
#' (and comma lists of them) attached directly to a letter or closing
#' bracket at the very end are dropped, so "100,000 and above" and
#' "10,000 - 14,999" are untouched. Applied only where a table's recipe
#' says its labels carry such marks.
#'
#' @noRd
abstract_strip_footnote_digits <- function(x) {
  trimws(sub("(?<=[A-Za-z)])[0-9]+( ?, ?[0-9]+)*( ?,)?$", "", x, perl = TRUE))
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

  # The header row puts years (with their status marks) in columns 2 onward,
  # as a run of consecutive years. Four-digit cells alone are not enough: a
  # data row of four-digit values (7866, 8269, 8922, ... in Table 2.7a) also
  # matches the year pattern, and taking it for a header silently dropped it.
  year_hits <- lapply(region, function(r) {
    row <- trimws(as.character(unlist(cells[r, -1])))
    which(!is.na(row) & grepl(abstract_year_re(), row)) + 1L
  })
  hit_years <- lapply(seq_along(region), function(i) {
    cols <- year_hits[[i]]
    as.integer(substr(trimws(as.character(unlist(cells[region[[i]], cols]))), 1, 4))
  })
  header_at <- vapply(hit_years, function(y) {
    length(y) >= 3L && all(diff(y) == 1L)
  }, logical(1))
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
  out_unit <- character(0)
  out_value <- list()
  line <- 0L

  data_region <- region[region > header_row]
  # A repeated header (where the print layout breaks a page) repeats the same
  # years in the same columns; nothing else is skipped as one.
  repeats_header <- vapply(seq_along(region), function(i) {
    header_at[[i]] && identical(year_hits[[i]], year_cols) &&
      identical(hit_years[[i]], years)
  }, logical(1))
  later_headers <- region[repeats_header]
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
      # An unlabelled row of words across the year columns is a second header
      # row - "Male | Female | Total" under each year - and every year's
      # first sub-column would otherwise be read as that year's value. A unit
      # note in one corner is not; half the year columns is the line.
      words <- !is.na(row_vals) & nzchar(trimws(row_vals)) &
        !trimws(row_vals) %in% abstract_missing_markers()
      if (sum(words) * 2L >= length(year_cols)) {
        knbs_abort(
          c(
            "Sheet {.val {spec$sheet}} has a second header row under its years ({.val {row_vals[words][[1]]}}, ...).",
            "i" = "Sub-columns per year are not a layout this extraction reads."
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
    if (isTRUE(spec$footnote_digits)) {
      label <- abstract_strip_footnote_digits(label)
    }
    relabel <- spec$relabel %||% list()
    if (label %in% names(relabel)) {
      label <- as.character(relabel[[label]])
    }

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
    if (!is.null(spec$unit_column)) {
      unit <- trimws(as.character(cells[[as.integer(spec$unit_column)]][[r]]))
      out_unit <- c(out_unit, if (is.na(unit) || !nzchar(unit)) NA_character_ else unit)
    }
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
  if (!is.null(spec$unit_column)) {
    # The sheet prints a unit per row (MT, '000 litres, metres): it travels
    # with each row, not in the table-level metadata.
    long$unit <- rep(out_unit, each = n_years)
  }
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
  long <- abstract_apply_hierarchy(long, spec, call = call)
  list(table = long, title = title)
}

#' Attach and verify a table's curated parts-and-totals structure
#'
#' Adds `parent` beside the item column: the row each item is a component
#' of, `NA` for headline totals and memo items. Every row the structure names
#' must be present, and where the spec says the parts add up, they must, in
#' every year, within what rounding to the printed precision can explain.
#' Either failure means the workbook no longer matches its curation.
#'
#' @noRd
abstract_apply_hierarchy <- function(long, spec, call = rlang::caller_env()) {
  hierarchy <- spec$hierarchy
  if (is.null(hierarchy)) {
    return(long)
  }
  item_col <- spec$item_column
  # `all_others: true` - a total over every other row, as in the county
  # tables - stands for listing all 47 counties by hand.
  entries <- lapply(hierarchy$parents, function(e) {
    if (isTRUE(e$all_others)) {
      e$components <- setdiff(unique(long[[item_col]]), e$parent)
    }
    e
  })

  named <- unique(unlist(lapply(entries, function(e) c(e$parent, e$components))))
  absent <- setdiff(named, long[[item_col]])
  if (length(absent) > 0L) {
    knbs_abort(
      c(
        paste0(
          "{.val {spec$table_id}} is missing {cli::qty(length(absent))}row{?s} ",
          "its curated structure names: {.val {absent}}."
        ),
        "i" = "The workbook's layout has changed; please report it."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }

  parent_of <- character(0)
  for (e in entries) {
    parent_of[as.character(e$components)] <- as.character(e$parent)
  }

  if (isTRUE(hierarchy$sums)) {
    for (e in entries) {
      abstract_check_parts(long, item_col, e, as.numeric(hierarchy$rounding),
                           spec$table_id, call = call)
    }
  }

  tibble::add_column(long, parent = unname(parent_of[long[[item_col]]]),
                     .after = item_col)
}

#' Check that one parent's parts add up to it in every year
#'
#' Each part and the total are rounded to the printed precision, so they can
#' disagree by at most (parts + 1) / 2 rounding units. A year with a missing
#' figure among them cannot be checked and is skipped.
#'
#' @noRd
abstract_check_parts <- function(long, item_col, entry, rounding, table_id,
                                 call = rlang::caller_env()) {
  components <- as.character(entry$components)
  signs <- ifelse(components %in% as.character(entry$subtract %||% character(0)),
                  -1, 1)
  tolerance <- rounding * (length(components) + 1) / 2

  for (p in sort(unique(long$period))) {
    year <- long[long$period == p, ]
    total <- year$value[year[[item_col]] == entry$parent]
    parts <- year$value[match(components, year[[item_col]])]
    if (length(total) != 1L || is.na(total) || anyNA(parts)) {
      next
    }
    gap <- total - sum(signs * parts)
    if (abs(gap) > tolerance + 1e-9) {
      knbs_abort(
        c(
          "The parts of {.val {entry$parent}} in {.val {table_id}} do not add up to it in {p}.",
          "x" = "They are off by {format(gap, big.mark = ',')}; rounding explains at most {tolerance}.",
          "i" = "The workbook has changed since curation; please report it so the registry can be re-verified."
        ),
        class = "knbs_error_validation_failed",
        call = call
      )
    }
  }
  invisible(NULL)
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
