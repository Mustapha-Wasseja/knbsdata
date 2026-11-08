# Report table extraction from PDF ---------------------------------------------
#
# Turns one curated table of a KNBS report published as PDF into tidy
# observations, driven entirely by its registry recipe (audit F-46). As with
# the Statistical Abstract workbooks, nothing about the layout is guessed at
# run time: the recipe names the title the table is found by, its columns in
# order, the rows it must hold (for a county table, the 47 counties and a
# total), its unit, and figures read by hand at curation time. Every read
# verifies all of it, and a table that no longer matches is refused with a
# classed error - wrong tidy data is worse than none.
#
# What the text of these PDFs looks like (audit F-46):
#
#   - A row is a label followed by one figure per column, separated by
#     spaces. Figures carry thousands commas, negatives come in parentheses
#     ("(387)"), and a provisional year is marked "2024*".
#   - A long label wraps: "ELGEYO/" then "MARAKWET" on the next line, or the
#     two halves above and below a row of figures with no label at all.
#     Labels are resolved by matching each candidate joining against the
#     rows the recipe expects, never by position alone.
#   - Some tables print two panels side by side, each with its own County
#     column. Each line is split where the second panel's County header
#     starts on that page, and each panel is read as a table of its own.
#   - Tables continue across pages under a repeated header, with running
#     heads and page numbers between. Lines that are neither a complete row
#     nor part of a label are skipped.
#   - Some reports set wider figures on a slightly different baseline, and
#     text extraction moves them to the line above or below their row. A
#     row that is short beside a line of figures alone is reunited by the
#     figures' positions under the columns, and only if every column then
#     holds exactly one figure.
#   - A cell left blank would make its row one figure short, and with plain
#     text there is no telling which column is missing. Such a row is
#     refused, never shifted - unless the recipe names that very cell
#     (`blank_cells`), checked by hand at curation; it is then filled from
#     the identity the table prints for its column (C = A + B) and marked
#     "derived".
#   - Text is read only from the pages a table is expected on, cut out of
#     the file first: some reports carry pages that take minutes to read,
#     and they are never the table's.

#' The text of the given pages of a PDF, named by page number
#'
#' @param pages Page numbers; `NULL` for every page.
#' @noRd
pdf_pages <- function(path, pages = NULL, call = rlang::caller_env()) {
  rlang::check_installed(c("pdftools", "qpdf"),
                         reason = "to read tables from KNBS report PDFs.", call = call)
  fail <- function(cnd) {
    knbs_abort(
      c("Could not read the PDF {.path {basename(path)}}.",
        "x" = conditionMessage(cnd)),
      class = "knbs_error_parse_failed",
      call = call
    )
  }
  total <- tryCatch(qpdf::pdf_length(path), error = fail)
  pages <- if (is.null(pages)) seq_len(total) else sort(unique(as.integer(pages)))
  pages <- pages[pages >= 1L & pages <= total]
  if (length(pages) == 0L) {
    return(stats::setNames(character(0), character(0)))
  }
  part <- tempfile(fileext = ".pdf")
  on.exit(unlink(part), add = TRUE)
  tryCatch(qpdf::pdf_subset(path, pages = pages, output = part), error = fail)
  text <- tryCatch(suppressMessages(pdftools::pdf_text(part)), error = fail)
  # Some producers end lines with \r\n; one convention throughout.
  stats::setNames(gsub("\r", "", text, fixed = TRUE), pages)
}

# A figure as printed: 1,234 | 1234 | 12.5 | (387) | -12.5 | 2024* | 7+ |
# 99.5% ; or a mark for no figure. Thousands commas must come in threes, so
# a stray "12,34" is not a figure.
pdf_figure_re <- function() {
  "^\\(?[-\u2212]?([0-9]{1,3}(,[0-9]{3})+|[0-9]+)(\\.[0-9]+)?\\)?[*+%]?$"
}

pdf_missing_marks <- function() {
  c("-", "\u2013", "\u2014", "..", "...", "\u2026", "n.a", "n.a.", "na", "N/A")
}

#' Is each token a figure, or a mark standing for one?
#' @noRd
pdf_is_figure <- function(tokens) {
  grepl(pdf_figure_re(), tokens) | tokens %in% pdf_missing_marks()
}

