# Statistical Abstract: public interface --------------------------------------

#' List the curated Statistical Abstract tables
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The Statistical Abstract publishes its chapter tables as Excel workbooks on
#' the KNBS website. This function lists the tables the package has *curated*:
#' each one has a hand-verified extraction recipe — sheet, layout anchors,
#' section labels, unit and pinned reference values — so that
#' [knbs_abstract_table()] can return it as clean tidy observations, or refuse
#' with a clear error if the workbook has changed.
#'
#' Curated so far, from the 2025 edition: all fifteen tables of Chapter 2
#' (National Accounts) — the production accounts, GDP by activity at current
#' and constant prices, expenditure on GDP, capital formation, national
#' income and saving — and 33 tables from twelve more chapters: wage
#' employment, insurance and savings, exports, crop sales and prices,
#' forests and wildlife, electricity and fuel, producer prices and
#' industrial production, construction, tourism, transport, education
#' enrolment, and registered births and deaths. Six are county tables.
#'
#' @return A `knbs_catalogue` tibble with columns `table_id`, `title`,
#'   `chapter`, `unit`, `sheet` and `workbook`.
#'
#' @seealso [knbs_abstract_table()], [knbs_publications()]
#'
#' @examples
#' knbs_abstract_tables()
#' @export
knbs_abstract_tables <- function() {
  registry <- abstract_registry()
  workbooks <- registry$workbooks
  chapters <- stats::setNames(
    vapply(workbooks, function(w) as.character(w$chapter), character(1)),
    vapply(workbooks, function(w) as.character(w$workbook_id), character(1))
  )
  files <- stats::setNames(
    vapply(workbooks, function(w) as.character(w$file_name), character(1)),
    names(chapters)
  )

  tables <- registry$tables
  out <- tibble::tibble(
    table_id = vapply(tables, function(t) as.character(t$table_id), character(1)),
    title = vapply(tables, function(t) as.character(t$title), character(1)),
    chapter = unname(chapters[vapply(tables, function(t) t$workbook_id, character(1))]),
    unit = vapply(tables, function(t) as.character(t$unit), character(1)),
    sheet = vapply(tables, function(t) as.character(t$sheet), character(1)),
    workbook = unname(files[vapply(tables, function(t) t$workbook_id, character(1))])
  )

  new_knbs_catalogue(
    out,
    new_knbs_metadata(
      title = paste0(registry$edition, " Statistical Abstract: curated tables"),
      resource_type = "table",
      source_id = "knbs_publications",
      source_name = "KNBS Publications (website media library)",
      source_url = as.character(workbooks[[1]]$index_page),
      producer = "Kenya National Bureau of Statistics",
      licence = "Not stated by the source",
      access = "open",
      notes = paste0(
        "Each listed table has a hand-verified extraction recipe; ",
        "knbs_abstract_table() refuses a workbook that no longer matches it."
      )
    )
  )
}

