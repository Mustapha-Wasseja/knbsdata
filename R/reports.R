# KNBS report tables: public interface ------------------------------------------
#
# Tables printed in KNBS reports published as PDF - the Gross County Product
# reports first - read from the KNBS publications library and extracted by
# curated recipe (R/pdf-extract.R, inst/extdata/report-registry.yml, audit
# F-46). Nothing is bundled: a table is read from the report as KNBS serves
# it, and refused if it no longer matches what was checked at curation.

#' List the curated tables of KNBS reports
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' KNBS publishes some of its data only as tables printed in PDF reports.
#' This lists the tables the package has curated: each has a hand-checked
#' recipe - the report, the title it is found by, its columns, its unit and
#' figures read by hand - so that [knbs_report_table()] can return it as tidy
#' observations, or refuse with a clear error if the report has changed.
#'
#' Curated so far: the Gross County Product reports of 2019, 2021, 2023,
#' 2024 and 2025 - county GDP at current and constant prices, each county's
#' share of gross value added, per-capita GCP (2019) and the county
#' population tables (2024, 2025).
#'
#' @param series Keep only these report series, for example `"gcp"`.
#'
#' @return A `knbs_catalogue` tibble with columns `table_id`, `series`,
#'   `edition`, `publisher`, `printed`, `title`, `measure`, `prices`,
#'   `base_year`, `unit`, `periods` and `report`.
#'
#' @seealso [knbs_report_table()], [knbs_gcp()], [knbs_county_population()]
#'
#' @examples
#' knbs_report_tables()
#' knbs_report_tables(series = "gcp")
#' @export
knbs_report_tables <- function(series = NULL) {
  if (!is.null(series)) check_character(series, "series")
  registry <- report_registry()
  tables <- registry$tables
  report_of <- function(t) report_spec(registry, t$report_id)
  chr <- function(x) if (is.null(x)) NA_character_ else as.character(x)
  out <- tibble::tibble(
    table_id = vapply(tables, function(t) t$table_id, character(1)),
    series = vapply(tables, function(t) chr(report_of(t)$series), character(1)),
    edition = vapply(tables, function(t) as.integer(report_of(t)$edition), integer(1)),
    publisher = vapply(tables, function(t) {
      chr(report_of(t)$publisher %||% "Kenya National Bureau of Statistics")
    }, character(1)),
    printed = vapply(tables, function(t) chr(t$printed), character(1)),
    title = vapply(tables, function(t) chr(t$title), character(1)),
    measure = vapply(tables, function(t) chr(t$measure), character(1)),
    prices = vapply(tables, function(t) chr(t$prices), character(1)),
    base_year = vapply(tables, function(t) {
      if (is.null(t$base_year)) NA_integer_ else as.integer(t$base_year)
    }, integer(1)),
    unit = vapply(tables, function(t) chr(t$unit), character(1)),
    periods = vapply(tables, function(t) {
      years <- stats::na.omit(pdf_columns(t)$period)
      if (length(years) == 0L) NA_character_ else paste(min(years), max(years), sep = "-")
    }, character(1)),
    report = vapply(tables, function(t) chr(report_of(t)$title), character(1))
  )
  if (!is.null(series)) {
    out <- out[out$series %in% series, ]
  }
  new_knbs_catalogue(
    out,
    new_knbs_metadata(
      title = "KNBS report tables: curated",
      resource_type = "table",
      source_id = "knbs_publications",
      source_name = "KNBS Publications (website media library)",
      source_url = "https://www.knbs.or.ke/",
      producer = "Kenya National Bureau of Statistics",
      licence = "Not stated by the source",
      access = "open",
      notes = paste0(
        "Each listed table has a hand-checked extraction recipe; ",
        "knbs_report_table() refuses a report that no longer matches it."
      )
    )
  )
}