#' Figures as numbers: commas dropped, parentheses negative, marks NA
#' @noRd
pdf_value <- function(tokens) {
  x <- gsub("[*+%]$", "", tokens)
  negative <- grepl("^\\(.*\\)$", x) | grepl("^[-\u2212][0-9]", x)
  x <- gsub("[(),\u2212-]", "", x)
  out <- suppressWarnings(as.numeric(x))
  out[tokens %in% pdf_missing_marks()] <- NA_real_
  out[negative & !is.na(out)] <- -out[negative & !is.na(out)]
  out
}

#' Split a line into its label and its figures
#'
#' The figures are the run of figure tokens after the line's last word;
#' everything before them is the label. Where text is printed beside a table
#' (`trailing = TRUE`), the figures are instead the first run after the
#' label, and words after them are dropped: the row must still carry exactly
#' one figure per column, and its label must still name an expected row.
#'
#' @return list(label, figures) with figures as printed.
#' @noRd
pdf_split_line <- function(line, trailing = FALSE) {
  tokens <- strsplit(trimws(line), "[[:space:]]+")[[1]]
  tokens <- tokens[nzchar(tokens)]
  if (length(tokens) == 0L) {
    return(list(label = "", figures = character(0)))
  }
  is_fig <- pdf_is_figure(tokens)
  if (trailing && any(is_fig)) {
    start <- which(is_fig)[[1]]
    end <- start
    while (end < length(tokens) && is_fig[[end + 1L]]) end <- end + 1L
    label <- if (start > 1L) paste(tokens[seq_len(start - 1L)], collapse = " ") else ""
    return(list(label = label, figures = tokens[start:end]))
  }
  words <- which(!is_fig)
  start <- if (length(words) == 0L) 1L else max(words) + 1L
  figures <- if (start <= length(tokens)) tokens[start:length(tokens)] else character(0)
  # A lone dash after words is the hyphen of a name that wraps ("Tharaka -"
  # over "Nithi"), not a row of one nil figure.
  if (length(words) > 0L && length(figures) == 1L && figures %in% pdf_missing_marks()) {
    start <- length(tokens) + 1L
    figures <- character(0)
  }
  label <- if (start > 1L) paste(tokens[seq_len(start - 1L)], collapse = " ") else ""
  list(label = label, figures = figures)
}

#' Squash text for matching titles: lower case, words separated by single
#' spaces
#' @noRd
pdf_squash <- function(x) {
  trimws(gsub("[^a-z0-9]+", " ", tolower(x)))
}

#' The lines of one table: from its title to where it ends
#'
#' The title is found by the recipe's anchor (case, spacing and punctuation
#' ignored). A contents page also carries the title, so the table is the
#' occurrence followed by figure rows. Lines run on across following pages
#' until a line names a different table or `max_pages` pages have been read.
#'
#' @param pages Page texts named by page number.
#' @return A tibble of the table's lines with the page each came from; NULL
#'   if the title is not on these pages.
#' @noRd
pdf_table_lines <- function(pages, spec, n) {
  anchor <- pdf_squash(spec$anchor)
  max_pages <- as.integer(spec$max_pages %||% 3L)
  page_lines <- lapply(pages, function(p) strsplit(p, "\n", fixed = TRUE)[[1]])
  numbers <- as.integer(names(pages))
  # Another table's title ends this one; this table's own title repeated on
  # a continuation page ("(Cont'd)", "(continued)") does not.
  other_table <- function(line) {
    s <- pdf_squash(line)
    grepl("^table [0-9a-z]", s) && !grepl(anchor, s, fixed = TRUE) &&
      !grepl("\\bcont( d|inued)?\\b", s)
  }
  trailing <- isTRUE(spec$trailing_text)
  min_rows <- as.integer(spec$min_rows_on_first_page %||% 3L)
  for (i in seq_along(page_lines)) {
    at <- which(grepl(anchor, pdf_squash(page_lines[[i]]), fixed = TRUE))
    for (j in at) {
      rest <- page_lines[[i]][-seq_len(j)]
      rows <- vapply(rest, function(l) {
        length(pdf_split_line(l, trailing)$figures) %in% c(n, 2L * n)
      }, logical(1))
      if (sum(rows) < min_rows) next
      # A page's lines up to any other table's title, and whether it ended.
      take <- function(lines, page) {
        stop_at <- which(vapply(lines, other_table, logical(1)))
        done <- length(stop_at) > 0L
        if (done) lines <- lines[seq_len(stop_at[[1]] - 1L)]
        list(lines = tibble::tibble(page = rep(page, length(lines)), line = lines), done = done)
      }
      got <- take(rest, numbers[[i]])
      out <- list(got$lines)
      k <- i
      while (!got$done && k < length(page_lines) && length(out) < max_pages &&
               numbers[[k + 1L]] == numbers[[k]] + 1L) {
        k <- k + 1L
        got <- take(page_lines[[k]], numbers[[k]])
        out[[length(out) + 1L]] <- got$lines
      }
      return(do.call(rbind, out))
    }
  }
  NULL
}