#' Retrieve one Statistical Abstract table as tidy observations
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Downloads the table's chapter workbook from the KNBS website (cached
#' locally), extracts the table by its curated recipe, verifies the layout
#' anchors and pinned reference values, and returns one row per cell of the
#' printed table.
#'
#' @details
#' `period` is the integer year. `status` carries the source's own year
#' flags, `"provisional"` (`*`) or `"revised"` (`+`), and is `NA` for final
#' years. Sectioned tables (the production accounts, the income accounts)
#' carry their section as an extra column named for what it is —
#' `industry` or `account`. A row the source prints without figures (such as
#' "Less: Subsidies" in the production accounts) is kept with `NA` values,
#' because that is what the source shows.
#'
#' Tables that print totals beside their parts (GDP by activity, expenditure
#' on GDP, capital formation) carry a `parent` column naming the row each item
#' is a component of: industries have `"All industries"` (or `"All industries
#' at basic prices"`) as their parent, sub-industries have their industry, and
#' headline totals and memo items have `NA`. Summing rows that share a parent
#' never double counts; summing the whole table does. For level and share
#' tables the parts are checked to add up to their parent in every year,
#' within rounding. Imports enter GDP with a negative sign, and the metadata
#' says so. The accounts tables (2.1, 2.8, 2.9) are linked by accounting
#' identities rather than parts and totals, and have no `parent` column.
#'
#' County tables (construction by county, school enrolment, registered
#' births and deaths) carry `geo_code`, each row's census frame code, so
#' they join [knbs_geographies()], the census tables and anything passed
#' through [knbs_county_code()]; their total row is `"00"`. Such a table is
#' refused if its rows no longer account for the 47 counties exactly once.
#' Tables that print a unit per row (production of selected commodities)
#' carry it in a `unit` column. The sheets' footnotes and source lines are
#' in [knbs_metadata()]'s notes.
#'
#' The extraction is deliberately strict: if the workbook's layout, sections
#' or pinned reference values no longer match what was verified at curation
#' time, the function stops with `knbs_error_schema_changed` or
#' `knbs_error_validation_failed` rather than guessing — wrong tidy data
#' would be worse than an honest error.
#'
#' @param table A table id from [knbs_abstract_tables()] (for example
#'   `"2.2"`), or enough of a table title to identify one unambiguously.
#' @param cache Whether to use the local cache.
#' @param refresh Whether to re-download the workbook and re-extract.
#'
#' @return A `knbs_abstract_table` tibble. [knbs_metadata()] returns its
#'   provenance, including the workbook file and its SHA-256; [knbs_cite()]
#'   cites it.
#'
#' @seealso [knbs_abstract_tables()]
#'
#' @examples
#' \dontrun{
#' gdp <- knbs_abstract_table("2.2")
#' expenditure <- knbs_abstract_table("expenditure on the gross domestic")
#' }
#' @export
knbs_abstract_table <- function(table,
                                cache = knbs_option("cache"),
                                refresh = FALSE) {
  check_string(table, "table")
  registry <- abstract_registry()
  spec <- abstract_resolve_table(table, registry)
  workbook <- abstract_workbook_spec(registry, spec$workbook_id)
  src <- knbs_source("knbs_publications")

  fetch_table <- function() {
    fetched <- abstract_fetch_workbook(src, workbook, refresh = refresh)
    cells <- abstract_read_sheet(fetched$path, spec$sheet)
    extracted <- extract_abstract_table(cells, spec)
    extracted$table <- abstract_add_counties(extracted$table, spec,
                                             cache = cache, refresh = refresh)
    list(extracted = extracted, fetched = fetched)
  }

  got <- cache_fetch(
    cache_key(
      src$source_id, "abstract_table",
      resource_id = paste(registry$edition, spec$table_id,
                          registry$schema_version, sep = "/")
    ),
    fetch = fetch_table,
    cache = cache,
    refresh = refresh,
    ttl = knbs_cache_ttl("catalogue"),
    info = list(source_id = src$source_id, operation = "abstract_table",
                resource_id = spec$table_id)
  )
  extracted <- got$extracted
  fetched <- got$fetched
  workbook_url <- as.character(fetched$url %||% NA_character_)
  if (is.na(workbook_url) || !nzchar(workbook_url)) {
    workbook_url <- as.character(workbook$index_page)
  }

  new_knbs_data(
    extracted$table,
    new_knbs_metadata(
      title = extracted$title,
      resource_id = spec$table_id,
      resource_type = "table",
      source_id = src$source_id,
      source_name = src$source_name,
      source_url = workbook_url,
      producer = "Kenya National Bureau of Statistics",
      reference_period = paste(
        min(extracted$table$period), "to", max(extracted$table$period)
      ),
      unit = as.character(spec$unit),
      frequency = "annual",
      licence = "Not stated by the source",
      access = "open",
      notes = c(
        paste0("From the ", registry$edition, " Statistical Abstract, ",
               workbook$chapter, "."),
        paste0("Extracted from sheet '", spec$sheet, "' of ",
               workbook$file_name, " (SHA-256 ", substr(fetched$sha256, 1, 12),
               "...)."),
        paste0("status carries the source's own year flags: provisional (*) ",
               "or revised (+)."),
        if (isTRUE(spec$line_numbers)) {
          paste0("line preserves the sheet's own row order; the source ",
                 "repeats some row labels within a section.")
        },
        abstract_hierarchy_notes(spec),
        # The sheet's footnotes and source line, curated with the recipe:
        # stripping a footnote mark from a label must not lose its meaning.
        as.character(unlist(spec$notes %||% character(0))),
        if (isTRUE(spec$county_items)) {
          paste0("geo_code is each county row's census frame code (2019); ",
                 "the total row is \"00\".")
        },
        paste0("Curated extraction: layout anchors and pinned reference ",
               "values are verified on every read, and a changed workbook ",
               "is refused rather than re-interpreted.")
      )
    ),
    class = "knbs_abstract_table"
  )
}

