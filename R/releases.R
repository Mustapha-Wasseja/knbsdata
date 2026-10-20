# Releases -----------------------------------------------------------------------

#' What KNBS has released lately
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Lists the documents KNBS has added to its website, newest first, with
#' each one's release series where it belongs to one — the monthly CPI and
#' inflation release, Leading Economic Indicators, the quarterly GDP and
#' balance of payments reports, the Economic Survey and the rest — and the
#' call that downloads it. Tenders, job adverts and other notices are left
#' out unless asked for.
#'
#' ```r
#' knbs_releases()                    # the last 30 days
#' knbs_releases(series = "cpi")      # every CPI release, latest first
#' knbs_releases(series = "cpi")[1, ] # has this month's come out?
#' ```
#'
#' @details
#' The date is the day the document was uploaded to the website, which is
#' the day it was released for regular publications. It is not the period
#' covered, and older releases were uploaded in bulk when the library was
#' set up in mid-2023. `period` gives the month (`"2026-09"`) or quarter
#' (`"2026-Q2"`) a title names, and is `NA` where the title names neither.
#'
#' A document's series is read from its title by a curated list of KNBS's
#' regular releases, see [knbs_release_series()]; titles vary ("Kenya
#' Residential Proprety Price Index", "Leading Economic Indicators- March
#' 2026"), so the patterns allow for that. A document matching no series
#' has `series` `NA`. Notices are titles naming a tender, procurement,
#' framework agreement, advert, vacancy or employment form.
#'
#' The publications library is listed once a day and cached, as for
#' [knbs_search()].
#'
#' @param since,until Keep releases on or after `since` and on or before
#'   `until`: dates, or `"YYYY-MM-DD"` strings. By default the last 30 days,
#'   or, when `series` is given, the series' whole history in the library.
#' @param series Keep only these series: ids or names from
#'   [knbs_release_series()], matched without regard to case (`"cpi"`,
#'   `"lei"`, `"Economic Survey"`).
#' @param notices Whether to include tenders, adverts and other notices.
#' @param cache Whether to use the local cache.
#' @param refresh Whether to re-list the library.
#'
#' @return A `knbs_catalogue` tibble: `release_date`, `series`, `period`,
#'   `title`, `format`, `publication_id`, `landing_page`, and `get` — the
#'   call that downloads the document.
#'
#' @seealso [knbs_release_series()], [knbs_publications()], [knbs_search()]
#'
#' @examplesIf interactive()
#' knbs_releases(since = "2026-09-01")
#' knbs_releases(series = c("cpi", "lei"), since = "2026-01-01")
#' @export
knbs_releases <- function(since = NULL,
                          until = NULL,
                          series = NULL,
                          notices = FALSE,
                          cache = knbs_option("cache"),
                          refresh = FALSE) {
  check_bool(notices, "notices")
  wanted <- release_series_resolve(series)
  from <- release_date_arg(since, "since")
  to <- release_date_arg(until, "until")
  if (is.null(from) && is.null(series)) {
    from <- release_today() - 30L
  }
  if (!is.null(from) && !is.null(to) && from > to) {
    knbs_abort(
      c("{.arg since} is after {.arg until}.",
        "x" = "{.val {format(from)}} > {.val {format(to)}}."),
      class = "knbs_error_invalid_argument"
    )
  }

  listing <- publications_listing(cache = cache, refresh = refresh)
  classified <- release_classify(listing$title)

  keep <- rep(TRUE, nrow(listing))
  if (!notices) keep <- keep & !classified$notice
  if (!is.null(from)) keep <- keep & !is.na(listing$release_date) & listing$release_date >= from
  if (!is.null(to)) keep <- keep & !is.na(listing$release_date) & listing$release_date <= to
  if (!is.null(wanted)) keep <- keep & classified$series_id %in% wanted

  out <- tibble::tibble(
    release_date = listing$release_date,
    series = classified$series,
    period = classified$period,
    title = listing$title,
    format = listing$format,
    publication_id = listing$publication_id,
    landing_page = listing$landing_page,
    get = sprintf('knbs_download_publication("%s", destination = ".")', listing$publication_id)
  )[keep, ]
  # Newest upload first; among same-day uploads (the library's 2023
  # migration put years of releases on one date), the latest period first.
  out <- out[order(out$release_date, out$period, decreasing = TRUE, na.last = TRUE), ]

  new_knbs_catalogue(
    out,
    new_knbs_metadata(
      title = "KNBS releases",
      resource_type = "publication",
      source_id = "knbs_publications",
      source_name = "KNBS Publications (website media library)",
      producer = "Kenya National Bureau of Statistics",
      reference_period = paste(
        if (is.null(from)) "start of listing" else format(from), "to",
        if (is.null(to)) "today" else format(to)
      ),
      access = "open",
      notes = c(
        "release_date is the website upload date, not the reference period.",
        "series is read from each title by a curated list; see knbs_release_series().",
        if (!notices) "Tenders, adverts and other notices are left out (notices = TRUE includes them)."
      )
    )
  )
}