#' Split two-panel lines into one panel after the other
#'
#' On each page, the second panel starts where the line holding the panel
#' header word (County) twice has its second one. Every line of that page is
#' cut at that position, and the right-hand parts follow the left-hand ones.
#' A page read past the table's end, with no row of figures on it, is
#' dropped; one with rows but no such header is refused.
#'
#' @noRd
pdf_unpanel <- function(lines, spec, n, call = rlang::caller_env()) {
  word <- spec$panel_header %||% "County"
  out <- list()
  for (page in unique(lines$page)) {
    these <- lines$line[lines$page == page]
    at <- gregexpr(paste0("\\b", word, "\\b"), these, ignore.case = TRUE)
    twice <- which(vapply(at, function(m) sum(m > 0L) >= 2L, logical(1)))
    has_rows <- any(vapply(these, function(l) length(pdf_split_line(l)$figures) >= n, logical(1)))
    if (length(twice) == 0L && !has_rows) {
      next
    }
    if (length(twice) == 0L) {
      knbs_abort(
        c("Page {page} of {.val {spec$table_id}} has no header naming {.val {word}} twice.",
          "i" = "The two-panel layout has changed; please report it."),
        class = "knbs_error_schema_changed",
        call = call
      )
    }
    cut <- at[[twice[[1]]]][[2]] - 1L
    left <- substr(these, 1L, cut)
    right <- substr(these, cut + 1L, nchar(these))
    out[[length(out) + 1L]] <- tibble::tibble(page = page, line = c(left, right))
  }
  do.call(rbind, out)
}

#' The figure tokens of a line with the character position each ends at
#' @noRd
pdf_figure_positions <- function(line, trailing = FALSE) {
  m <- gregexpr("\\S+", line)[[1]]
  if (m[[1]] < 0L) {
    return(list(words = character(0), figures = character(0), ends = integer(0)))
  }
  tokens <- regmatches(line, list(m))[[1]]
  ends <- as.integer(m) + attr(m, "match.length") - 1L
  split <- pdf_split_line(line, trailing)
  n_fig <- length(split$figures)
  keep <- if (n_fig > 0L) {
    first <- if (trailing) which(pdf_is_figure(tokens))[[1]] else length(tokens) - n_fig + 1L
    first:(first + n_fig - 1L)
  } else {
    integer(0)
  }
  list(words = if (nzchar(split$label)) split$label else character(0),
       figures = tokens[keep], ends = ends[keep])
}

#' Each column's right edge, measured on the complete rows among `lines`
#'
#' @return The edges, or NULL with fewer than three complete rows.
#' @noRd
pdf_column_edges <- function(lines, n, trailing = FALSE) {
  info <- lapply(lines, pdf_figure_positions, trailing = trailing)
  complete <- Filter(function(x) length(x$figures) == n, info)
  if (length(complete) < 3L) {
    return(NULL)
  }
  apply(do.call(rbind, lapply(complete, function(x) x$ends)), 2, stats::median)
}

#' Put a recipe's blank cells in their columns, by position
#'
#' For a table the recipe says leaves cells empty where there is nothing to
#' report. A row with a label and too few figures has each figure placed
#' under the column its right edge sits at, and a mark for no figure put in
#' the columns left over. A row whose figures do not sit under distinct
#' columns is left as it was, and refused later.
#'
#' @noRd
pdf_fill_blanks <- function(lines, n, edges, trailing = FALSE) {
  if (is.null(edges)) {
    return(lines)
  }
  tolerance <- max(2, min(diff(edges)) * 0.45)
  vapply(lines, function(line) {
    pos <- pdf_figure_positions(line, trailing = trailing)
    count <- length(pos$figures)
    if (length(pos$words) == 0L || count == 0L || count >= n) {
      return(line)
    }
    col <- vapply(pos$ends, function(p) which.min(abs(edges - p)), integer(1))
    if (any(abs(edges[col] - pos$ends) > tolerance) || anyDuplicated(col)) {
      return(line)
    }
    figures <- rep("-", n)
    figures[col] <- pos$figures
    paste(c(pos$words, figures), collapse = "   ")
  }, character(1), USE.NAMES = FALSE)
}