#' Retrieve one curated table of a KNBS report as tidy observations
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Downloads the report from the KNBS publications library (cached locally),
#' reads the pages the table is on, extracts it by its curated recipe and
#' verifies it, and returns one row per county per column of the printed
#' table.
#'
#' @details
#' Every read verifies the table: all 47 counties and the total are present
#' exactly once (matched to their 2019 census codes, whatever the spelling
#' or line wrapping in the report); the counties add up to the printed total
#' within what rounding to the printed precision can explain - shares to
#' 100; and figures read by hand at curation time are unchanged. A table that
#' fails any of these is refused with `knbs_error_schema_changed` or
#' `knbs_error_validation_failed` rather than returned - wrong tidy data
#' would be worse than an honest error.
#'
#' `geo_code` is each county's census code, so these tables join
#' [knbs_geographies()], the census tables, the county Statistical Abstract
#' tables and the DHS county indicators; the total row is `"00"`. `period`
#' is the year a column describes, `NA` for columns that are not one year
#' (an average). `status` carries the report's own marks: `"provisional"`
#' for a year printed with an asterisk.
#'
#' Reports revise earlier years, and the Gross County Product reports
#' changed base year with the 2016 rebasing of the national accounts: the
#' 2019 edition's constant prices are 2009 prices, later editions' 2016
#' prices. Each table keeps its edition and `base_year`; never splice
#' constant-price figures across base years.
#'
#' Some reports cannot be fetched by a program: the Controller of Budget's
#' website answers programs with a bot check, which the package does not get
#' past. Their tables are read from a copy of the report you download in a
#' browser and pass as `file`; the copy must be the edition the recipe was
#' made from, and is checked like any other. The verified data from those
#' reports also ship with the package: see [knbs_county_budget()].
#'
#' @param table A table id from [knbs_report_tables()], such as
#'   `"gcp-2025-current"`, or enough of its title to identify one table.
#' @param file For a report the package cannot fetch, the path to your copy
#'   of it. Ignored for reports fetched from the KNBS library.
#' @param cache Whether to use the local cache.
#' @param refresh Whether to re-download the report and re-extract.
#'
#' @return A `knbs_report_table` tibble with columns `table_id`, `geo_code`,
#'   `county`, `period`, `column`, `measure`, `prices`, `base_year`, `unit`,
#'   `status`, `value`, `edition` and `source_id`. [knbs_metadata()] gives
#'   its provenance, including the report file, its SHA-256 and the pages
#'   read; [knbs_cite()] cites it.
#'
#' @seealso [knbs_report_tables()], [knbs_gcp()]
#'
#' @examplesIf interactive()
#' gcp <- knbs_report_table("gcp-2025-current")
#' population <- knbs_report_table("gcp-2025-population")
#' @export
knbs_report_table <- function(table,
                              file = NULL,
                              cache = knbs_option("cache"),
                              refresh = FALSE) {
  check_string(table, "table")
  registry <- report_registry()
  spec <- report_resolve_table(table, registry)
  report <- report_spec(registry, spec$report_id)
  src <- knbs_source("knbs_publications")

  if (isTRUE(report$file_only)) {
    fetched <- report_local_file(file, report)
    extracted <- report_extract(fetched$path, spec)
    return(report_as_data(extracted, fetched, spec, report, src))
  }

  got <- cache_fetch(
    cache_key(src$source_id, "report_table",
              resource_id = paste(spec$table_id, registry$schema_version,
                                  report_recipe_hash(spec), sep = "/")),
    fetch = function() {
      fetched <- report_fetch_pdf(src, report, refresh = refresh)
      extracted <- report_extract(fetched$path, spec)
      list(extracted = extracted, fetched = fetched)
    },
    cache = cache,
    refresh = refresh,
    ttl = knbs_cache_ttl("catalogue"),
    info = list(source_id = src$source_id, operation = "report_table",
                resource_id = spec$table_id)
  )
  report_as_data(got$extracted, got$fetched, spec, report, src)
}

