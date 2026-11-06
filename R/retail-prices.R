# Retail prices ---------------------------------------------------------------
#
# National average prices of the 22 commodities tracked for the CPI basket,
# monthly, from two KNBS sources that publish the same figures (audit F-45):
#
#   - The KNBS Data Portal's dataflow DF_CPI_NA, asked first. It is one SDMX
#     request for the whole history.
#   - The CPI Explorer's retail-price listing (audit F-27), asked if the
#     portal does not answer. The route is Django-REST paginated; an
#     exact-month filter exists but no range filter, so a range query walks
#     the listing once and filters locally — cached, so the walk happens once
#     per week, not once per call.

#' The 22 commodities of the CPI retail-price basket, in both sources' terms
#'
#' The CPI Explorer numbers them CPI001-CPI022; the Data Portal keys them by
#' COICOP item code and pack size. Matched by name and pack size, then checked
#' value by value (audit F-45): the portal's prices equal the Explorer's to
#' its two decimals, and equal the June 2026 CPI release's retail table for
#' every commodity both print - which also settles the two packs the portal
#' labels alike, "Other animal oils and fats": the litre is the salad oil,
#' the 500 grams the cooking fat. Names, units and quantities are the
#' Explorer's, so prices line up whichever source answered.
#'
#' @noRd
retail_commodities <- function() {
  tibble::tribble(
    ~commodity_code, ~coicop_code, ~portal_quantity, ~commodity, ~unit, ~quantity,
    "CPI001", "CP01112603", "UNIT_1KG", "Maize Flour - Loose", "Kilogram", 1,
    "CPI002", "CP01112605", "UNIT_2KG", "Fortified Maize flour", "Kilogram", 2,
    "CPI003", "CP01112101", "UNIT_2KG", "Wheat Flour-White", "Kilogram", 2,
    "CPI004", "CP01113103", "UNIT_400G", "White bread", "Gram", 400,
    "CPI005", "CP01122101", "UNIT_1KG", "Beef - With Bones", "Kilogram", 1,
    "CPI006", "CP01141101", "UNIT_1L", "Fresh unpacketed cow milk / Fresh Cream", "Litre", 1,
    "CPI007", "CP01141102", "UNIT_500ML", "Fresh packeted cow milk", "Milliliter", 500,
    "CPI008", "CP01148103", "ONE_PIECE", "Eggs - Exotic/Kienyenji", "Piece", 1,
    "CPI009", "CP01159903", "UNIT_500G", "Cooking Fat", "Gram", 500,
    "CPI010", "CP011599", "UNIT_1L", "Cooking Oil (Salad)", "Litre", 1,
    "CPI011", "CP01171903", "UNIT_1KG", "Kale-Sukuma Wiki", "Kilogram", 1,
    "CPI012", "CP01171200", "UNIT_1KG", "Cabbages", "Kilogram", 1,
    "CPI013", "CP01172400", "UNIT_1KG", "Tomatoes", "Kilogram", 1,
    "CPI014", "CP01175704", "UNIT_1KG", "Cooking bananas", "Kilogram", 1,
    "CPI015", "CP01176102", "UNIT_1KG", "Beans", "Kilogram", 1,
    "CPI016", "CP011820", "UNIT_1KG", "Sugar", "Kilogram", 1,
    "CPI017", "CP04110101", "PER_MONTH", "House rent - single room", "Per Month", 1,
    "CPI018", "CP04510102", "UNIT_200KWH", "Electricity", "Kilowatts", 200,
    "CPI019", "CP04522102", "UNIT_13KG", "Gas/LPG", "Kilogram", 13,
    "CPI020", "CP04530101", "UNIT_1L", "Kerosene/Paraffin", "Litre", 1,
    "CPI021", "CP07222100", "UNIT_1L", "Petrol", "Litre", 1,
    "CPI022", "CP07221000", "UNIT_1L", "Diesel", "Litre", 1
  )
}

#' The sources asked for retail prices, in order
#'
#' The Data Portal first: it is first-party, it has kept answering while the
#' CPI Explorer failed twice (audit F-38, F-45), and the two publish the same
#' figures, so falling back from one to the other changes no number.
#'
#' @noRd
retail_price_sources <- function(call = rlang::caller_env()) {
  lapply(c("knbs_opendata", "knbs_cpi"), function(id) {
    resolve_source("retail_prices", id, call = call)
  })
}