#' Reunite rows whose figures were printed on two lines
#'
#' Some reports set wider figures on a slightly different baseline, and text
#' extraction then puts them on the line above or below their row: a row
#' one or more figures short, beside a line of figures alone. Figures in
#' these tables are right-aligned, so each column's position is measured on
#' the page's complete rows, and the two lines' figures are placed by
#' position. They are joined only if every column then holds exactly one
#' figure; otherwise both lines are left as they were, and a short row is
#' refused as before.
#'
#' @return The lines, with each reunited row as one line and the line of
#'   figures it took removed.
#' @noRd
pdf_merge_overflow <- function(lines, n, trailing = FALSE) {
  info <- lapply(lines, pdf_figure_positions, trailing = trailing)
  counts <- vapply(info, function(x) length(x$figures), integer(1))
  complete <- which(counts == n)
  if (length(complete) < 3L) {
    return(lines)
  }
  # Each column's right edge: the median end position on the complete rows.
  ends <- do.call(rbind, lapply(info[complete], function(x) x$ends))
  edges <- apply(ends, 2, stats::median)
  spacing <- if (n > 1L) min(diff(edges)) else Inf
  tolerance <- max(2, spacing * 0.45)
  place <- function(pos) {
    col <- vapply(pos, function(p) which.min(abs(edges - p)), integer(1))
    ok <- abs(edges[col] - pos) <= tolerance
    if (all(ok) && !anyDuplicated(col) && length(col) == n) col else NULL
  }
  drop <- integer(0)
  out <- lines
  for (i in seq_along(lines)) {
    if (i %in% drop || counts[[i]] == 0L || counts[[i]] >= n) next
    for (j in c(i + 1L, i - 1L)) {
      if (j < 1L || j > length(lines) || j %in% drop) next
      # The partner holds figures and nothing else, and is no row itself.
      if (length(info[[j]]$words) > 0L || counts[[j]] == 0L || counts[[j]] >= n) next
      pos <- c(info[[i]]$ends, info[[j]]$ends)
      col <- place(pos)
      if (is.null(col)) next
      figures <- c(info[[i]]$figures, info[[j]]$figures)[order(col)]
      out[[i]] <- paste(c(info[[i]]$words, figures), collapse = "   ")
      drop <- c(drop, j)
      break
    }
  }
  if (length(drop) > 0L) out[-drop] else out
}

#' Join rows printed over several lines
#'
#' For tables that print each row's name, with some of its figures, on one
#' line and the rest of its figures on the next, unlabelled - or, where the
#' name wraps, over three lines ("Elgeyo", the rates, "Marakwet" with the
#' amounts). From each line that starts with words, following lines are
#' taken in until the row holds exactly `n` figures; their words make the
#' label, and their figures are put in column order by where each ends. A
#' group is kept only if it comes to exactly `n` figures and its label names
#' an expected row - a running head printed between rows starts no group -
#' otherwise its first line is left as it was and the next line tried.
#'
#' @noRd
pdf_join_two_line_rows <- function(lines, n, key_of = function(label) "row") {
  info <- lapply(lines, pdf_figure_positions)
  counts <- vapply(info, function(x) length(x$figures), integer(1))
  out <- character(0)
  i <- 1L
  while (i <= length(lines)) {
    if (length(info[[i]]$words) == 0L || counts[[i]] >= n) {
      out <- c(out, lines[[i]])
      i <- i + 1L
      next
    }
    words <- info[[i]]$words
    figures <- info[[i]]$figures
    ends <- info[[i]]$ends
    j <- i
    while (length(figures) < n && j < length(lines) && j < i + 2L) {
      j <- j + 1L
      if (!nzchar(trimws(lines[[j]]))) next
      words <- c(words, info[[j]]$words)
      figures <- c(figures, info[[j]]$figures)
      ends <- c(ends, info[[j]]$ends)
    }
    label <- paste(words, collapse = " ")
    if (length(figures) == n && !is.na(key_of(label))) {
      out <- c(out, paste(c(label, figures[order(ends)]), collapse = "   "))
      i <- j + 1L
    } else {
      out <- c(out, lines[[i]])
      i <- i + 1L
    }
  }
  out
}

