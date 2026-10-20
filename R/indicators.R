# Indicators: public interface ------------------------------------------------

#' List available aggregate indicators
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Lists the indicators served by every verified indicator source: the 2019
#' Population and Housing Census tables (CC BY 4.0), the monthly consumer
#' price series from the KNBS CPI Explorer, the KNBS Data Portal's SDMX
#' dataflows, the datasets republished by Kenya Open Data for Africa, and
#' the Kenya Demographic and Health Survey and Malaria Indicator Survey
#' indicators published by the DHS Program. The `source_id` column says which
#' source serves each row.
#'
#' @details
#' `frequency` and `unit` are filled only where the source states them: the
#' CPI series are monthly, in index points or percent; a census table is not a
#' recurring series, so its `frequency` and `unit` are `NA` rather than
#' invented.
#'
#' If one source cannot be reached, its rows are missing and a warning says
#' so; the error comes only when no source answers.
#'
#' @param topic Keep only these topics, for example `"Population"` or
#'   `"prices"`.
#' @param search Free text matched against indicator names.
#' @param source Source id. Defaults to every verified source that lists
#'   indicators.
#' @param cache Whether to use the local cache.
#' @param refresh Whether to bypass any cached response.
#'
#' @return A `knbs_catalogue` tibble with columns `indicator_id`,
#'   `indicator_name`, `topic`, `frequency`, `unit` and `source_id`.
#'
#' @seealso [knbs_get_indicator()]
#'
#' @examplesIf interactive()
#' knbs_indicators()
#' knbs_indicators(topic = "prices")
#' knbs_indicators(search = "marital")
#' @export
knbs_indicators <- function(topic = NULL,
                            search = NULL,
                            source = NULL,
                            cache = knbs_option("cache"),
                            refresh = FALSE) {
  if (!is.null(topic)) check_character(topic, "topic")
  if (!is.null(search)) check_string(search, "search")

  sources <- resolve_indicator_sources(source)

  results <- list()
  failures <- character(0)
  conditions <- list()
  for (src in sources) {
    query <- new_knbs_query(
      "indicator",
      filters = compact_list(list(topic = topic, search = search)),
      source = src$source_id
    )
    outcome <- tryCatch(
      cache_fetch(
        cache_key(src$source_id, "list_indicators", query),
        fetch = function() source_search(src, query),
        cache = cache,
        refresh = refresh,
        ttl = knbs_cache_ttl("catalogue"),
        info = list(source_id = src$source_id, operation = "list_indicators")
      ),
      knbs_error = function(cnd) cnd
    )
    if (inherits(outcome, "knbs_error")) {
      failures <- c(failures, src$source_id)
      conditions[[src$source_id]] <- outcome
    } else {
      results[[src$source_id]] <- outcome
    }
  }

  if (length(results) == 0L) {
    if (length(conditions) == 1L) {
      # A single source was asked and it failed: its own condition says why,
      # and flattening it to a generic "unreachable" would hide a schema
      # change behind an availability message.
      rlang::cnd_signal(conditions[[1]])
    }
    knbs_abort(
      c(
        "No indicator source could be reached.",
        "x" = paste0("Did not answer: ", paste(failures, collapse = ", "), ".")
      ),
      class = "knbs_error_source_unavailable"
    )
  }
  if (length(failures) > 0L) {
    knbs_warn(
      c(
        paste0("Could not reach: ", paste(failures, collapse = ", "), "."),
        "i" = "The catalogue below is missing those indicators."
      ),
      class = "knbs_warning_partial_failure",
      unreachable = failures
    )
  }

  combined <- do.call(rbind, lapply(unname(results), tibble::as_tibble))
  first_meta <- knbs_metadata(results[[1]])

  new_knbs_catalogue(
    combined,
    new_knbs_metadata(
      title = "KNBS indicator catalogue",
      resource_type = "indicator",
      producer = first_meta$producer,
      access = "open",
      notes = paste0(
        "Sources: ", paste(names(results), collapse = ", "),
        if (length(failures) > 0L) {
          paste0(". Unreachable: ", paste(failures, collapse = ", "), ".")
        } else {
          "."
        }
      )
    )
  )
}