#' KNBS's regular release series
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The series [knbs_releases()] recognises, with the id to ask for each by.
#' Curated from the titles in the KNBS website's publications library.
#'
#' @return A tibble with columns `series_id`, `series` and `frequency`.
#' @seealso [knbs_releases()]
#' @examples
#' knbs_release_series()
#' @export
knbs_release_series <- function() {
  defs <- release_series_defs()
  tibble::tibble(series_id = defs$id, series = defs$name, frequency = defs$frequency)
}

# Internals --------------------------------------------------------------------

#' The curated series, most specific first
#'
#' Patterns run against the title in lower case with every run of
#' punctuation a space. Order matters: the first pattern a title matches
#' wins, so county abstracts are tested before the national one.
#'
#' @noRd
release_series_defs <- function() {
  defs <- list(
    c("cpi", "Consumer Price Indices and Inflation Rates", "monthly",
      "consumer price ind[a-z]* and inflation|^kenya highlights of consumer price"),
    c("lei", "Leading Economic Indicators", "monthly",
      "leading economic indicators"),
    c("ppi", "Producer Price Indices", "quarterly",
      "producer price ind"),
    c("cipi", "Construction Input Price Indices", "quarterly",
      "construction input price"),
    c("rppi", "Residential Property Price Index", "quarterly",
      "residential pro[a-z]* price"),
    c("qgdp", "Quarterly Gross Domestic Product", "quarterly",
      "quarterly gross domestic product|quarterly gdp"),
    c("qbop", "Quarterly Balance of Payments and International Trade", "quarterly",
      "quarterly balance of payment"),
    c("qlfs", "Quarterly Labour Force Report", "quarterly",
      "quarterly labour force"),
    c("county_abstract", "County Statistical Abstract", "annual",
      "statistical abstract [a-z ]*county|county statistical abstract"),
    c("abstract", "Statistical Abstract", "annual",
      "statistical abstract"),
    c("economic_survey", "Economic Survey", "annual",
      "^([0-9]{4} )?economic survey"),
    c("facts_figures", "Facts and Figures", "annual",
      "facts and figures"),
    c("gcp", "Gross County Product", "annual",
      "gross county product"),
    c("release_calendar", "Advance Release Calendar", "annual",
      "advance release calendar")
  )
  list(
    id = vapply(defs, `[[`, character(1), 1L),
    name = vapply(defs, `[[`, character(1), 2L),
    frequency = vapply(defs, `[[`, character(1), 3L),
    pattern = vapply(defs, `[[`, character(1), 4L)
  )
}

#' Which titles are notices rather than statistics
#' @noRd
release_notice_pattern <- function() {
  paste0("tender|procurement|framework agreement|clarification for|",
         "advert|vacanc|career|recruit|employment application")
}