# Internals --------------------------------------------------------------------

#' Read and validate the abstract extraction registry
#' @noRd
abstract_registry <- function(call = rlang::caller_env()) {
  path <- system.file("extdata", "abstract-registry.yml", package = "knbsdata")
  if (!nzchar(path)) {
    path <- file.path("inst", "extdata", "abstract-registry.yml")
  }
  registry <- yaml::read_yaml(path)

  ids <- vapply(registry$tables, function(t) as.character(t$table_id %||% ""),
                character(1))
  workbook_ids <- vapply(registry$workbooks,
                         function(w) as.character(w$workbook_id %||% ""),
                         character(1))
  ok <- length(ids) > 0L && !anyDuplicated(ids) && all(nzchar(ids)) &&
    all(nzchar(workbook_ids)) &&
    all(vapply(registry$tables, function(t) {
      is.character(t$sheet %||% NULL) && is.character(t$anchor %||% NULL) &&
        is.character(t$item_column %||% NULL) &&
        (t$workbook_id %||% "") %in% workbook_ids &&
        (is.null(t$groups) || is.character(t$group_column %||% NULL)) &&
        abstract_hierarchy_valid(t)
    }, logical(1)))
  if (!ok) {
    knbs_abort(
      c("The abstract extraction registry is invalid; please report it."),
      class = "knbs_error_internal",
      call = call
    )
  }
  registry
}

