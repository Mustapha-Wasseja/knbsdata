# CPI Explorer adapter --------------------------------------------------------
#
# Talks to the CPI Explorer API at cpiexplorer.knbs.or.ke, traced 2026-08-08
# (audit section 1c). Monthly consumer price indices and inflation from
# 2009-01 onwards.
#
# Behaviours of that API this adapter is built around:
#
#   F-24  An unknown region id silently falls back to the national series.
#         Requested regions are therefore validated against the source's own
#         region list before any data request, and every returned series is
#         matched back to a requested region by its metadata.region field —
#         which is also the only reliable region key, since every series
#         arrives with id "overall".
#   F-26  Six listed regions (the former provinces) carry no data in any
#         period. An empty series for them is the source's answer, not an
#         error.
#   The portal states no licence, so none is claimed here.

#' A CPI Explorer request
#'
#' The single network entry point for this adapter, mocked wholesale in tests.
#' Unlike the census API, this one declares JSON honestly and answers unknown
#' API routes with a real 404.
#'
#' @noRd
cpix_get <- function(source, path, query = list(), call = rlang::caller_env()) {
  req <- knbs_request(paste0(sub("/+$", "", source$base_url), "/", path), throttle = 2)
  if (length(query) > 0L) {
    req <- httr2::req_url_query(req, !!!query, .multi = "explode")
  }
  resp <- knbs_perform(req, source_id = source$source_id, expect = "json", call = call)
  parse_json_response(resp, source_id = source$source_id, call = call)
}

#' The indicators this source serves
#'
#' One data request carries all three measures — the index level and both
#' rates of change — so the definitions differ only in which field they read.
#'
#' @noRd
cpix_indicator_defs <- function() {
  tibble::tibble(
    indicator_id = c("CPI_ALL_ITEMS", "CPI_INFLATION_YOY", "CPI_INFLATION_MOM"),
    indicator_name = c(
      "Consumer Price Index, all items",
      "Consumer price inflation, year on year",
      "Consumer price inflation, month on month"
    ),
    topic = "prices",
    frequency = "monthly",
    unit = c("index", "percent", "percent"),
    value_field = c("value", "change_annual", "change_monthly")
  )
}

#' Name the KNBS Data Portal's equivalent when the CPI Explorer is down
#'
#' The portal publishes the same national index as `DF_CPI_R` (base February
#' 2019 = 100): compared on 2026-10-05, it matched this source to the two
#' decimals this source serves for April to June 2026. Its inflation series,
#' `DF_CPI_YR` and `DF_CPI_MR`, are KNBS's own published rates, rounded to
#' one decimal - and not always this source's computed changes: May 2026 year
#' on year was 6.9 there against 6.68 here, month on month 1.8 against 1.58.
#' So nothing is substituted: the error names the alternative and says how
#' far it stands in, and the caller decides.
#'
#' @noRd
cpix_hint_on_outage <- function(expr, indicator_id, call = rlang::caller_env()) {
  call_for <- function(id) {
    paste0("{.code knbs_get_indicator(\"", id, "\", source = \"knbs_opendata\")}")
  }
  rates_differ <- function(portal, here) {
    paste0(
      "Those are KNBS's published rates, rounded to one decimal, not this ",
      "source's computed change: May 2026 was ", portal, " there and ", here,
      " here."
    )
  }
  hint <- switch(indicator_id,
    CPI_ALL_ITEMS = c(
      "i" = paste0("The KNBS Data Portal publishes the same national index ",
                   "(base February 2019 = 100): ", call_for("DF_CPI_R"), "."),
      "i" = paste0("It matched this source to two decimals when last ",
                   "compared (April to June 2026).")
    ),
    CPI_INFLATION_YOY = c(
      "i" = paste0("The KNBS Data Portal publishes KNBS's year-on-year rates: ",
                   call_for("DF_CPI_YR"), "."),
      "!" = rates_differ("6.9", "6.68")
    ),
    CPI_INFLATION_MOM = c(
      "i" = paste0("The KNBS Data Portal publishes KNBS's month-on-month rates: ",
                   call_for("DF_CPI_MR"), "."),
      "!" = rates_differ("1.8", "1.58")
    ),
    NULL
  )
  tryCatch(
    expr,
    knbs_error_source_unavailable = function(cnd) {
      if (is.null(hint)) {
        rlang::cnd_signal(cnd)
      }
      knbs_abort(
        c(
          "The CPI Explorer is not answering.",
          hint,
          "i" = paste0(
            "The portal's areas are Kenya, Nairobi and \"Regions Except ",
            "Nairobi\" (SDMX codes {.val KE}, {.val KE_110_NA}, ",
            "{.val OTHER_URB}), not this source's region ids."
          )
        ),
        class = "knbs_error_source_unavailable",
        parent = cnd,
        call = call
      )
    }
  )
}