#' Series and notice status for each title
#' @noRd
release_classify <- function(titles) {
  text <- trimws(gsub("[^a-z0-9]+", " ", tolower(ifelse(is.na(titles), "", titles))))
  defs <- release_series_defs()
  series_id <- rep(NA_character_, length(text))
  for (i in rev(seq_along(defs$id))) {
    # Reverse order, so the earliest (most specific) pattern writes last.
    hit <- grepl(defs$pattern[[i]], text, perl = TRUE)
    series_id[hit] <- defs$id[[i]]
  }
  notice <- grepl(release_notice_pattern(), text, perl = TRUE) & is.na(series_id)
  list(
    series_id = series_id,
    series = unname(stats::setNames(defs$name, defs$id)[series_id]),
    notice = notice,
    period = release_period(text)
  )
}

#' The month or quarter a release's title says it covers
#'
#' "...Inflation Rates September 2026" is "2026-09"; "...Second Quarter
#' 2026" is "2026-Q2". Anything else, including a bare year, is NA: the
#' title is the only evidence, and it is read only where it is explicit.
#'
#' @param text Titles, lower case, punctuation runs as spaces.
#' @noRd
release_period <- function(text) {
  out <- rep(NA_character_, length(text))
  months <- tolower(month.name)
  month_re <- paste0("\\b(", paste(months, collapse = "|"), ") ([0-9]{4})\\b")
  hit <- regexpr(month_re, text, perl = TRUE)
  found <- regmatches(text, hit)
  if (length(found) > 0L) {
    month <- match(sub(" .*$", "", found), months)
    year <- sub("^.* ", "", found)
    out[hit > 0L] <- sprintf("%s-%02d", year, month)
  }
  quarter_re <- "\\b(first|second|third|fourth) quarter (for )?([0-9]{4})\\b"
  hit <- regexpr(quarter_re, text, perl = TRUE)
  found <- regmatches(text, hit)
  if (length(found) > 0L) {
    q <- match(sub(" .*$", "", found), c("first", "second", "third", "fourth"))
    year <- sub("^.* ", "", found)
    out[hit > 0L & is.na(out)] <- sprintf("%s-Q%d", year, q)[is.na(out[hit > 0L])]
  }
  out
}

#' Resolve series ids or names to ids
#' @noRd
release_series_resolve <- function(series, call = rlang::caller_env()) {
  if (is.null(series)) {
    return(NULL)
  }
  check_character(series, "series", call = call)
  defs <- release_series_defs()
  ids <- vapply(tolower(series), function(s) {
    hit <- which(tolower(defs$id) == s | tolower(defs$name) == s)
    if (length(hit) == 1L) defs$id[[hit]] else NA_character_
  }, character(1))
  if (anyNA(ids)) {
    knbs_abort(
      c(
        "Unknown release series {.val {series[is.na(ids)]}}.",
        "i" = "Known series: {.val {defs$id}}; see {.fn knbs_release_series}."
      ),
      class = "knbs_error_invalid_argument",
      call = call
    )
  }
  unname(ids)
}

#' Today, as the default window sees it; mocked in tests
#' @noRd
release_today <- function() Sys.Date()

#' A date argument, or NULL
#' @noRd
release_date_arg <- function(x, arg, call = rlang::caller_env()) {
  if (is.null(x)) {
    return(NULL)
  }
  if (inherits(x, "Date") && length(x) == 1L && !is.na(x)) {
    return(x)
  }
  parsed <- if (is.character(x) && length(x) == 1L && grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)) {
    tryCatch(as.Date(x), error = function(cnd) as.Date(NA))
  } else {
    as.Date(NA)
  }
  if (is.na(parsed)) {
    knbs_abort(
      c("{.arg {arg}} must be a date or a {.val YYYY-MM-DD} string.",
        "x" = "Got {.obj_type_friendly {x}}."),
      class = "knbs_error_invalid_argument",
      call = call
    )
  }
  parsed
}