#' Retrieve an indicator as tidy observations
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Returns one row per observation, in one schema whichever source serves
#' the indicator: a census table, a consumer price series, a Data Portal
#' dataflow, a republished dataset or a DHS Program survey indicator.
#'
#' @details
#' The period convention follows the source's own frequency. Monthly series
#' (the CPI family) carry `period` as a `Date` at the first of the month plus
#' a `period_label` like `"2026-06"`; census tables carry the census year as
#' an integer `period`. `start` and `end` accept a year (`2020`), a month
#' (`"2020-01"`), or a full date, and apply to both conventions.
#'
#' Geography differs by family and the two systems must not be mixed. Census
#' tables use territory codes (`geo_level` of `"national"`, `"county"`,
#' `"subcounty"`) that join [knbs_geographies()]. The CPI series use the CPI
#' collection strata (`geo_level` of `"national"` or `"region"`: the Nairobi
#' income bands, Rest of Urban, and the former provinces) — their codes are
#' the source's own and must never be joined against census territories. Six
#' listed CPI regions, the former provinces, carry no data in any period;
#' asking for them returns zero rows because that is the source's answer.
#'
#' For the CPI family the default is the national series; ask for
#' `geo_level = "region"` or name `geo_code`s for more. The CPI portal states
#' no licence and no index base period; [knbs_metadata()] on the result says
#' so. If the CPI Explorer is down, the error names the KNBS Data Portal
#' series that stands in for the one asked for, and how closely: the portal's
#' index has matched it, its rounded inflation rates have not always.
#'
#' DHS Program indicators (`source = "dhs_program"`) come with a row for
#' every survey that measured them, 1989 to 2022, with `period` the survey
#' year and `survey` naming it ("2022 DHS", "2020 MIS"). `characteristic_type`
#' and `characteristic` say which group a value describes: the `"Total"`, a
#' background characteristic such as `"Wealth quintile"` or `"Residence"`
#' (for Kenya as a whole), or a `"Region"`. Region rows are the former
#' provinces, or malaria zones, at `geo_level` `"region"` with no code; from
#' 2014 the 47 counties are `geo_level` `"county"` with 2019 census codes,
#' so they join the census tables. Where the DHS Program gives a value for
#' more than one reference period, every value is kept and `preferred` marks
#' the one it prefers: keep `preferred` rows for one value per survey and
#' group.
#'
#' Every other dimension of a table becomes a pair of columns, `<name>`
#' holding the source's labels and `<name>_code` its codes, the way
#' `geo_name` and `geo_code` pair up. Census tables use short curated names
#' (`marital_status`, `age`, `religion`, ...); Data Portal flows use their
#' SDMX dimension id in lower case (`na_indic`, `commodity`); Open Data for
#' Africa datasets use the portal's dimension id (`table`, `indicator`). A
#' Sex dimension is always `sex`, in lower case. The census age table mixes
#' single years with five-year groups, so it carries `age_type`
#' (`"total"`, `"single_year"`, `"age_group"`, `"other"`): keep one type
#' before summing.
#'
#' @param indicator An indicator id (see [knbs_indicators()]), or enough of an
#'   indicator name to identify one unambiguously.
#' @param start,end Keep only observations in this period range. A year, a
#'   `"YYYY-MM"` month, or a date.
#' @param geo_level Keep only these levels. Census tables: `"national"`,
#'   `"county"`, `"subcounty"`. CPI series: `"national"`, `"region"`. DHS
#'   Program indicators: `"national"`, `"region"`, `"county"`.
#' @param geo_code Keep only these codes, as character, in the indicator's own
#'   geography.
#' @param frequency Keep only series of this frequency: `"annual"`,
#'   `"quarterly"` or `"monthly"`. Only the Open Data for Africa source
#'   accepts it — its datasets may carry annual and sub-annual series side by
#'   side, and a mixed dataset asks you to choose rather than picking one
#'   silently.
#' @param source Source id, to disambiguate an indicator served by more than
#'   one source.
#' @param cache Whether to use the local cache.
#' @param refresh Whether to bypass any cached response.
#'
#' @return A `knbs_indicator` tibble. [knbs_metadata()] returns its
#'   provenance; [knbs_cite()] cites it.
#'
#' @seealso [knbs_indicators()], [knbs_geographies()]
#'
#' @examplesIf interactive()
#' cpi <- knbs_get_indicator("CPI_ALL_ITEMS", start = "2020-01")
#' inflation <- knbs_get_indicator("CPI_INFLATION_YOY", geo_level = "region")
#' pop <- knbs_get_indicator("POPCEN0001", geo_level = "county")
#' gcp <- knbs_get_indicator("jhbzkjc") # Gross County Product
#' stunting <- knbs_get_indicator("CN_NUTS_C_HA2", geo_level = "county") # KDHS
#' @export
knbs_get_indicator <- function(indicator,
                               start = NULL,
                               end = NULL,
                               geo_level = NULL,
                               geo_code = NULL,
                               frequency = NULL,
                               source = NULL,
                               cache = knbs_option("cache"),
                               refresh = FALSE) {
  check_string(indicator, "indicator")
  if (!is.null(geo_level)) {
    check_values(
      geo_level, "geo_level",
      c("national", "county", "subcounty", "region")
    )
  }
  if (!is.null(geo_code)) check_character(geo_code, "geo_code")
  if (!is.null(frequency)) {
    check_string(frequency, "frequency")
    check_values(frequency, "frequency", c("annual", "quarterly", "monthly"))
  }
  bounds <- normalise_period_bounds(start, end)

  resolved <- resolve_indicator(indicator, source = source,
                                cache = cache, refresh = refresh)
  src <- knbs_source(resolved$source_id)

  filters <- compact_list(list(geo_level = geo_level, geo_code = geo_code,
                               frequency = frequency))
  if (identical(src$adapter, "cpiexplorer")) {
    # Passed as strings so equivalent requests share a cache key; the adapter
    # parses them back.
    filters$start <- format(bounds$from, "%Y-%m")
    filters$end <- format(bounds$to, "%Y-%m")
  }

  query <- new_knbs_query(
    "indicator",
    resource_id = resolved$indicator_id,
    filters = filters,
    source = src$source_id
  )

  # The catalogue's name for the indicator travels with it: the census API
  # labels every table alike, so its adapter titles tables from the catalogue
  # (census_table_name()). Adapters that name their own data ignore it.
  out <- cache_fetch(
    cache_key(src$source_id, "get_indicator", query),
    fetch = function() {
      source_fetch(src, query, catalogue_name = resolved$indicator_name)
    },
    cache = cache,
    refresh = refresh,
    ttl = knbs_cache_ttl("data"),
    info = list(source_id = src$source_id, operation = "get_indicator",
                resource_id = resolved$indicator_id)
  )

  filter_period_bounds(out, bounds)
}

