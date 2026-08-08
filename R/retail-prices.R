# Retail prices ---------------------------------------------------------------
#
# The CPI Explorer's retail-price history (audit F-27): national average
# prices of the 22 commodities tracked for the CPI basket, monthly. The route
# is Django-REST paginated; an exact-month filter exists but no range filter,
# so a range query walks the listing once and filters locally — cached, so the
# walk happens once per week, not once per call.

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
#' Returns the monthly national average retail prices the KNBS CPI Explorer
#' publishes for the 22 commodities it tracks — maize flour, bread, milk,
#' petrol, house rent and the rest — one row per commodity per month, in
#' Kenya Shillings per the stated unit and quantity.
#'
#' @details
#' These are national averages only: the source holds no regional retail
#' prices. The portal states no licence; [knbs_metadata()] on the result says
#' so. A range query retrieves the full history once (a few seconds, then
#' cached); an exact single month is fetched directly.
#'
#' @param commodity Keep only these commodities, by `CPI001`-style code
#'   (exact) or by name (matched as text).
#' @param start,end Keep only these months. A year, a `"YYYY-MM"` month, or a
#'   date.
#' @param source Source id.
#' @param cache Whether to use the local cache.
#' @param refresh Whether to bypass any cached response.
#'
#' @return A `knbs_prices` tibble with columns `commodity_code`, `commodity`,
#'   `unit`, `quantity`, `period`, `period_label`, `price` and `source_id`.
#'
#' @seealso [knbs_get_indicator()] for the price *indices* the same portal
#'   serves.
#'
#' @examples
#' \dontrun{
#' knbs_retail_prices(commodity = "petrol", start = 2024)
#' knbs_retail_prices(start = "2026-06", end = "2026-06")
#' }
#' @export
knbs_retail_prices <- function(commodity = NULL,
                               start = NULL,
                               end = NULL,
                               source = NULL,
                               cache = knbs_option("cache"),
                               refresh = FALSE) {
  if (!is.null(commodity)) check_character(commodity, "commodity")
  bounds <- normalise_period_bounds(start, end)
  src <- resolve_source("retail_prices", source)

  # An exact month can be filtered by the server; anything else walks the
  # cached full listing, so different ranges share one retrieval.
  single_month <- !is.null(start) && !is.null(end) &&
    identical(format(bounds$from, "%Y-%m"), format(bounds$to, "%Y-%m"))
  query <- new_knbs_query(
    "indicator",
    filters = if (single_month) {
      list(period = format(bounds$from, "%Y-%m"))
    } else {
      list()
    },
    source = src$source_id
  )

  out <- cache_fetch(
    cache_key(src$source_id, "retail_prices", query),
    fetch = function() source_retail_prices(src, query),
    cache = cache,
    refresh = refresh,
    ttl = knbs_cache_ttl("catalogue"),
    info = list(source_id = src$source_id, operation = "retail_prices")
  )

  out <- filter_period_bounds(out, bounds)
  if (!is.null(commodity)) {
    wanted <- tolower(as.character(commodity))
    by_code <- tolower(out$commodity_code) %in% wanted
    by_name <- rep(FALSE, nrow(out))
    for (term in as.character(commodity)) {
      by_name <- by_name | grepl(term, out$commodity, ignore.case = TRUE)
    }
    out <- out[by_code | by_name, ]
  }
  out
}