#' Gross County Product: county GDP from the KNBS reports
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The size of each county's economy, from the Gross County Product reports
#' KNBS publishes each year: GCP at current or constant prices, each
#' county's share of gross value added, or per-capita GCP, for the 47
#' counties and Kenya, with the counties' 2019 census codes.
#'
#' @details
#' Each edition covers five to eight years and revises the years before it.
#' `edition = "latest"` (the default) returns the newest edition that has
#' the measure; `edition = "all"` returns every edition, one block per
#' edition, so that revisions can be compared; or name the editions wanted.
#'
#' Constant prices are 2009 prices in the 2019 edition and 2016 prices from
#' the 2021 edition on, after the national accounts were rebased; the
#' `base_year` column says which. Figures from editions with different base
#' years must not be spliced into one series.
#'
#' Per-capita GCP is published only in the 2019 edition. County shares are
#' returned for single years; each report's average over its years is in
#' [knbs_report_table()].
#'
#' @param measure `"gcp"` (KSh million), `"share"` (percent of gross value
#'   added) or `"per_capita"` (KSh).
#' @param prices `"current"` or `"constant"`; ignored for shares.
#' @param edition `"latest"`, `"all"`, or edition years such as `2024`.
#' @inheritParams knbs_report_table
#'
#' @return A `knbs_report_table` tibble with columns `geo_code`, `county`,
#'   `period`, `value`, `measure`, `prices`, `base_year`, `unit`, `status`,
#'   `edition`, `table_id` and `source_id`.
#'
#' @seealso [knbs_report_table()] for any single curated table,
#'   [knbs_county_population()] for the reports' population tables.
#'
#' @examplesIf interactive()
#' gcp <- knbs_gcp()
#' real <- knbs_gcp(prices = "constant")
#' shares <- knbs_gcp("share", edition = "all")
#' @export
knbs_gcp <- function(measure = c("gcp", "share", "per_capita"),
                     prices = c("current", "constant"),
                     edition = "latest",
                     cache = knbs_option("cache"),
                     refresh = FALSE) {
  measure <- rlang::arg_match(measure)
  prices <- rlang::arg_match(prices)
  wanted <- c(gcp = "gcp", share = "gva_share", per_capita = "gcp_per_capita")[[measure]]
  catalogue <- tibble::as_tibble(knbs_report_tables(series = "gcp"))
  rows <- catalogue[catalogue$measure %in% wanted &
                      (wanted == "gva_share" | catalogue$prices %in% prices), ]
  rows <- report_pick_editions(rows, edition, what = paste(measure, if (wanted != "gva_share") prices))

  parts <- lapply(rows$table_id, knbs_report_table, cache = cache, refresh = refresh)
  out <- do.call(rbind, lapply(parts, function(p) {
    p <- tibble::as_tibble(p)
    p[p$measure == wanted, ]
  }))
  out <- out[order(-out$edition, out$geo_code == "00", out$geo_code, out$period),
             c("geo_code", "county", "period", "value", "measure", "prices", "base_year",
               "unit", "status", "edition", "table_id", "source_id")]
  report_combine_metadata(out, parts, title = paste0(
    "Gross County Product: ",
    c(gcp = "GCP", share = "county share of gross value added",
      per_capita = "per-capita GCP")[[measure]],
    if (wanted != "gva_share") paste0(", ", prices, " prices"),
    " (", paste(sort(unique(out$edition)), collapse = ", "), " edition",
    if (length(unique(out$edition)) > 1L) "s", ")"
  ))
}