# Internals --------------------------------------------------------------------

#' The verified sources that list indicators
#' @noRd
resolve_indicator_sources <- function(source, call = rlang::caller_env()) {
  if (!is.null(source)) {
    return(list(resolve_source("list_indicators", source, call = call)))
  }
  entries <- Filter(
    function(s) {
      "list_indicators" %in% as.character(s$operations) &&
        !identical(s$stability, "discovery")
    },
    read_source_registry()$sources
  )
  if (length(entries) == 0L) {
    knbs_abort(
      c("No verified source lists indicators yet."),
      class = "knbs_error_source_unavailable",
      call = call
    )
  }
  lapply(entries, function(s) knbs_source(s$source_id))
}

#' Resolve a user-supplied indicator reference to an id and its source
#'
#' The id as given if any catalogue knows it; otherwise a name search. One
#' match is used, several are reported, none is a plain not-found.
#'
#' A source that could not be reached matters only when it could change the
#' answer. An id found in a reachable catalogue resolves silently - warning
#' that some other portal is down, on every call, was noise. A name search
#' warns, since the unreachable catalogue might hold another match; a
#' not-found names the unreachable source as a possible reason.
#'
#' @noRd
resolve_indicator <- function(indicator, source = NULL, cache = TRUE,
                              refresh = FALSE, call = rlang::caller_env()) {
  unreachable <- character(0)
  catalogue <- withCallingHandlers(
    knbs_indicators(source = source, cache = cache, refresh = refresh),
    knbs_warning_partial_failure = function(cnd) {
      unreachable <<- c(unreachable, as.character(cnd$unreachable))
      rlang::cnd_muffle(cnd)
    }
  )

  exact <- catalogue[catalogue$indicator_id == indicator, ]
  if (nrow(exact) == 1L) {
    return(list(indicator_id = exact$indicator_id, source_id = exact$source_id,
                indicator_name = exact$indicator_name))
  }
  if (nrow(exact) > 1L) {
    knbs_abort(
      c(
        "{.val {indicator}} is served by {nrow(exact)} sources.",
        "i" = "Name one with {.arg source}: {.val {exact$source_id}}."
      ),
      class = "knbs_error_ambiguous_resource",
      call = call,
      matches = exact$source_id
    )
  }

  hits <- catalogue[grepl(indicator, catalogue$indicator_name, ignore.case = TRUE), ]
  if (nrow(hits) == 0L) {
    knbs_abort(
      c(
        "No indicator matches {.val {indicator}}.",
        if (length(unreachable) > 0L) {
          c("!" = "Could not reach {.val {unreachable}}; it may be served there.")
        },
        "i" = "List what exists with {.fn knbs_indicators}."
      ),
      class = "knbs_error_resource_not_found",
      call = call,
      unreachable = unreachable
    )
  }
  if (length(unreachable) > 0L) {
    knbs_warn(
      c(
        "Matched {.val {indicator}} by name without {.val {unreachable}}, which could not be reached.",
        "i" = "A match there would be missing; use an exact {.field indicator_id} to be sure."
      ),
      class = "knbs_warning_partial_failure",
      unreachable = unreachable,
      call = call
    )
  }
  if (nrow(hits) > 1L) {
    knbs_abort(
      c(
        "{.val {indicator}} matches {nrow(hits)} indicators.",
        "i" = "Use an exact {.field indicator_id}:",
        "*" = "{paste(hits$indicator_id, ' - ', substr(hits$indicator_name, 1, 55))}"
      ),
      class = "knbs_error_ambiguous_resource",
      call = call,
      matches = hits$indicator_id
    )
  }
  list(indicator_id = hits$indicator_id, source_id = hits$source_id,
       indicator_name = hits$indicator_name)
}

