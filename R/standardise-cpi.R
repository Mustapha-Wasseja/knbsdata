# CPI standardisation ---------------------------------------------------------

#' Standardise CPI Explorer series into observations
#'
#' @param payload The parsed `/explorer/data/` response: a list of series, each
#'   `{id, name, data: [{period, value, change_monthly, change_annual}],
#'   metadata: {region, ...}}`.
#' @param def One row of `cpix_indicator_defs()`; its `value_field` decides
#'   which measure becomes `value`.
#' @param wanted The validated region tibble the request asked for.
#' @param bounds Period bounds as `list(from, to)` of Dates.
#' @param source_id Source id.
#' @noRd
standardise_cpix_series <- function(payload, def, wanted, bounds, source_id,
                                    call = rlang::caller_env()) {
  ok <- is.list(payload) &&
    all(vapply(payload, function(s) {
      is.list(s) && !is.null(s$metadata$region) && is.list(s$data)
    }, logical(1)))
  if (!ok) {
    knbs_abort(
      c(
        "The data endpoint changed shape; please report it.",
        "i" = "Expected series carrying {.field metadata.region} and {.field data}."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }

  # F-24: every returned series must be one that was asked for, matched by the
  # source's own region name. A series for anything else means the endpoint
  # substituted a default.
  returned <- vapply(payload, function(s) as.character(s$metadata$region), character(1))
  unexpected <- setdiff(returned, wanted$geo_name)
  if (length(unexpected) > 0L) {
    knbs_abort(
      c(
        "The source answered with series that were not requested: {.val {unexpected}}.",
        "i" = "This endpoint silently substitutes the national series for unknown regions.",
        "i" = "Please report it; the request may have gone stale against the region list."
      ),
      class = "knbs_error_validation_failed",
      call = call
    )
  }

  rows <- list()
  for (series in payload) {
    region_name <- as.character(series$metadata$region)
    region <- wanted[wanted$geo_name == region_name, ]
    points <- series$data
    if (length(points) == 0L) {
      next
    }
    periods <- as.Date(vapply(points, function(p) as.character(p$period), character(1)))
    values <- vapply(points, function(p) {
      v <- p[[def$value_field]]
      if (is.null(v)) NA_real_ else as.numeric(v)
    }, numeric(1))

    rows[[length(rows) + 1L]] <- tibble::tibble(
      indicator_id = def$indicator_id,
      indicator_name = def$indicator_name,
      period = periods,
      period_label = format(periods, "%Y-%m"),
      value = values,
      unit = def$unit,
      frequency = "monthly",
      geo_code = region$geo_code,
      geo_name = region$geo_name,
      geo_level = region$geo_level,
      source_id = source_id
    )
  }

  out <- if (length(rows) == 0L) {
    empty_cpix_observations()
  } else {
    do.call(rbind, rows)
  }

  # Belt and braces on the date range: the server honoured it when traced, but
  # this API family silently ignores parameters often enough that the bounds
  # are enforced here too.
  out <- out[out$period >= bounds$from & out$period <= bounds$to, ]
  out <- out[order(out$geo_code, out$period), ]

  keys <- paste(out$indicator_id, out$geo_code, out$period, sep = "\r")
  if (anyDuplicated(keys) > 0L) {
    knbs_abort(
      c("The standardised observations contain duplicate keys.",
        "i" = "This means the source's series changed shape; please report it."),
      class = "knbs_error_validation_failed",
      call = call
    )
  }
  out
}

#' Standardise retail-price records into the price schema
#'
#' @param records DRF result records from `/retail-prices/`.
#' @param register The commodity register from `cpix_commodities()`.
#' @noRd
standardise_cpix_retail <- function(records, register, source_id,
                                    call = rlang::caller_env()) {
  if (length(records) == 0L) {
    return(empty_cpix_prices())
  }
  ok <- all(vapply(records, function(r) {
    is.list(r) && !is.null(r$commodity) && !is.null(r$commodity_name) &&
      !is.null(r$period) && !is.null(r$price)
  }, logical(1)))
  if (!ok) {
    knbs_abort(
      c("The retail-price records changed shape; please report it."),
      class = "knbs_error_schema_changed",
      call = call
    )
  }

  ids <- vapply(records, function(r) as.character(r$commodity), character(1))
  periods <- as.Date(vapply(records, function(r) as.character(r$period), character(1)))
  codes <- register$commodity_code[match(ids, register$commodity_id)]
  basket <- retail_commodities()

  out <- tibble::tibble(
    commodity_code = codes,
    coicop_code = basket$coicop_code[match(codes, basket$commodity_code)],
    commodity = vapply(records, function(r) as.character(r$commodity_name), character(1)),
    unit = vapply(records, json_chr, character(1), "unit_of_measure"),
    quantity = vapply(records, function(r) {
      q <- r$quantity
      if (is.null(q)) NA_real_ else as.numeric(q)
    }, numeric(1)),
    period = periods,
    period_label = format(periods, "%Y-%m"),
    price = vapply(records, function(r) as.numeric(r$price), numeric(1)),
    source_id = rep(source_id, length(records))
  )
  out <- out[order(out$commodity_code, out$period), ]

  # Keyed in the source's own record order: `ids` and `periods` were never
  # reordered. Pairing `ids` with the sorted `out$period` once matched records
  # to the wrong months, and refused the whole history as soon as the source
  # stopped sending it pre-sorted (observed 2026-10-15).
  keys <- paste(ids, periods, sep = "\r")
  if (anyDuplicated(keys) > 0L) {
    knbs_abort(
      c("The retail-price history contains duplicate keys.",
        "i" = "This means the listing changed shape; please report it."),
      class = "knbs_error_validation_failed",
      call = call
    )
  }
  if (anyNA(out$period)) {
    knbs_abort(
      c("A retail-price record carries an unreadable period."),
      class = "knbs_error_validation_failed",
      call = call
    )
  }
  out
}

#' Standardise the Data Portal's retail-price dataflow into the price schema
#'
#' `DF_CPI_NA` is a cube of item x pack size x month in which only each
#' item's own pack carries values; the empty cells are dropped. Each item and
#' pack is matched to the CPI Explorer's register, so prices line up
#' whichever source answered. One the register does not know keeps its row,
#' with an `NA` code and the portal's own labels, as an unknown commodity does
#' from the Explorer.
#'
#' @param obs The dataflow as standardised SDMX observations.
#' @noRd
standardise_hub_retail <- function(obs, source_id, call = rlang::caller_env()) {
  needed <- c("item_price", "item_price_code", "unit_quantity", "unit_quantity_code",
              "period", "value")
  if (!all(needed %in% names(obs))) {
    knbs_abort(
      c("The retail-price dataflow changed shape; please report it.",
        "i" = "Expected the dimensions ITEM_PRICE and UNIT_QUANTITY, monthly."),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  obs <- obs[!is.na(obs$value), ]
  if (nrow(obs) == 0L) {
    return(empty_cpix_prices())
  }
  if (!inherits(obs$period, "Date") || anyNA(obs$period)) {
    knbs_abort(
      c("A retail-price observation carries an unreadable month."),
      class = "knbs_error_validation_failed",
      call = call
    )
  }
  keys <- paste(obs$item_price_code, obs$unit_quantity_code, obs$period, sep = "\r")
  if (anyDuplicated(keys) > 0L) {
    knbs_abort(
      c("The retail-price dataflow contains duplicate keys.",
        "i" = "This means the dataflow changed shape; please report it."),
      class = "knbs_error_validation_failed",
      call = call
    )
  }

  basket <- retail_commodities()
  at <- match(paste(obs$item_price_code, obs$unit_quantity_code),
              paste(basket$coicop_code, basket$portal_quantity))
  # "500 Gram" -> 500 and "Gram", for a pack the register does not know.
  pack <- trimws(as.character(obs$unit_quantity))
  pack_quantity <- suppressWarnings(as.numeric(sub("^([0-9.]+).*$", "\\1", pack)))
  pack_unit <- trimws(sub("^[0-9.]+\\s*", "", pack))
  known <- !is.na(at)

  out <- tibble::tibble(
    commodity_code = basket$commodity_code[at],
    coicop_code = as.character(obs$item_price_code),
    commodity = ifelse(known, basket$commodity[at], trimws(as.character(obs$item_price))),
    unit = ifelse(known, basket$unit[at], pack_unit),
    quantity = ifelse(known, basket$quantity[at], pack_quantity),
    period = obs$period,
    period_label = format(obs$period, "%Y-%m"),
    price = as.numeric(obs$value),
    source_id = rep(source_id, nrow(obs))
  )
  out[order(out$commodity_code, out$coicop_code, out$period), ]
}

empty_cpix_prices <- function() {
  tibble::tibble(
    commodity_code = character(0),
    coicop_code = character(0),
    commodity = character(0),
    unit = character(0),
    quantity = numeric(0),
    period = as.Date(character(0)),
    period_label = character(0),
    price = numeric(0),
    source_id = character(0)
  )
}

empty_cpix_observations <- function() {
  tibble::tibble(
    indicator_id = character(0),
    indicator_name = character(0),
    period = as.Date(character(0)),
    period_label = character(0),
    value = numeric(0),
    unit = character(0),
    frequency = character(0),
    geo_code = character(0),
    geo_name = character(0),
    geo_level = character(0),
    source_id = character(0)
  )
}