#' County population from the Gross County Product reports
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Each county's 2019 census population and KNBS's projections for the
#' years since, with land area and 2019 population density, as printed in
#' the Gross County Product reports - the annual county-year population
#' denominators for per-capita figures.
#'
#' @details
#' `measure` says what each row is: `"population_census"` (the 2019 Kenya
#' Population and Housing Census), `"population_projected"`,
#' `"land_area"` (square kilometres) and `"population_density"` (persons per
#' square kilometre, 2019). The 2025 edition projects 2020-2024, the 2024
#' edition 2020-2023; a newer edition's projections supersede an older
#' one's.
#'
#' @param edition `"latest"`, `"all"`, or edition years such as `2024`.
#' @inheritParams knbs_report_table
#'
#' @return A `knbs_report_table` tibble with columns `geo_code`, `county`,
#'   `period`, `value`, `measure`, `unit`, `edition`, `table_id` and
#'   `source_id`.
#'
#' @seealso [knbs_gcp()]; [knbs_get_indicator()] for the census tables.
#'
#' @examplesIf interactive()
#' population <- knbs_county_population()
#' @export
knbs_county_population <- function(edition = "latest",
                                   cache = knbs_option("cache"),
                                   refresh = FALSE) {
  catalogue <- tibble::as_tibble(knbs_report_tables(series = "gcp"))
  rows <- report_pick_editions(catalogue[catalogue$measure %in% "population", ],
                               edition, what = "county population")
  parts <- lapply(rows$table_id, knbs_report_table, cache = cache, refresh = refresh)
  out <- do.call(rbind, lapply(parts, tibble::as_tibble))
  out <- out[order(-out$edition, out$geo_code == "00", out$geo_code, out$measure, out$period),
             c("geo_code", "county", "period", "value", "measure", "unit", "edition",
               "table_id", "source_id")]
  report_combine_metadata(out, parts, title = paste0(
    "County population: 2019 census and projections (",
    paste(sort(unique(out$edition)), collapse = ", "), " edition",
    if (length(unique(out$edition)) > 1L) "s", ")"
  ))
}

# Internals --------------------------------------------------------------------

#' Read and validate the report table registry
#' @noRd
report_registry <- function(call = rlang::caller_env()) {
  path <- system.file("extdata", "report-registry.yml", package = "knbsdata")
  if (!nzchar(path)) {
    path <- file.path("inst", "extdata", "report-registry.yml")
  }
  registry <- yaml::read_yaml(path)
  report_ids <- vapply(registry$reports, function(r) as.character(r$report_id %||% ""), "")
  table_ids <- vapply(registry$tables, function(t) as.character(t$table_id %||% ""), "")
  ok <- length(table_ids) > 0L && all(nzchar(table_ids)) && !anyDuplicated(table_ids) &&
    all(nzchar(report_ids)) && !anyDuplicated(report_ids) &&
    all(vapply(registry$reports, function(r) {
      # A report is fetched from the KNBS library by its media id, or read
      # from a file the user supplies when its publisher's site cannot be
      # reached by programs.
      fetchable <- is.character(r$publication_id %||% NULL) ||
        (isTRUE(r$file_only) && is.character(r$publisher %||% NULL))
      fetchable && is.character(r$file_name %||% NULL) && is.character(r$sha256 %||% NULL)
    }, logical(1))) &&
    all(vapply(registry$tables, function(t) {
      (t$report_id %||% "") %in% report_ids && is.character(t$anchor %||% NULL) &&
        length(t$pages %||% NULL) > 0L && length(t$columns %||% NULL) > 0L &&
        all(vapply(t$pins %||% list(), function(p) {
          as.character(p$column) %in% sub("[*+]+$", "", vapply(t$columns, function(c) {
            if (is.list(c)) as.character(c$label) else as.character(c)
          }, ""))
        }, logical(1)))
    }, logical(1)))
  if (!ok) {
    knbs_abort(
      c("The report table registry is invalid; please report it."),
      class = "knbs_error_internal",
      call = call
    )
  }
  registry
}

#' The report entry a table belongs to
#' @noRd
report_spec <- function(registry, report_id) {
  for (r in registry$reports) {
    if (identical(r$report_id, report_id)) {
      return(r)
    }
  }
  knbs_abort(c("The report table registry is invalid; please report it."),
             class = "knbs_error_internal")
}