#' The source's region list, standardised
#'
#' @return A tibble with `geo_code` (the source's region id, as character),
#'   `geo_name` and `geo_level` (`national` or `region`).
#' @noRd
cpix_regions <- function(source, call = rlang::caller_env()) {
  payload <- cpix_get(source, "explorer/regions/", call = call)
  ok <- is.list(payload) && length(payload) > 0L &&
    all(vapply(payload, function(r) {
      is.list(r) && !is.null(r$id) && !is.null(r$name)
    }, logical(1)))
  if (!ok) {
    knbs_abort(
      c("The source's region list changed shape; please report it."),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  ids <- vapply(payload, function(r) as.character(r$id), character(1))
  tibble::tibble(
    geo_code = ids,
    geo_name = vapply(payload, function(r) as.character(r$name), character(1)),
    geo_level = ifelse(ids == "national", "national", "region")
  )
}

#' @export
source_search.knbs_source_cpiexplorer <- function(source, query, ...) {
  check_operation(source, "list_indicators")
  check_source_verified(source)
  check_supported_filters(query, c("search", "topic"))

  defs <- cpix_indicator_defs()
  out <- defs[, c("indicator_id", "indicator_name", "topic", "frequency", "unit")]
  out$source_id <- source$source_id
  out <- out[, knbs_indicator_list_columns()]

  filters <- query$filters
  if (!is.null(filters$topic)) {
    out <- out[tolower(out$topic) %in% tolower(as.character(filters$topic)), ]
  }
  if (!is.null(filters$search)) {
    out <- out[grepl(filters$search, out$indicator_name, ignore.case = TRUE), ]
  }

  new_knbs_catalogue(
    out,
    new_knbs_metadata(
      title = paste0(source$source_name, " indicator catalogue"),
      resource_type = "indicator",
      source_id = source$source_id,
      source_name = source$source_name,
      source_url = source$landing_page %||% source$base_url,
      producer = source$owner,
      licence = "Not stated by the source",
      access = "open"
    )
  )
}

#' @export
source_fetch.knbs_source_cpiexplorer <- function(source, query, ...) {
  check_operation(source, "get_indicator")
  check_source_verified(source)
  check_supported_filters(query, c("start", "end", "geo_level", "geo_code"))

  defs <- cpix_indicator_defs()
  def <- defs[defs$indicator_id == (query$resource_id %||% ""), ]
  if (nrow(def) != 1L) {
    knbs_abort(
      c(
        "This source has no indicator {.val {query$resource_id}}.",
        "i" = "It serves: {.val {defs$indicator_id}}."
      ),
      class = "knbs_error_resource_not_found"
    )
  }

  regions <- cpix_hint_on_outage(cpix_regions(source), def$indicator_id)
  filters <- query$filters

  # F-24: the region set is decided and validated here, before any data
  # request, because the data endpoint substitutes national for anything it
  # does not recognise.
  wanted <- if (!is.null(filters$geo_code)) {
    unknown <- setdiff(as.character(filters$geo_code), regions$geo_code)
    if (length(unknown) > 0L) {
      knbs_abort(
        c(
          "{cli::qty(length(unknown))}Unknown region{?s} {.val {unknown}}.",
          "i" = "This source's regions: {.val {regions$geo_code}}.",
          "i" = "CPI regions are collection strata, not census territories."
        ),
        class = "knbs_error_resource_not_found"
      )
    }
    regions[regions$geo_code %in% as.character(filters$geo_code), ]
  } else if (!is.null(filters$geo_level)) {
    regions[regions$geo_level %in% as.character(filters$geo_level), ]
  } else {
    regions[regions$geo_level == "national", ]
  }
  if (nrow(wanted) == 0L) {
    knbs_abort(
      c("No region matches the request.",
        "i" = "This source's levels: {.val {unique(regions$geo_level)}}."),
      class = "knbs_error_invalid_query"
    )
  }

  bounds <- list(
    from = as.Date(paste0(filters$start %||% "2000-01", "-01")),
    to = as.Date(paste0(filters$end %||% format(Sys.Date(), "%Y-%m"), "-01"))
  )
  # The server computes month-on-month and year-on-year changes only against
  # points inside the requested window (verified live: a window starting
  # 2026-01 returns NULL year-on-year for all of 2026). For the change
  # variants the request therefore starts 13 months early, and the
  # standardiser trims back to the caller's bounds.
  request_from <- if (identical(def$value_field, "value")) {
    bounds$from
  } else {
    seq(bounds$from, by = "-13 months", length.out = 2)[[2]]
  }
  payload <- cpix_hint_on_outage(
    cpix_get(source, "explorer/data/", list(
      `region_id[]` = wanted$geo_code,
      start_date = format(request_from, "%Y-%m-%d"),
      end_date = format(bounds$to, "%Y-%m-%d"),
      data_type = "cpi",
      frequency = "monthly"
    )),
    def$indicator_id
  )

  out <- standardise_cpix_series(
    payload,
    def = def,
    wanted = wanted,
    bounds = bounds,
    source_id = source$source_id
  )

  new_knbs_data(
    out,
    new_knbs_metadata(
      title = def$indicator_name,
      resource_id = def$indicator_id,
      resource_type = "indicator",
      source_id = source$source_id,
      source_name = source$source_name,
      source_url = source$landing_page %||% source$base_url,
      producer = source$owner,
      reference_period = if (nrow(out) > 0L) {
        paste(min(out$period_label), "to", max(out$period_label))
      } else {
        NULL
      },
      unit = def$unit,
      frequency = "monthly",
      geographic_level = paste(sort(unique(out$geo_level)), collapse = " and "),
      licence = "Not stated by the source",
      access = "open",
      notes = c(
        "The API does not state a release date or the index base period.",
        "CPI regions are collection strata, not census territories; do not join them against knbs_geographies()."
      )
    ),
    class = "knbs_indicator"
  )
}

#' @export
source_metadata.knbs_source_cpiexplorer <- function(source, resource_id, ...) {
  check_operation(source, "indicator_metadata")
  check_source_verified(source)
  check_string(resource_id, "resource_id")

  defs <- cpix_indicator_defs()
  def <- defs[defs$indicator_id == resource_id, ]
  if (nrow(def) != 1L) {
    knbs_abort(
      c("This source has no indicator {.val {resource_id}}.",
        "i" = "It serves: {.val {defs$indicator_id}}."),
      class = "knbs_error_resource_not_found"
    )
  }

  periods <- cpix_get(source, "periods/")
  labels <- sort(vapply(periods, function(p) {
    as.character(if (is.list(p)) p$period %||% p[[1]] else p)
  }, character(1)))

  new_knbs_metadata(
    title = def$indicator_name,
    resource_id = def$indicator_id,
    resource_type = "indicator",
    source_id = source$source_id,
    source_name = source$source_name,
    source_url = source$landing_page %||% source$base_url,
    producer = source$owner,
    reference_period = if (length(labels) > 0L) {
      paste(substr(labels[[1]], 1, 7), "to", substr(labels[[length(labels)]], 1, 7))
    } else {
      NULL
    },
    unit = def$unit,
    frequency = "monthly",
    licence = "Not stated by the source",
    access = "open",
    notes = "The API does not state a release date or the index base period."
  )
}

#' @export
source_health.knbs_source_cpiexplorer <- function(source, ...) {
  started <- Sys.time()
  outcome <- tryCatch(
    {
      payload <- cpix_get(source, "periods/")
      list(
        status = if (is.list(payload) && length(payload) > 0L) "ok" else "unavailable",
        message = "Period list answered."
      )
    },
    knbs_error = function(cnd) {
      list(status = "unavailable", message = conditionMessage(cnd))
    }
  )
  tibble::tibble(
    source_id = source$source_id,
    operation = "list_indicators",
    status = outcome$status,
    http_status = NA_integer_,
    response_time_ms = as.numeric(difftime(Sys.time(), started, units = "secs")) * 1000,
    checked_at = started,
    message = outcome$message
  )
}