#' Give a county table the census codes of its rows
#'
#' For a table whose recipe says its rows are counties: each county row gets
#' its census frame code through the same matching as [knbs_county_code()],
#' and the recipe's named total rows get `"00"`. The table is refused unless
#' every row is accounted for and every one of the 47 counties appears
#' exactly once - a county table that has lost, doubled or renamed a county
#' beyond recognition no longer matches its curation.
#'
#' @noRd
abstract_add_counties <- function(table, spec, cache = TRUE, refresh = FALSE,
                                  call = rlang::caller_env()) {
  if (!isTRUE(spec$county_items)) {
    return(table)
  }
  item_col <- spec$item_column
  items <- unique(table[[item_col]])
  totals <- as.character(spec$total_items %||% character(0))
  rows <- setdiff(items, totals)
  matched <- county_match(rows, vintage = 2019L,
                          cache = cache, refresh = refresh, call = call)
  # Judged label by label: "Mombasa" and "Mombasa County" share a matching
  # key, and two rows for one county is exactly what must not pass.
  at <- match(county_input_key(rows), matched$key_input)
  by <- matched$matched_by[at]
  is_county <- by %in% "name"
  stray <- rows[!is_county]
  counties <- matched$geo_code[at][is_county]
  missing_codes <- setdiff(sprintf("%02d", 1:47), counties)
  if (length(stray) > 0L || anyDuplicated(counties) > 0L || length(missing_codes) > 0L) {
    knbs_abort(
      c(
        "The county rows of {.val {spec$table_id}} no longer match the 47 counties.",
        if (length(stray) > 0L) c("x" = "Not a county: {.val {stray}}."),
        if (anyDuplicated(counties) > 0L) {
          c("x" = "Counted twice: {.val {unique(counties[duplicated(counties)])}}.")
        },
        if (length(missing_codes) > 0L) c("x" = "Missing county codes: {.val {missing_codes}}."),
        "i" = "The workbook has changed since curation; please report it."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  code_of <- c(stats::setNames(matched$geo_code[at], rows),
               stats::setNames(rep("00", length(totals)), totals))
  tibble::add_column(table, geo_code = unname(code_of[table[[item_col]]]),
                     .after = item_col)
}

#' Provenance notes describing a table's parts-and-totals structure
#' @noRd
abstract_hierarchy_notes <- function(spec) {
  h <- spec$hierarchy
  if (is.null(h)) {
    return(NULL)
  }
  subtracted <- unlist(lapply(h$parents, function(e) {
    vapply(as.character(e$subtract %||% character(0)), function(s) {
      paste0(s, " enters ", e$parent, " with a negative sign.")
    }, character(1), USE.NAMES = FALSE)
  }))
  c(
    paste0("parent names the row each item is a component of; headline ",
           "totals and memo items have none. Rows sharing a parent are its ",
           "parts, so sum within one parent, never across levels."),
    if (isTRUE(h$sums)) {
      paste0("The parts were checked to add up to their parent in every ",
             "year, within rounding.")
    } else {
      "Growth rates do not add; the parts are not summed against their parent."
    },
    subtracted
  )
}

#' Is a table's parts-and-totals structure well formed?
#'
#' Absent is fine. Present, it must name each parent once with at least one
#' part, never list a row under two parents or as its own part, subtract only
#' its own parts, and say how precisely the figures are printed when the sums
#' are to be checked. It describes the item column alone, so a sectioned or
#' line-numbered table cannot carry one.
#'
#' @noRd
abstract_hierarchy_valid <- function(spec) {
  h <- spec$hierarchy
  if (is.null(h)) {
    return(TRUE)
  }
  if (!is.null(spec$groups) || isTRUE(spec$line_numbers)) {
    return(FALSE)
  }
  if (!is.list(h$parents) || length(h$parents) == 0L) {
    return(FALSE)
  }
  if (!is.logical(h$sums) || length(h$sums) != 1L || is.na(h$sums)) {
    return(FALSE)
  }
  if (h$sums && !(is.numeric(h$rounding) && length(h$rounding) == 1L &&
                    !is.na(h$rounding) && h$rounding > 0)) {
    return(FALSE)
  }
  # A total over every other row stands alone; listing parts besides it
  # would make the structure ambiguous.
  others <- vapply(h$parents, function(e) isTRUE(e$all_others), logical(1))
  if (any(others)) {
    e <- h$parents[[1]]
    return(length(h$parents) == 1L && is.character(e$parent) &&
             length(e$parent) == 1L && is.null(e$components) && is.null(e$subtract))
  }
  entries_ok <- all(vapply(h$parents, function(e) {
    is.list(e) && is.character(e$parent) && length(e$parent) == 1L &&
      is.character(e$components) && length(e$components) > 0L &&
      !e$parent %in% e$components &&
      all(as.character(e$subtract %||% character(0)) %in% e$components)
  }, logical(1)))
  if (!entries_ok) {
    return(FALSE)
  }
  parents <- vapply(h$parents, function(e) e$parent, character(1))
  components <- unlist(lapply(h$parents, function(e) e$components))
  !anyDuplicated(parents) && !anyDuplicated(components)
}

#' Resolve a user-supplied table reference against the registry
#' @noRd
abstract_resolve_table <- function(table, registry,
                                   call = rlang::caller_env()) {
  ids <- vapply(registry$tables, function(t) as.character(t$table_id),
                character(1))
  exact <- which(ids == table)
  if (length(exact) == 1L) {
    return(registry$tables[[exact]])
  }

  titles <- vapply(registry$tables, function(t) as.character(t$title),
                   character(1))
  hits <- which(grepl(table, titles, ignore.case = TRUE, fixed = FALSE))
  if (length(hits) == 1L) {
    return(registry$tables[[hits]])
  }
  if (length(hits) > 1L) {
    knbs_abort(
      c(
        "{.val {table}} matches {length(hits)} curated tables.",
        "i" = "Use an exact {.field table_id}:",
        "*" = "{paste(ids[hits], ' - ', substr(titles[hits], 1, 55))}"
      ),
      class = "knbs_error_ambiguous_resource",
      call = call,
      matches = ids[hits]
    )
  }
  knbs_abort(
    c(
      "No curated table matches {.val {table}}.",
      "i" = "List what exists with {.fn knbs_abstract_tables}."
    ),
    class = "knbs_error_resource_not_found",
    call = call
  )
}

#' The workbook entry a table belongs to
#' @noRd
abstract_workbook_spec <- function(registry, workbook_id) {
  for (w in registry$workbooks) {
    if (identical(w$workbook_id, workbook_id)) {
      return(w)
    }
  }
  knbs_abort(
    c("The abstract extraction registry is invalid; please report it."),
    class = "knbs_error_internal"
  )
}

#' Fetch a chapter workbook into the cache directory
#'
#' Resolves the workbook's media record through the publications adapter,
#' downloads it through the verify layer (an HTML page arriving where a
#' spreadsheet was expected is refused), and keeps it beside a small sidecar
#' recording where it came from. Mocked in tests.
#'
#' @return list(path, url, sha256)
#' @noRd
abstract_fetch_workbook <- function(source, workbook, refresh = FALSE,
                                    call = rlang::caller_env()) {
  dir <- file.path(knbs_cache_dir(create = TRUE), "abstract")
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  target <- file.path(dir, paste0(workbook$publication_id, "-",
                                  workbook$file_name))
  sidecar <- paste0(target, ".provenance.json")

  if (refresh || !file.exists(target)) {
    record <- wp_get(source, paste0("media/", workbook$publication_id),
                     call = call)
    url <- as.character(record$source_url %||% "")
    if (!nzchar(url)) {
      knbs_abort(
        c(
          "The workbook's media record carries no file URL.",
          "i" = "The library record changed shape; please report it."
        ),
        class = "knbs_error_schema_changed",
        call = call
      )
    }
    fetched <- download_to_temp(url, source_id = source$source_id, call = call)
    check_download_type(fetched$content_type, workbook$file_name, url,
                        call = call)
    if (!file.copy(fetched$path, target, overwrite = TRUE)) {
      knbs_abort(
        c("Could not place the workbook at {.path {target}}."),
        class = "knbs_error_download_failed",
        call = call
      )
    }
    unlink(fetched$path)
    writeLines(
      jsonlite::toJSON(
        list(url = url, downloaded_at = format(Sys.time(), tz = "UTC")),
        auto_unbox = TRUE
      ),
      sidecar
    )
  }

  url <- NA_character_
  if (file.exists(sidecar)) {
    recorded <- tryCatch(
      jsonlite::fromJSON(sidecar),
      error = function(cnd) NULL
    )
    url <- as.character(recorded$url %||% NA_character_)
  }
  list(
    path = target,
    url = url,
    sha256 = digest::digest(file = target, algo = "sha256")
  )
}

#' Read one sheet of a workbook as text cells
#' @noRd
abstract_read_sheet <- function(path, sheet, call = rlang::caller_env()) {
  if (!sheet %in% readxl::excel_sheets(path)) {
    knbs_abort(
      c(
        "The workbook no longer carries a sheet named {.val {sheet}}.",
        "i" = "Its layout has changed; please report it."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  readxl::read_excel(path, sheet = sheet, col_names = FALSE,
                     col_types = "text", .name_repair = "minimal")
}