#' Parse start/end into first-of-month Date bounds
#'
#' Accepts a year (`2020` or `"2020"`), a month (`"2020-01"`), a full date, or
#' `NULL` for an open end. A year means January for `start` and December for
#' `end`.
#'
#' @noRd
normalise_period_bounds <- function(start, end, call = rlang::caller_env()) {
  parse_point <- function(x, arg, december) {
    if (is.null(x)) {
      return(NULL)
    }
    if (inherits(x, "Date") && length(x) == 1L && !is.na(x)) {
      return(as.Date(format(x, "%Y-%m-01")))
    }
    if (is.numeric(x) && length(x) == 1L && !is.na(x) && x == as.integer(x)) {
      x <- as.character(as.integer(x))
    }
    if (is.character(x) && length(x) == 1L && !is.na(x)) {
      if (grepl("^[0-9]{4}$", x)) {
        return(as.Date(paste0(x, if (december) "-12-01" else "-01-01")))
      }
      quiet_date <- function(text) {
        tryCatch(as.Date(text), error = function(cnd) as.Date(NA))
      }
      if (grepl("^[0-9]{4}-[0-9]{2}$", x)) {
        parsed <- quiet_date(paste0(x, "-01"))
        if (!is.na(parsed)) {
          return(parsed)
        }
      }
      if (grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)) {
        parsed <- quiet_date(x)
        if (!is.na(parsed)) {
          return(as.Date(format(parsed, "%Y-%m-01")))
        }
      }
    }
    knbs_abort(
      c(
        "{.arg {arg}} must be a year, a {.val YYYY-MM} month, or a date.",
        "x" = "Got {.val {x}}."
      ),
      class = "knbs_error_invalid_argument",
      call = call
    )
  }

  from <- parse_point(start, "start", december = FALSE) %||% as.Date("2000-01-01")
  to <- parse_point(end, "end", december = TRUE) %||%
    as.Date(format(Sys.Date(), "%Y-%m-01"))

  if (from > to) {
    knbs_abort(
      c("{.arg start} is after {.arg end}.",
        "x" = "{.val {format(from, '%Y-%m')}} > {.val {format(to, '%Y-%m')}}."),
      class = "knbs_error_invalid_argument",
      call = call
    )
  }
  # The defaults exist so adapters that need concrete request windows (the CPI
  # Explorer) have one; whether the caller actually stated a bound travels
  # alongside, so that unstated bounds never trim anything.
  list(from = from, to = to,
       from_given = !is.null(start), to_given = !is.null(end))
}

#' Apply period bounds to observations of either period convention
#'
#' Only bounds the caller actually stated are applied. A default window would
#' silently hide the ends of long histories, which is exactly the kind of
#' quiet incompleteness the package refuses elsewhere.
#'
#' @noRd
filter_period_bounds <- function(out, bounds) {
  if (!"period" %in% names(out) || nrow(out) == 0L) {
    return(out)
  }
  if (!isTRUE(bounds$from_given) && !isTRUE(bounds$to_given)) {
    return(out)
  }
  lower <- if (isTRUE(bounds$from_given)) bounds$from else as.Date("0001-01-01")
  upper <- if (isTRUE(bounds$to_given)) bounds$to else as.Date("9999-12-01")
  keep <- if (inherits(out$period, "Date")) {
    out$period >= lower & out$period <= upper
  } else {
    years <- as.integer(out$period)
    is.na(years) | (years >= as.integer(format(lower, "%Y")) &
                      years <= as.integer(format(upper, "%Y")))
  }
  out[keep, ]
}
