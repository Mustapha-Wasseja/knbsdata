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
#' Curated so far: Chapter 2 (National Accounts) of the 2025 edition — the
#' production accounts, GDP by activity at current and constant prices,
#' expenditure on GDP, capital formation, national income and saving.
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
        (is.null(t$groups) || is.character(t$group_column %||% NULL))
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