#' Resolve a table reference: an exact id, or words of a title
#'
#' Matched as plain words, like [knbs_abstract_table()]'s titles.
#'
#' @noRd
report_resolve_table <- function(table, registry, call = rlang::caller_env()) {
  ids <- vapply(registry$tables, function(t) t$table_id, character(1))
  exact <- which(tolower(ids) == tolower(trimws(table)))
  if (length(exact) == 1L) {
    return(registry$tables[[exact]])
  }
  titles <- vapply(registry$tables, function(t) {
    r <- report_spec(registry, t$report_id)
    paste(r$title, t$printed, t$title)
  }, character(1))
  key <- abstract_lookup_key(table)
  hits <- which(grepl(key, abstract_lookup_key(titles), fixed = TRUE))
  if (length(hits) == 1L) {
    return(registry$tables[[hits]])
  }
  if (length(hits) > 1L) {
    literal <- function(s) gsub("([{}])", "\\1\\1", s)
    shown <- utils::head(hits, 10L)
    knbs_abort(
      c(
        "{.val {table}} matches {length(hits)} curated report tables.",
        "i" = "Choose one by its {.field table_id}:",
        stats::setNames(sprintf("{.code knbs_report_table(\"%s\")}: %s",
                                literal(ids[shown]), literal(titles[shown])),
                        rep("*", length(shown))),
        if (length(hits) > 10L) c(" " = "... and {length(hits) - 10L} more.")
      ),
      class = "knbs_error_ambiguous_resource",
      call = call,
      matches = ids[hits]
    )
  }
  knbs_abort(
    c("No curated report table matches {.val {table}}.",
      "i" = "List what exists with {.fn knbs_report_tables}."),
    class = "knbs_error_resource_not_found",
    call = call
  )
}

#' A short fingerprint of a recipe, so a changed recipe is never served from
#' a cache filled by the old one
#' @noRd
report_recipe_hash <- function(spec) {
  substr(digest::digest(spec, algo = "sha256"), 1L, 12L)
}

#' Choose the tables of the editions asked for
#' @noRd
report_pick_editions <- function(rows, edition, what, call = rlang::caller_env()) {
  if (nrow(rows) == 0L) {
    knbs_abort(c("No curated report table holds {what}."),
               class = "knbs_error_resource_not_found", call = call)
  }
  if (identical(edition, "latest")) {
    return(rows[rows$edition == max(rows$edition), ])
  }
  if (identical(edition, "all")) {
    return(rows[order(-rows$edition), ])
  }
  years <- suppressWarnings(as.integer(edition))
  if (anyNA(years) || length(years) == 0L) {
    knbs_abort(
      c("{.arg edition} must be {.val latest}, {.val all} or edition years.",
        "x" = "Got {.val {as.character(edition)}}."),
      class = "knbs_error_invalid_argument", call = call
    )
  }
  missing <- setdiff(years, rows$edition)
  if (length(missing) > 0L) {
    knbs_abort(
      c("No curated edition {.val {missing}} holds {what}.",
        "i" = "Editions with it: {.val {sort(unique(rows$edition))}}."),
      class = "knbs_error_resource_not_found", call = call
    )
  }
  rows[rows$edition %in% years, ]
}