#' Read the rows of a table whose rows are named by the recipe
#'
#' Every line with exactly one figure per column is a row. Its label is its
#' own text, joined where needed with label-only lines just above or below
#' it - whichever joining names an expected row. Lines with other numbers of
#' figures are running heads, page numbers, headers and notes, and are
#' skipped; but a line naming an expected row without the full set of
#' figures means a blank or merged cell, and refuses the table.
#'
#' @param lines Candidate lines.
#' @param n Figures per row.
#' @param key_of Function mapping a label to the key of the row it names,
#'   NA if it names none.
#' @return A tibble: key, label, figures (a list of the figures as printed).
#' @noRd
pdf_named_rows <- function(lines, n, key_of, table_id, trailing = FALSE,
                           blanks = list(), call = rlang::caller_env()) {
  parts <- lapply(lines, pdf_split_line, trailing = trailing)
  labels <- vapply(parts, function(p) p$label, character(1))
  counts <- vapply(parts, function(p) length(p$figures), integer(1))
  # A row the recipe says the report prints with a blank cell is one figure
  # short; it is read as a row only if its label names that row.
  blank_keys <- vapply(blanks, function(b) as.character(b$geo_code), character(1))
  short_but_known <- function(i) {
    counts[[i]] == n - 1L && length(blank_keys) > 0L &&
      !is.na(key_of(labels[[i]])) && key_of(labels[[i]]) %in% blank_keys
  }
  is_row <- counts == n | vapply(seq_along(lines), short_but_known, logical(1))
  is_label_only <- counts == 0L & grepl("[A-Za-z]", labels)

  rows <- which(is_row)
  used <- rep(FALSE, length(lines))
  out <- vector("list", length(rows))
  for (k in seq_along(rows)) {
    i <- rows[[k]]
    above <- if (i > 1L && is_label_only[[i - 1L]] && !used[[i - 1L]]) labels[[i - 1L]] else ""
    below <- if (i < length(lines) && is_label_only[[i + 1L]]) labels[[i + 1L]] else ""
    own <- labels[[i]]
    candidates <- list(
      list(text = own, above = FALSE, below = FALSE),
      list(text = paste(own, below), above = FALSE, below = nzchar(below)),
      list(text = paste(above, own), above = nzchar(above), below = FALSE),
      list(text = paste(above, own, below), above = nzchar(above), below = nzchar(below))
    )
    key <- NA_character_
    chosen <- candidates[[1]]
    for (cand in candidates) {
      text <- trimws(cand$text)
      if (!nzchar(text)) next
      found <- key_of(text)
      if (!is.na(found)) {
        key <- found
        chosen <- cand
        break
      }
    }
    if (chosen$above) used[[i - 1L]] <- TRUE
    if (chosen$below) used[[i + 1L]] <- TRUE
    used[[i]] <- TRUE
    figures <- parts[[i]]$figures
    if (length(figures) == n - 1L) {
      # The declared blank: an empty slot at its column, filled later.
      at <- as.integer(blanks[[match(key, blank_keys)]]$position)
      figures <- append(figures, "", after = at - 1L)
    }
    out[[k]] <- list(key = key, label = trimws(chosen$text), figures = figures)
  }

  # A line that names an expected row but did not become one: a blank or
  # merged cell, which plain text cannot place.
  stray <- which(!used & !is_row & counts > 0L)
  stray <- stray[!is.na(vapply(labels[stray], key_of, character(1)))]
  if (length(stray) > 0L) {
    knbs_abort(
      c(
        "A row of {.val {table_id}} does not carry one figure per column.",
        "x" = "Expected {n}; {.val {labels[stray][[1]]}} has {counts[stray][[1]]}.",
        "i" = "A blank or merged cell cannot be placed from the text; please report it."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }

  tibble::tibble(
    key = vapply(out, function(r) r$key, character(1)),
    label = vapply(out, function(r) r$label, character(1)),
    figures = lapply(out, function(r) r$figures)
  )
}

#' The key of a county-table row: a census county code, "00" for the total
#'
#' Matched on the official names through the same keys as
#' [knbs_county_code()] (spacing, case, hyphens, slashes and "City" do not
#' matter), plus the recipe's own spellings, and offline: the 47 names are
#' built into the package. A leading county number column is ignored.
#'
#' @noRd
pdf_county_key_fn <- function(spec) {
  statutory <- county_statutory()
  keys <- stats::setNames(statutory$geo_code, county_key(statutory$geo_name))
  totals <- county_key(as.character(unlist(spec$total_labels %||% c("Total", "Kenya", "National"))))
  relabel <- unlist(spec$relabel %||% list())
  if (length(relabel) > 0L) {
    names(relabel) <- county_key(names(relabel))
  } else {
    relabel <- stats::setNames(character(0), character(0))
  }
  function(label) {
    k <- county_key(sub("^[0-9]{1,2}\\s+", "", label))
    if (k %in% names(relabel)) {
      k <- county_key(relabel[[k]])
    }
    if (k %in% totals) {
      return("00")
    }
    hit <- unname(keys[k])
    if (length(hit) == 1L && !is.na(hit)) hit else NA_character_
  }
}

#' A recipe's columns as a table: label as printed, status, period, measure,
#' and whether the counties add up to the total in it
#'
#' A column is given as a string - a year, with "*" for provisional or "+"
#' for revised - or as a map with `label` and any of `period`, `measure`,
#' `unit` and `sums`.
#'
#' @noRd
pdf_columns <- function(spec) {
  cols <- spec$columns
  one <- function(col) {
    if (is.list(col)) {
      label <- as.character(col$label)
      period <- col$period %||% NA
      measure <- col$measure %||% spec$measure %||% NA_character_
      unit <- col$unit %||% spec$unit %||% NA_character_
      sums <- col$sums %||% (spec$sums %||% TRUE)
    } else {
      label <- as.character(col)
      period <- NA
      measure <- spec$measure %||% NA_character_
      unit <- spec$unit %||% NA_character_
      sums <- spec$sums %||% TRUE
    }
    clean <- sub("[*+]+$", "", label)
    if (is.na(period) && grepl("^[0-9]{4}$", clean)) period <- as.integer(clean)
    tibble::tibble(
      column = clean,
      status = if (grepl("\\*$", label)) "provisional" else if (grepl("\\+$", label)) "revised" else NA_character_,
      period = as.integer(period),
      measure = as.character(measure),
      unit = as.character(unit),
      sums = isTRUE(as.logical(sums))
    )
  }
  do.call(rbind, lapply(cols, one))
}

#' Extract one curated county table from a report's pages
#'
#' @param pages Page texts named by page number, from pdf_pages().
#' @param spec The table's recipe from the report registry.
#' @return list(table = tidy tibble, pages = page numbers read), or NULL if
#'   the table's title is not on these pages.
#' @noRd
extract_pdf_county_table <- function(pages, spec, call = rlang::caller_env()) {
  columns <- pdf_columns(spec)
  n <- nrow(columns)
  located <- pdf_table_lines(pages, spec, n)
  if (is.null(located)) {
    return(NULL)
  }
  if (!is.null(spec$line_width)) {
    # Text printed beside the table would otherwise end its rows in words.
    located$line <- substr(located$line, 1L, as.integer(spec$line_width))
  }
  lines <- if (as.integer(spec$panels %||% 1L) > 1L) pdf_unpanel(located, spec, n, call = call) else located
  # Rows split over two lines are reunited page by page (panel by panel),
  # since column positions are measured per page.
  key_of <- pdf_county_key_fn(spec)
  # Where a recipe says cells are left empty, columns are measured on the
  # page's own complete rows, or on the whole table's if the page has too few.
  table_edges <- if (isTRUE(spec$blank_by_position)) {
    pdf_column_edges(lines$line, n, trailing = isTRUE(spec$trailing_text))
  }
  lines <- do.call(rbind, lapply(split(lines, factor(lines$page, unique(lines$page))), function(pg) {
    merged <- if (isTRUE(spec$two_line_rows)) {
      pdf_join_two_line_rows(pg$line, n, key_of)
    } else {
      pdf_merge_overflow(pg$line, n, trailing = isTRUE(spec$trailing_text))
    }
    if (isTRUE(spec$blank_by_position)) {
      edges <- pdf_column_edges(merged, n, trailing = isTRUE(spec$trailing_text)) %||% table_edges
      merged <- pdf_fill_blanks(merged, n, edges, trailing = isTRUE(spec$trailing_text))
    }
    tibble::tibble(page = rep(pg$page[[1]], length(merged)), line = merged)
  }))
  blanks <- lapply(spec$blank_cells %||% list(), function(b) {
    b$position <- match(as.character(b$column), columns$column)
    b
  })
  rows <- pdf_named_rows(lines$line, n, key_of, spec$table_id,
                         trailing = isTRUE(spec$trailing_text), blanks = blanks, call = call)
  rows <- rows[!is.na(rows$key), ]

  # Counties the report prints with no figures ("did not submit"), found at
  # curation: kept as rows of no figures, marked as not reported.
  absent <- setdiff(as.character(unlist(spec$absent_rows %||% character(0))), rows$key)
  if (length(absent) > 0L) {
    rows <- rbind(rows, tibble::tibble(key = absent, label = absent,
                                       figures = rep(list(rep("", n)), length(absent))))
  }

  expected <- c(sprintf("%02d", 1:47), if (!isFALSE(spec$total_row)) "00")
  missing <- setdiff(expected, rows$key)
  doubled <- unique(rows$key[duplicated(rows$key)])
  if (length(missing) > 0L || length(doubled) > 0L) {
    statutory <- county_statutory()
    name_of <- function(code) {
      ifelse(code == "00", "the total", statutory$geo_name[match(code, statutory$geo_code)])
    }
    missing_names <- name_of(missing)
    doubled_names <- name_of(doubled)
    knbs_abort(
      c(
        "The rows of {.val {spec$table_id}} no longer match the 47 counties and the total.",
        if (length(missing) > 0L) c("x" = "Missing: {.val {missing_names}}."),
        if (length(doubled) > 0L) c("x" = "Read twice: {.val {doubled_names}}."),
        "i" = "The report has changed since curation; please report it."
      ),
      class = "knbs_error_schema_changed",
      call = call,
      missing = missing_names,
      doubled = doubled_names
    )
  }

  values <- do.call(rbind, lapply(rows$figures, pdf_value))
  colnames(values) <- columns$column
  if (isTRUE(spec$dash_means_zero)) {
    # Where the report prints "-" for nil, as its totals show.
    dashes <- do.call(rbind, lapply(rows$figures, function(f) f %in% c("-", "\u2013", "\u2014")))
    values[dashes] <- 0
  }
  # A cell the report prints blank is filled from the identity the table
  # prints in its header (C = A + B), and marked as derived.
  derived <- matrix(FALSE, nrow(values), n, dimnames = dimnames(values))
  for (b in blanks) {
    r <- match(as.character(b$geo_code), rows$key)
    parts <- as.character(unlist(b$derive))
    if (is.na(r) || length(parts) == 0L || !is.na(values[r, b$position])) next
    values[r, b$position] <- sum(values[r, parts])
    derived[r, b$position] <- TRUE
  }
  long <- tibble::tibble(
    geo_code = rep(rows$key, times = n),
    column = rep(columns$column, each = nrow(rows)),
    value = as.vector(values),
    derived = as.vector(derived)
  )
  long <- merge(long, columns, by = "column", sort = FALSE)
  long$status[long$derived] <- "derived"
  long$status[long$geo_code %in% absent] <- "not_reported"
  # A row whose identity fails with nothing to show which figure is wrong,
  # named in the recipe: kept as printed, marked on its total.
  for (identity in spec$identities %||% list()) {
    long$status[long$column == as.character(identity$column) &
                  long$geo_code %in% as.character(unlist(identity$exempt))] <- "inconsistent"
  }
  for (m in spec$misprints %||% list()) {
    long$status[long$geo_code == m$geo_code & long$column == as.character(m$column)] <- "misprint"
  }
  long <- tibble::as_tibble(long[order(long$geo_code == "00", long$geo_code,
                                       match(long$column, columns$column)),
                                 c("geo_code", "column", "period", "measure", "unit",
                                   "status", "value", "sums")])
  pdf_check_table(long, spec, call = call)
  long$sums <- NULL
  list(table = long, pages = sort(unique(located$page)))
}

#' Verify a table against its recipe: pinned figures, row identities, and
#' the counties against the total
#'
#' Works on a copy: the table returned keeps every figure as printed.
#'
#' Rounding to the printed precision explains at most half a unit per
#' county, so the 47 counties may differ from the printed total by up to
#' (47 + 1) / 2 units; anything more means a misread figure or a table
#' that does not add up as printed, and refuses it. Columns marked as not
#' adding (rates, densities, per-capita figures) are not summed; a recipe
#' can instead require the counties to add to a fixed figure (`sum_to: 100`
#' for shares). Known printed discrepancies are listed in the recipe with
#' the gap observed, and only that gap is accepted.
#'
#' @noRd
pdf_check_table <- function(long, spec, call = rlang::caller_env()) {
  for (pin in spec$pins %||% list()) {
    got <- long$value[long$geo_code == pin$geo_code & long$column == as.character(pin$column)]
    if (length(got) != 1L || is.na(got) || abs(got - as.numeric(pin$value)) > 1e-9) {
      knbs_abort(
        c(
          "A figure in {.val {spec$table_id}} no longer matches the one checked at curation.",
          "x" = "{pin$geo_code} / {pin$column}: expected {pin$value}, read {if (length(got)) got else 'nothing'}.",
          "i" = "The report has changed since curation; please report it."
        ),
        class = "knbs_error_validation_failed",
        call = call
      )
    }
  }
  unit <- as.numeric(spec$rounding %||% 1)
  # Some tables print their total row to a coarser precision than the rows.
  total_unit <- as.numeric(spec$total_rounding %||% unit)
  value_at <- function(code, col) long$value[long$geo_code == code & long$column == col]

  # Row identities the table prints in its header (C = A + B): checked on
  # every row, within what rounding of each part can explain. A misprint
  # found at curation is listed in the recipe and kept as printed; for the
  # column totals it counts at the value its identity gives.
  misprinted <- vapply(spec$misprints %||% list(), function(m) {
    paste(m$geo_code, m$column)
  }, character(1))
  corrected <- long$value
  for (identity in spec$identities %||% list()) {
    col <- as.character(identity$column)
    parts <- as.character(unlist(identity$sum))
    for (code in unique(long$geo_code)) {
      if (isTRUE(identity$counties_only) && code == "00") next
      if (code %in% as.character(unlist(identity$exempt))) next
      printed <- value_at(code, col)
      implied <- sum(vapply(parts, function(p) value_at(code, p), numeric(1)))
      if (length(printed) != 1L || is.na(printed) || is.na(implied)) next
      # A county's parts are each rounded once; the total row's are sums of
      # 47 rounded figures, and may drift as far as a column total may.
      allowed <- if (code == "00") {
        (unit * sum(long$geo_code != "00" & long$column == col) + total_unit) / 2 + 1e-9
      } else {
        unit * (length(parts) + 1) / 2 + 1e-9
      }
      if (paste(code, col) %in% misprinted) {
        corrected[long$geo_code == code & long$column == col] <- implied
        next
      }
      wrong_part <- parts[paste(code, parts) %in% misprinted]
      if (length(wrong_part) == 1L) {
        # The total is right and one part is not: that part, corrected.
        at <- long$geo_code == code & long$column == wrong_part
        corrected[at] <- long$value[at] + printed - implied
        next
      }
      if (abs(printed - implied) > allowed) {
        knbs_abort(
          c(
            "A row of {.val {spec$table_id}} does not add up as the table says it does.",
            "x" = "{code}: {col} is printed as {printed}; {paste(parts, collapse = ' + ')} = {implied}.",
            "i" = "A figure was misread or the report has changed; please report it."
          ),
          class = "knbs_error_validation_failed",
          call = call,
          geo_code = code,
          column = col
        )
      }
    }
  }
  long$value <- corrected

  if (isFALSE(spec$total_row) && is.null(spec$sum_to)) {
    return(invisible(TRUE))
  }
  known <- spec$known_gaps %||% list()
  for (col in unique(long$column[long$sums])) {
    counties <- long$value[long$column == col & long$geo_code != "00"]
    target <- if (!is.null(spec$sum_to)) as.numeric(spec$sum_to) else
      long$value[long$column == col & long$geo_code == "00"]
    counties <- counties[!is.na(counties)]
    if (length(counties) == 0L || length(target) != 1L || is.na(target)) {
      next
    }
    gap <- sum(counties) - target
    allowed <- (unit * length(counties) + total_unit) / 2 + 1e-9
    accepted <- Filter(function(k) identical(as.character(k$column), col), known)
    if (length(accepted) > 0L && abs(gap - as.numeric(accepted[[1]]$gap)) <= 1e-6) {
      next
    }
    if (abs(gap) > allowed) {
      summed <- format(sum(counties), big.mark = ",")
      printed <- format(target, big.mark = ",")
      knbs_abort(
        c(
          "The counties of {.val {spec$table_id}} do not add up to its total.",
          "x" = "{col}: the 47 counties sum to {summed}; the total is {printed}.",
          "i" = "Rounding explains at most {allowed}; a figure was misread or the table changed. Please report it."
        ),
        class = "knbs_error_validation_failed",
        call = call,
        column = col,
        counties_sum = summed,
        total = printed
      )
    }
  }
  invisible(TRUE)
}
