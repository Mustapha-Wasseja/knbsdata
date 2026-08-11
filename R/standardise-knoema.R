# Knoema observation standardisation ------------------------------------------
#
# Turns the raw series of a Knoema dataset into the observation schema. Every
# series carries its own start date, frequency code and values array; the
# timeline is expanded per series and verified against the series' own stated
# end date, so a miscounted expansion is refused rather than silently shifted.
#
# One dataset may mix frequencies (audit F-33). Annual observations carry
# integer-year periods and sub-annual ones carry Dates, which cannot share a
# column, so a mixed dataset requires an explicit frequency choice - nothing
# is picked silently.

#' Frequency codes the portal uses, mapped to the package's names
#' @noRd
knoema_frequencies <- function() {
  c(A = "annual", Q = "quarterly", M = "monthly")
}

#' Expand one series' timeline
#'
#' @return list(period, label) in the package's period convention: integer
#'   years for annual series, first-of-period Dates otherwise.
#' @noRd
knoema_series_periods <- function(start_date, end_date, code, n,
                                  call = rlang::caller_env()) {
  start <- as.Date(substr(as.character(start_date %||% ""), 1, 10))
  end <- as.Date(substr(as.character(end_date %||% ""), 1, 10))
  if (is.na(start) || is.na(end)) {
    knbs_abort(
      c(
        "A series carries an unreadable timeline; please report it.",
        "x" = "startDate {.val {start_date}}, endDate {.val {end_date}}."
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }

  out <- switch(
    code,
    A = {
      years <- as.integer(format(start, "%Y")) + seq_len(n) - 1L
      # A fiscal-year series starts mid-year; the stated end keeps that
      # month and day, so the check reconstructs it the same way.
      list(
        period = years,
        label = as.character(years),
        expected_end = as.Date(paste0(years[[n]], format(start, "-%m-%d")))
      )
    },
    Q = {
      dates <- seq(start, by = "3 months", length.out = n)
      list(
        period = dates,
        label = paste0(
          format(dates, "%Y"), "-Q",
          (as.integer(format(dates, "%m")) - 1L) %/% 3L + 1L
        ),
        expected_end = dates[[n]]
      )
    },
    M = {
      dates <- seq(start, by = "1 month", length.out = n)
      list(period = dates, label = format(dates, "%Y-%m"), expected_end = dates[[n]])
    }
  )

  if (!identical(out$expected_end, end)) {
    knbs_abort(
      c(
        "A series' values do not span its stated timeline; please report it.",
        "x" = paste0(
          "{n} value{?s} of frequency {.val {code}} from ",
          "{.val {as.character(start)}} should end ",
          "{.val {as.character(out$expected_end)}}, but the series says ",
          "{.val {as.character(end)}}."
        )
      ),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  out[c("period", "label")]
}

#' Standardise a Knoema dataset's series into observations
#'
#' @param series The `data` array of the portal's data response.
#' @param meta The dataset's own metadata payload, whose `dimensions` are the
#'   only trustworthy structural record (audit F-32).
#' @param indicator_id The dataset id.
#' @param source_id Source id.
#' @param frequency Keep only series of this frequency (`"annual"`,
#'   `"quarterly"` or `"monthly"`), or `NULL` to require a single-frequency
#'   dataset.
#' @return list(table, unit, frequency, fixed, scale_note) - `fixed` describes
#'   single-member dimensions folded into metadata rather than emitted as
#'   constant columns.
#' @noRd
standardise_knoema_obs <- function(series, meta, indicator_id, source_id,
                                   frequency = NULL,
                                   call = rlang::caller_env()) {
  dims <- meta$dimensions %||% list()
  dim_ids <- vapply(
    dims,
    function(d) as.character(d$id %||% NA_character_),
    character(1)
  )
  is_geo <- vapply(dims, function(d) isTRUE(d$isGeo), logical(1))
  if (anyNA(dim_ids) || anyDuplicated(dim_ids) > 0L || sum(is_geo) > 1L) {
    knbs_abort(
      c("The dataset's dimension metadata changed shape; please report it."),
      class = "knbs_error_schema_changed",
      call = call
    )
  }
  dim_names <- stats::setNames(
    vapply(dims, function(d) as.character(d$name %||% d$id %||% "?"), character(1)),
    dim_ids
  )
  geo_dim <- if (any(is_geo)) dim_ids[[which(is_geo)]] else NULL

  codes <- vapply(
    series,
    function(s) as.character(s$frequency %||% NA_character_),
    character(1)
  )
  freq_map <- knoema_frequencies()
  known <- !is.na(codes) & codes %in% names(freq_map)

  if (!is.null(frequency)) {
    keep <- known & unname(freq_map[codes]) == frequency
    keep[is.na(keep)] <- FALSE
    if (!any(keep)) {
      have <- sort(unique(unname(freq_map[codes[known]])))
      knbs_abort(
        c(
          "{.val {indicator_id}} has no {frequency} series.",
          "i" = if (length(have) > 0L) {
            "It serves: {.val {have}}."
          } else {
            "Its frequency codes: {.val {sort(unique(codes))}}."
          }
        ),
        class = "knbs_error_invalid_query",
        call = call
      )
    }
    series <- series[keep]
    codes <- codes[keep]
  } else {
    if (any(!known)) {
      knbs_abort(
        c(
          "{.val {indicator_id}} carries an unrecognised frequency code; please report it.",
          "x" = "Codes present: {.val {sort(unique(codes))}}."
        ),
        class = "knbs_error_schema_changed",
        call = call
      )
    }
    have <- sort(unique(unname(freq_map[codes])))
    if (length(have) > 1L) {
      knbs_abort(
        c(
          "{.val {indicator_id}} mixes {.val {have}} series.",
          "i" = "Say which to keep with the {.arg frequency} argument."
        ),
        class = "knbs_error_invalid_query",
        call = call
      )
    }
  }
  freq_name <- unname(freq_map[[codes[[1]]]])

  parts <- vector("list", length(series))
  for (i in seq_along(series)) {
    s <- series[[i]]
    n <- length(s$values %||% list())
    if (n == 0L) {
      next
    }
    timeline <- knoema_series_periods(s$startDate, s$endDate, codes[[i]], n,
                                      call = call)
    row <- list(
      period = timeline$period,
      period_label = timeline$label,
      # Cells may be null or non-numeric; both become NA quietly.
      value = vapply(s$values, jsonstat_cell, double(1)),
      unit = rep(
        if (nzchar(as.character(s$unit %||% ""))) as.character(s$unit) else NA_character_,
        n
      ),
      scale = rep(as.numeric(s$scale %||% NA_real_), n)
    )
    for (d in dim_ids) {
      member <- s[[d]]
      if (!is.list(member) || is.null(member$name)) {
        knbs_abort(
          c(
            "A series is missing its {.val {d}} dimension member; please report it."
          ),
          class = "knbs_error_schema_changed",
          call = call
        )
      }
      if (identical(d, geo_dim)) {
        row$geo_code <- rep(
          as.character(member$RegionId %||% member$id %||% member$key), n
        )
        row$geo_name <- rep(as.character(member$name), n)
      } else {
        row[[d]] <- rep(as.character(member$id %||% member$key), n)
        row[[paste0(d, "_label")]] <- rep(as.character(member$name), n)
      }
    }
    parts[[i]] <- tibble::as_tibble(row)
  }
  parts <- parts[!vapply(parts, is.null, logical(1))]
  if (length(parts) == 0L) {
    return(list(
      table = tibble::tibble(
        indicator_id = character(0),
        indicator_name = character(0),
        period = integer(0),
        period_label = character(0),
        value = double(0),
        source_id = character(0)
      ),
      unit = NA_character_,
      frequency = freq_name,
      fixed = character(0),
      scale_note = NULL
    ))
  }
  long <- do.call(rbind, parts)

  # Dimensions with a single member are facts about the whole dataset, not
  # per-row information; they go to metadata rather than constant columns.
  non_geo <- setdiff(dim_ids, geo_dim)
  fixed <- character(0)
  for (d in non_geo) {
    if (length(unique(long[[d]])) == 1L) {
      fixed <- c(
        fixed,
        paste0(dim_names[[d]], " = ", long[[paste0(d, "_label")]][[1]])
      )
      long[[d]] <- NULL
      long[[paste0(d, "_label")]] <- NULL
    }
  }
  varying <- intersect(non_geo, names(long))

  units <- unique(long$unit)
  unit_meta <- if (length(units) == 1L) units[[1]] else NA_character_
  if (length(units) == 1L) {
    long$unit <- NULL
  }

  # The scale field's semantics are the portal's, not ours: values are served
  # as-is, and a scale other than one is surfaced rather than applied.
  scales <- unique(long$scale)
  scale_note <- NULL
  if (length(scales) == 1L && (is.na(scales[[1]]) || scales[[1]] == 1)) {
    long$scale <- NULL
  } else {
    scale_note <- paste0(
      "The source's scale field is carried as-is in the scale column; ",
      "values are as served, with no multiplier applied."
    )
  }

  cols <- list(
    indicator_id = rep(indicator_id, nrow(long)),
    indicator_name = rep(as.character(meta$name %||% NA_character_), nrow(long)),
    period = long$period,
    period_label = long$period_label,
    value = long$value
  )
  if ("geo_code" %in% names(long)) {
    cols$geo_code <- long$geo_code
    cols$geo_name <- long$geo_name
    # Portal region codes, not census territories: the level is not knowable
    # from the code, and is not guessed.
    cols$geo_level <- rep(NA_character_, nrow(long))
  }
  for (d in varying) {
    cols[[d]] <- long[[d]]
    cols[[paste0(d, "_label")]] <- long[[paste0(d, "_label")]]
  }
  if ("unit" %in% names(long)) {
    cols$unit <- long$unit
  }
  if ("scale" %in% names(long)) {
    cols$scale <- long$scale
  }
  cols$source_id <- rep(source_id, nrow(long))
  out <- tibble::as_tibble(cols)

  key_cols <- c(
    "period_label",
    if ("geo_code" %in% names(out)) "geo_code",
    varying
  )
  keys <- do.call(paste, c(out[key_cols], sep = "\r"))
  if (anyDuplicated(keys) > 0L) {
    knbs_abort(
      c(
        "The standardised observations contain duplicate keys.",
        "x" = "Key columns: {.field {key_cols}}.",
        "i" = "This means the dataset changed shape; please report it."
      ),
      class = "knbs_error_validation_failed",
      call = call
    )
  }

  ord <- do.call(order, out[c(setdiff(key_cols, "period_label"), "period_label")])
  list(
    table = out[ord, ],
    unit = unit_meta,
    frequency = freq_name,
    fixed = fixed,
    scale_note = scale_note
  )
}