#' Fetch a report PDF into the cache directory
#'
#' As abstract_fetch_workbook(): the media record through the publications
#' adapter, the file through the verify layer, a provenance sidecar beside
#' it. Mocked in tests.
#'
#' @return list(path, url, sha256)
#' @noRd
report_fetch_pdf <- function(source, report, refresh = FALSE, call = rlang::caller_env()) {
  dir <- file.path(knbs_cache_dir(create = TRUE), "reports")
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  target <- file.path(dir, paste0(report$publication_id, "-", report$file_name))
  sidecar <- paste0(target, ".provenance.json")

  if (refresh || !file.exists(target)) {
    record <- wp_get(source, paste0("media/", report$publication_id), call = call)
    url <- as.character(record$source_url %||% "")
    if (!nzchar(url)) {
      knbs_abort(
        c("The report's media record carries no file URL.",
          "i" = "The library record changed shape; please report it."),
        class = "knbs_error_schema_changed",
        call = call
      )
    }
    fetched <- download_to_temp(url, source_id = source$source_id, call = call)
    check_download_type(fetched$content_type, report$file_name, url, call = call)
    if (!file.copy(fetched$path, target, overwrite = TRUE)) {
      knbs_abort(c("Could not place the report at {.path {target}}."),
                 class = "knbs_error_download_failed", call = call)
    }
    unlink(fetched$path)
    writeLines(
      jsonlite::toJSON(list(url = url, downloaded_at = format(Sys.time(), tz = "UTC")),
                       auto_unbox = TRUE),
      sidecar
    )
  }
  url <- NA_character_
  if (file.exists(sidecar)) {
    recorded <- tryCatch(jsonlite::fromJSON(sidecar), error = function(cnd) NULL)
    url <- as.character(recorded$url %||% NA_character_)
  }
  list(path = target, url = url, sha256 = digest::digest(file = target, algo = "sha256"))
}

#' Check a report file the user supplies
#'
#' For a report the package cannot fetch. The file must exist and be a PDF;
#' a copy that is not byte-for-byte the curated file is still read - the
#' table checks decide - and the provenance says it differs.
#'
#' @return list(path, url, sha256), as report_fetch_pdf().
#' @noRd
report_local_file <- function(file, report, call = rlang::caller_env()) {
  if (is.null(file)) {
    knbs_abort(
      c(
        "{report$title} cannot be fetched by the package.",
        "i" = "{report$publisher}'s website answers programs with a bot check, which the package does not get past.",
        "i" = "Download the report in a browser and pass it as {.arg file}.",
        "i" = "Its verified figures also ship with the package: see {.fn knbs_county_budget}."
      ),
      class = "knbs_error_access_restricted",
      call = call
    )
  }
  check_string(file, "file")
  if (!file.exists(file)) {
    knbs_abort(c("{.arg file} does not exist.", "x" = "{.path {file}}"),
               class = "knbs_error_invalid_argument", call = call)
  }
  head <- readBin(file, "raw", 5L)
  if (!identical(rawToChar(head[seq_len(min(4L, length(head)))]), "%PDF")) {
    knbs_abort(c("{.arg file} is not a PDF.", "x" = "{.path {file}}"),
               class = "knbs_error_invalid_argument", call = call)
  }
  list(path = normalizePath(file), url = as.character(report$landing_page %||% NA_character_),
       sha256 = digest::digest(file = file, algo = "sha256"))
}

