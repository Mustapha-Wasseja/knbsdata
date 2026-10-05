# Citations -------------------------------------------------------------------
#
# A citation is assembled from the metadata rather than composed by hand, so a
# citation cannot claim a release or a retrieval date the object does not have
# (plan section 11.17). A citation supplied by the source takes precedence over
# anything the package would write itself.

#' Cite a knbsdata object
#'
#' Builds a citation from the object's provenance metadata. Where the source
#' supplies its own required citation, that text is used and the package adds
#' only the retrieval information.
#'
#' @param x A knbsdata object or a `knbs_metadata` object.
#' @param style `"plain"`, `"bibtex"` or `"ris"`.
#' @param include_retrieval_date Whether to record when the data were retrieved.
#'   Retrieval date matters for reproducibility whenever a `"latest"` release was
#'   requested.
#' @param ... Passed to methods.
#'
#' @return A `knbs_citation` object; print it, or use [format()] to get a string.
#'
#' @seealso [knbs_metadata()]
#'
#' @examples
#' # Citations are produced from objects returned by knbsdata.
#' @export
knbs_cite <- function(x,
                      style = c("plain", "bibtex", "ris"),
                      include_retrieval_date = TRUE,
                      ...) {
  UseMethod("knbs_cite")
}

#' @export
knbs_cite.knbs_data <- function(x,
                                style = c("plain", "bibtex", "ris"),
                                include_retrieval_date = TRUE,
                                ...) {
  knbs_cite(knbs_metadata(x), style = style,
            include_retrieval_date = include_retrieval_date, ...)
}

#' @export
knbs_cite.knbs_metadata <- function(x,
                                    style = c("plain", "bibtex", "ris"),
                                    include_retrieval_date = TRUE,
                                    ...) {
  style <- rlang::arg_match(style)
  check_bool(include_retrieval_date, "include_retrieval_date")

  text <- switch(style,
    plain = cite_plain(x, include_retrieval_date),
    bibtex = cite_bibtex(x, include_retrieval_date),
    ris = cite_ris(x, include_retrieval_date)
  )
  new_knbs_citation(text, style = style)
}

#' @export
knbs_cite.default <- function(x, ...) {
  knbs_abort(
    c(
      "{.fn knbs_cite} does not know how to cite {.obj_type_friendly {x}}.",
      "i" = "It works on objects returned by knbsdata."
    ),
    class = "knbs_error_invalid_argument"
  )
}

new_knbs_citation <- function(text, style) {
  structure(list(text = text, style = style), class = "knbs_citation")
}

#' @export
format.knbs_citation <- function(x, ...) x$text

#' @export
print.knbs_citation <- function(x, ...) {
  cat(x$text, sep = "\n")
  invisible(x)
}

# Builders --------------------------------------------------------------------

cite_year <- function(meta) {
  if (!is.null(meta$release_date)) {
    return(substr(format_metadata_value(meta$release_date), 1L, 4L))
  }
  if (!is.null(meta$reference_period)) {
    period <- format_metadata_value(meta$reference_period)
    year <- regmatches(period, regexpr("[0-9]{4}", period))
    if (length(year) == 1L) {
      return(year)
    }
  }
  format(Sys.Date(), "%Y")
}

#' The calendar date of a retrieval, in the user's own time zone
#'
#' as.Date() reads a time in UTC, so a retrieval in the first three hours of
#' a Nairobi day (UTC+3) was cited as the day before. Formatting with an
#' explicit `tz = ""` reads it in local time, the time the user saw, even
#' when the time itself is labelled UTC.
#'
#' @noRd
retrieval_date <- function(x) {
  x <- x %||% Sys.time()
  if (inherits(x, "POSIXt")) {
    return(as.Date(format(x, "%Y-%m-%d", tz = "")))
  }
  as.Date(x)
}

cite_retrieval <- function(meta) {
  paste0(
    "Retrieved ", format(retrieval_date(meta$retrieved_at), "%d %B %Y"),
    " using knbsdata version ", meta$package_version %||%
      as.character(utils::packageVersion("knbsdata")), "."
  )
}

cite_plain <- function(meta, include_retrieval_date) {
  # A citation the source requires takes precedence over one we would compose.
  head <- if (!is.null(meta$citation)) {
    # A source-supplied citation may or may not be punctuated; the retrieval
    # sentence that follows must not run into it.
    supplied <- trimws(meta$citation)
    if (grepl("[.!?]$", supplied)) supplied else paste0(supplied, ".")
  } else {
    parts <- c(
      meta$producer %||% "Kenya National Bureau of Statistics",
      meta$title %||% meta$resource_id %||% "Untitled dataset"
    )
    if (!is.null(meta$version)) parts <- c(parts, paste0("version ", meta$version))
    if (!is.null(meta$release_date)) {
      parts <- c(parts, paste0("release dated ",
                               format(as.Date(meta$release_date), "%d %B %Y")))
    }
    paste0(paste(parts, collapse = ". "), ".")
  }

  tail <- character(0)
  if (!is.null(meta$source_url)) tail <- c(tail, paste0("Available at ", meta$source_url, "."))
  if (include_retrieval_date) tail <- c(tail, cite_retrieval(meta))
  paste(c(head, tail), collapse = " ")
}

cite_bibtex <- function(meta, include_retrieval_date) {
  key <- gsub("[^A-Za-z0-9]+", "", meta$resource_id %||% meta$title %||% "knbsdata")
  fields <- c(
    title = meta$title %||% meta$resource_id %||% "Untitled dataset",
    author = paste0("{", meta$producer %||% "Kenya National Bureau of Statistics", "}"),
    year = cite_year(meta),
    url = meta$source_url,
    note = meta$citation
  )
  if (include_retrieval_date) {
    fields <- c(fields, urldate = format(retrieval_date(meta$retrieved_at), "%Y-%m-%d"))
  }
  fields <- fields[!vapply(fields, function(v) is.null(v) || is.na(v), logical(1))]
  c(
    paste0("@misc{", key, ","),
    paste0("  ", names(fields), " = {", unlist(fields), "},"),
    "}"
  )
}

cite_ris <- function(meta, include_retrieval_date) {
  lines <- c(
    "TY  - DATA",
    paste0("TI  - ", meta$title %||% meta$resource_id %||% "Untitled dataset"),
    paste0("AU  - ", meta$producer %||% "Kenya National Bureau of Statistics"),
    paste0("PY  - ", cite_year(meta))
  )
  if (!is.null(meta$source_url)) lines <- c(lines, paste0("UR  - ", meta$source_url))
  if (!is.null(meta$resource_id)) lines <- c(lines, paste0("ID  - ", meta$resource_id))
  if (!is.null(meta$citation)) lines <- c(lines, paste0("N1  - ", meta$citation))
  if (include_retrieval_date) {
    lines <- c(lines, paste0("Y2  - ",
                             format(retrieval_date(meta$retrieved_at), "%Y/%m/%d")))
  }
  c(lines, "ER  - ")
}