#' @export
source_retail_prices.knbs_source_sdmxhub <- function(source, query, ...) {
  check_operation(source, "retail_prices")
  check_source_verified(source)
  check_supported_filters(query, c("period"))

  flow <- source_fetch(source, new_knbs_query("indicator", resource_id = "DF_CPI_NA",
                                              source = source$source_id))
  out <- standardise_hub_retail(tibble::as_tibble(flow), source$source_id)
  if (!is.null(query$filters$period)) {
    out <- out[out$period_label == query$filters$period, ]
  }

  new_knbs_data(
    out,
    new_knbs_metadata(
      title = "National average retail prices of CPI basket commodities",
      resource_id = "DF_CPI_NA",
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
      unit = "KES",
      frequency = "monthly",
      geographic_level = "national",
      licence = "Not stated by the source",
      access = "open",
      notes = c(
        "From the KNBS Data Portal dataflow DF_CPI_NA, \"National Average Retail Prices\".",
        "Prices are in Kenya Shillings per the stated unit and quantity.",
        paste0("commodity_code, commodity, unit and quantity follow the CPI ",
               "Explorer's register, so prices from either source line up; ",
               "coicop_code is the portal's COICOP item code."),
        "National only: the source holds no regional retail prices."
      )
    ),
    class = "knbs_prices"
  )
}

#' Walk a Django-REST paginated listing
#'
#' @param source The source.
#' @param path API path.
#' @param query Base query, page added per request.
#' @return All result records.
#' @noRd
cpix_drf_results <- function(source, path, query = list(), call = rlang::caller_env()) {
  page <- 1L
  collected <- list()
  repeat {
    payload <- cpix_get(source, path, c(query, list(page = page)), call = call)
    if (!is.list(payload) || !all(c("count", "results") %in% names(payload))) {
      knbs_abort(
        c(
          "The {.field {path}} listing changed shape; please report it.",
          "i" = "Expected a paginated object carrying {.field count} and {.field results}."
        ),
        class = "knbs_error_schema_changed",
        call = call
      )
    }
    collected <- c(collected, payload$results)
    total <- as.integer(payload$count %||% NA_integer_)
    if (is.na(total) || length(collected) >= total ||
          length(payload$results) == 0L) {
      break
    }
    page <- page + 1L
    if (page > 100L) {
      knbs_warn(
        c("Stopped after 100 pages of {.field {path}}.",
          "i" = "Only the records collected so far are used."),
        class = "knbs_warning_partial_failure"
      )
      break
    }
  }
  collected
}