#' Extract a table from a report file
#'
#' Reads the recipe's pages and two after; if the title is not there - the
#' report was re-laid out - the whole report is searched.
#'
#' @noRd
report_extract <- function(path, spec, call = rlang::caller_env()) {
  window <- unlist(spec$pages)
  window <- seq(min(window), max(window) + 2L)
  found <- extract_pdf_county_table(pdf_pages(path, window, call = call), spec, call = call)
  if (is.null(found)) {
    found <- extract_pdf_county_table(pdf_pages(path, call = call), spec, call = call)
  }
  if (is.null(found)) {
    knbs_abort(
      c("Could not find {.val {spec$table_id}} ({spec$printed}) in the report.",
        "x" = "No page carries {.val {spec$anchor}} followed by its rows.",
        "i" = "The report has changed since curation; please report it."),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  found
}

#' Turn an extracted table into a knbs_report_table with its provenance
#' @noRd
report_as_data <- function(extracted, fetched, spec, report, src) {
  table <- extracted$table
  statutory <- county_statutory()
  county <- statutory$geo_name[match(table$geo_code, statutory$geo_code)]
  county[table$geo_code == "00"] <- "Kenya"
  out <- tibble::tibble(
    table_id = spec$table_id,
    geo_code = table$geo_code,
    county = county,
    period = table$period,
    column = table$column,
    measure = table$measure,
    prices = as.character(spec$prices %||% NA_character_),
    base_year = if (is.null(spec$base_year)) NA_integer_ else as.integer(spec$base_year),
    unit = table$unit,
    status = table$status,
    value = table$value,
    edition = as.integer(report$edition),
    source_id = if (isTRUE(report$file_only)) report_source_id(report) else src$source_id
  )
  url <- as.character(fetched$url %||% NA_character_)
  if (is.na(url) || !nzchar(url)) url <- as.character(report$landing_page)
  years <- stats::na.omit(out$period)
  same_file <- identical(fetched$sha256, as.character(report$sha256 %||% ""))
  publisher <- as.character(report$publisher %||% "Kenya National Bureau of Statistics")
  new_knbs_data(
    out,
    new_knbs_metadata(
      title = paste0(report$title, ", ", spec$printed, ": ", spec$title),
      resource_id = spec$table_id,
      resource_type = "table",
      source_id = if (isTRUE(report$file_only)) report_source_id(report) else src$source_id,
      source_name = if (isTRUE(report$file_only)) publisher else src$source_name,
      source_url = url,
      producer = publisher,
      reference_period = if (length(years)) paste(min(years), "to", max(years)) else NULL,
      unit = as.character(spec$unit),
      frequency = "annual",
      licence = "Not stated by the source",
      access = "open",
      notes = c(
        paste0("From ", report$title, " (", report$file_name, ", SHA-256 ",
               substr(fetched$sha256, 1, 12), "...), ", spec$printed, ", pages ",
               paste(extracted$pages, collapse = ", "), "."),
        if (!same_file) {
          paste0("The file differs from the one curated (SHA-256 ",
                 substr(as.character(report$sha256 %||% ""), 1, 12),
                 "...); every check below still passed.")
        },
        if (!is.null(spec$base_year)) {
          paste0("Constant prices are ", spec$base_year, " prices; do not splice them ",
                 "with figures at another base year.")
        },
        if (any(out$status %in% "provisional")) {
          "status marks the years the report prints as provisional (*)."
        },
        "geo_code is each county's 2019 census code; the total row is \"00\".",
        paste0("Curated extraction: the 47 counties and the total are read exactly ",
               "once, the counties are checked against the total within rounding, ",
               "and pinned figures are verified on every read.")
      )
    ),
    class = "knbs_report_table"
  )
}

#' The source id of a report read from a file the user supplies: its
#' publisher, as a snake-case id
#' @noRd
report_source_id <- function(report) {
  switch(as.character(report$series),
         cob = "controller_of_budget",
         gsub("[^a-z0-9]+", "_", tolower(as.character(report$publisher))))
}

#' Stack several report tables, with metadata naming all of them
#' @noRd
report_combine_metadata <- function(out, parts, title) {
  metas <- lapply(parts, knbs_metadata)
  first <- metas[[1]]
  years <- stats::na.omit(out$period)
  new_knbs_data(
    out,
    new_knbs_metadata(
      title = title,
      resource_id = paste(vapply(metas, function(m) m$resource_id, ""), collapse = ", "),
      resource_type = "table",
      source_id = first$source_id,
      source_name = first$source_name,
      source_url = first$source_url,
      producer = first$producer,
      reference_period = if (length(years)) paste(min(years), "to", max(years)) else NULL,
      unit = paste(unique(stats::na.omit(out$unit)), collapse = "; "),
      frequency = "annual",
      licence = first$licence,
      access = "open",
      notes = unique(unlist(lapply(metas, function(m) m$notes)))
    ),
    class = "knbs_report_table"
  )
}