#' The commodity register: numeric id to CPI code, unit and quantity
#' @noRd
cpix_commodities <- function(source, call = rlang::caller_env()) {
  records <- cpix_drf_results(source, "commodities/", call = call)
  ok <- length(records) > 0L && all(vapply(records, function(r) {
    is.list(r) && !is.null(r$id) && !is.null(r$name) && !is.null(r$code)
  }, logical(1)))
  if (!ok) {
    knbs_abort(
      c("The commodity register changed shape; please report it."),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  tibble::tibble(
    commodity_id = vapply(records, function(r) as.character(r$id), character(1)),
    commodity_code = vapply(records, function(r) as.character(r$code), character(1)),
    commodity = vapply(records, function(r) as.character(r$name), character(1))
  )
}

#' @export
source_retail_prices.knbs_source_cpiexplorer <- function(source, query, ...) {
  check_operation(source, "retail_prices")
  check_source_verified(source)
  check_supported_filters(query, c("period"))

  base_query <- if (!is.null(query$filters$period)) {
    list(period = paste0(query$filters$period, "-01"))
  } else {
    list()
  }
  records <- cpix_drf_results(source, "retail-prices/", base_query)
  register <- cpix_commodities(source)

  out <- standardise_cpix_retail(records, register, source$source_id)

  new_knbs_data(
    out,
    new_knbs_metadata(
      title = "National average retail prices of CPI basket commodities",
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
      unit = "KES",
      frequency = "monthly",
      geographic_level = "national",
      licence = "Not stated by the source",
      access = "open",
      notes = c(
        "Prices are in Kenya Shillings per the stated unit and quantity, as labelled on the portal.",
        "National only: the source holds no regional retail prices (audit F-27)."
      )
    ),
    class = "knbs_prices"
  )
}

#' National average retail prices of the CPI basket commodities
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Returns the monthly national average retail prices KNBS publishes for the
#' 22 commodities tracked for the CPI basket — maize flour, bread, milk,
#' petrol, house rent and the rest — one row per commodity per month from
#' February 2019, in Kenya Shillings per the stated unit and quantity.
#'
#' @details
#' Two KNBS sources publish these prices, and they publish the same figures:
#' the KNBS Data Portal (dataflow `DF_CPI_NA`) and the CPI Explorer. The Data
#' Portal is asked first; if it does not answer, the CPI Explorer is, and a
#' message says so. The `source_id` column and [knbs_metadata()] name the
#' source that answered. Commodities carry the CPI Explorer's codes, names
#' and units whichever source answered, and `coicop_code` is the
#' international COICOP item code.
#'
#' These are national averages only: neither source holds regional retail
#' prices. Neither states a licence; [knbs_metadata()] on the result says so.
#' The full history is retrieved once (a few seconds, then cached).
#'
#' @param commodity Keep only these commodities, by `CPI001`-style code or
#'   COICOP code (exact), or by name (matched as text).
#' @param start,end Keep only these months. A year, a `"YYYY-MM"` month, or a
#'   date.
#' @param source Ask only this source: `"knbs_opendata"` (the KNBS Data
#'   Portal) or `"knbs_cpi"` (the CPI Explorer). By default the Data Portal is
#'   asked first and the CPI Explorer if it does not answer.
#' @param cache Whether to use the local cache.
#' @param refresh Whether to bypass any cached response.
#'
#' @return A `knbs_prices` tibble with columns `commodity_code`,
#'   `coicop_code`, `commodity`, `unit`, `quantity`, `period`,
#'   `period_label`, `price` and `source_id`.
#'
#' @seealso [knbs_get_indicator()] for the price *indices*: the CPI by
#'   region (`"CPI_ALL_ITEMS"`, or `"DF_CPI_R"` on the Data Portal) and by
#'   division (`"DF_CPI_IX"`).
#'
#' @examplesIf interactive()
#' knbs_retail_prices(commodity = "petrol", start = 2024)
#' knbs_retail_prices(start = "2026-06", end = "2026-06")
#' @export
knbs_retail_prices <- function(commodity = NULL,
                               start = NULL,
                               end = NULL,
                               source = NULL,
                               cache = knbs_option("cache"),
                               refresh = FALSE) {
  if (!is.null(commodity)) check_character(commodity, "commodity")
  bounds <- normalise_period_bounds(start, end)
  candidates <- if (is.null(source)) {
    retail_price_sources()
  } else {
    list(resolve_source("retail_prices", source))
  }

  # An exact month can be filtered by the CPI Explorer's server; anything else
  # walks the cached full listing, so different ranges share one retrieval.
  single_month <- !is.null(start) && !is.null(end) &&
    identical(format(bounds$from, "%Y-%m"), format(bounds$to, "%Y-%m"))
  fetch_from <- function(src) {
    query <- new_knbs_query(
      "indicator",
      filters = if (single_month) {
        list(period = format(bounds$from, "%Y-%m"))
      } else {
        list()
      },
      source = src$source_id
    )
    cache_fetch(
      cache_key(src$source_id, "retail_prices", query),
      fetch = function() source_retail_prices(src, query),
      cache = cache,
      refresh = refresh,
      ttl = knbs_cache_ttl("catalogue"),
      info = list(source_id = src$source_id, operation = "retail_prices")
    )
  }

  # A source that is down or refusing gives way to the next; any other
  # failure - a changed shape, a failed check - is reported as it is, since
  # the next source answering would hide it.
  out <- NULL
  failed <- list()
  for (src in candidates) {
    if (length(candidates) == 1L) {
      out <- fetch_from(src)
      break
    }
    got <- tryCatch(
      fetch_from(src),
      knbs_error_source_unavailable = function(cnd) cnd,
      knbs_error_access_restricted = function(cnd) cnd
    )
    if (inherits(got, "knbs_error")) {
      failed[[src$source_id]] <- got
      next
    }
    out <- got
    break
  }
  if (is.null(out)) {
    knbs_abort(
      c(
        "No retail-price source answered.",
        stats::setNames(
          vapply(names(failed), function(id) {
            paste0(id, ": ", condition_summary(failed[[id]]))
          }, character(1)),
          rep("x", length(failed))
        ),
        "i" = "See {.code knbs_status(live = TRUE)}."
      ),
      class = "knbs_error_source_unavailable",
      parent = failed[[1]]
    )
  }
  if (length(failed) > 0L) {
    cli::cli_inform(
      c("i" = paste0("{.val {names(failed)}} did not answer; these prices are from ",
                     "{.val {knbs_metadata(out)$source_id}}, which publishes the same figures.")),
      class = "knbs_message_fallback"
    )
  }

  out <- filter_period_bounds(out, bounds)
  if (!is.null(commodity)) {
    wanted <- tolower(as.character(commodity))
    by_code <- tolower(out$commodity_code) %in% wanted |
      tolower(out$coicop_code) %in% wanted
    by_name <- rep(FALSE, nrow(out))
    for (term in as.character(commodity)) {
      by_name <- by_name | grepl(term, out$commodity, ignore.case = TRUE)
    }
    out <- out[by_code | by_name, ]
  }
  out
}
