# Publications: public interface ----------------------------------------------

#' Search official KNBS publications
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Searches the documents in the KNBS website's media library: statistical
#' releases, survey reports, the Economic Survey and other published files.
#'
#' @details
#' Two honesty notes about this source. First, `release_date` is the date the
#' file was uploaded to the site, not the publication's reference period; the
#' `year` column is read from the title, and is `NA` when the title names none.
#' Second, the media library also holds speeches, launch remarks and forms —
#' narrowing to what you mean is the job of `query` and `format`.
#'
#' The reference-year filter is applied to the title-derived `year`, after
#' retrieval. With a narrow `query` this is exact; with a broad one it filters
#' only within the `limit` most recent matches.
#'
#' @param query Free-text search over titles and descriptions.
#' @param year Keep only publications whose title names this year, or a range
#'   `c(from, to)`.
#' @param format Keep only these file formats: any of `"pdf"`, `"xlsx"`,
#'   `"xls"`, `"docx"`, `"csv"`, `"zip"`.
#' @param limit Maximum number of records to return (at most 100 per request).
#' @param source Source id. Defaults to the first verified publications source.
#' @param cache Whether to use the local cache.
#' @param refresh Whether to bypass any cached response.
#'
#' @return A `knbs_catalogue` tibble with columns `publication_id`, `title`,
#'   `year`, `release_date`, `modified`, `description`, `format`, `file_size`,
#'   `file_name`, `download_url`, `landing_page`, `source_id`, `checksum` and
#'   `access`.
#'
#' @seealso [knbs_download_publication()]
#'
#' @examples
#' \dontrun{
#' knbs_publications("economic survey")
#' knbs_publications("consumer price", format = "xlsx")
#' knbs_publications("census", year = c(2019, 2023))
#' }
#' @export
knbs_publications <- function(query = NULL,
                              year = NULL,
                              format = NULL,
                              limit = 100,
                              source = NULL,
                              cache = knbs_option("cache"),
                              refresh = FALSE) {
  if (!is.null(query)) check_string(query, "query")
  if (!is.null(format)) {
    check_values(format, "format", names(knbs_publication_formats()))
  }
  check_number(limit, "limit", min = 1)
  if (limit > 100) {
    knbs_abort(
      c(
        "{.arg limit} can be at most 100 for this source.",
        "i" = "Narrow the search with {.arg query} or {.arg format} instead."
      ),
      class = "knbs_error_invalid_argument"
    )
  }
  years <- normalise_year_range(year)

  src <- resolve_source("search_publications", source)

  # A single format can be filtered by the source; several are filtered here.
  mime <- if (!is.null(format) && length(format) == 1L) {
    unname(knbs_publication_formats()[format])
  } else {
    NULL
  }

  knbs_query <- new_knbs_query(
    "publication",
    filters = compact_list(list(
      search = query,
      mime_type = mime,
      limit = as.integer(limit)
    )),
    source = src$source_id
  )

  results <- cache_fetch(
    cache_key(src$source_id, "search_publications", knbs_query),
    fetch = function() source_search(src, knbs_query),
    cache = cache,
    refresh = refresh,
    ttl = knbs_cache_ttl("catalogue"),
    info = list(source_id = src$source_id, operation = "search_publications")
  )

  # The format filter is applied here even when it was also sent to the source:
  # the survey audit (F-10) showed this family of APIs can silently ignore a
  # query parameter, and a filter that silently widens is worse than none.
  keep <- rep(TRUE, nrow(results))
  if (!is.null(format)) {
    keep <- keep & results$format %in% format
  }
  if (!is.null(years$from)) {
    keep <- keep & !is.na(results$year) &
      results$year >= years$from & results$year <= years$to
  }
  results <- results[keep, ]
  if (nrow(results) > limit) {
    results <- results[seq_len(limit), ]
  }
  results
}

#' Download a publication and verify what arrived
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Downloads one publication file, preserving its official filename, verifying
#' that a document (not an error page) arrived, checksumming it, and writing a
#' `<file>.metadata.json` provenance sidecar next to it.
#'
#' @param publication_id A `publication_id` from [knbs_publications()].
#' @param destination Directory to write into.
#' @param overwrite Whether to replace an existing file of the same name.
#' @param verify Whether to refuse a response that is a web page rather than a
#'   document.
#' @param sidecar Whether to write the provenance sidecar.
#' @param source Source id.
#' @param quiet Whether to suppress the progress message.
#'
#' @return Invisibly, a one-row tibble describing the download: `local_path`,
#'   `download_url`, `downloaded_at`, `size_bytes`, `sha256` and the identifying
#'   fields.
#'
#' @seealso [knbs_publications()] to find identifiers, [knbs_cite()] to cite
#'   what you downloaded.
#'
#' @examples
#' \dontrun{
#' pubs <- knbs_publications("economic survey", year = 2026)
#' knbs_download_publication(pubs$publication_id[[1]], "data/publications")
#' }
#' @export
knbs_download_publication <- function(publication_id,
                                      destination = ".",
                                      overwrite = FALSE,
                                      verify = TRUE,
                                      sidecar = TRUE,
                                      source = NULL,
                                      quiet = knbs_option("quiet")) {
  check_string(publication_id, "publication_id")
  check_string(destination, "destination")

  src <- resolve_source("download_publication", source)
  meta <- source_metadata(src, publication_id)

  # The URL comes from the raw source record, which the metadata object retains
  # precisely so that structured fields never have to be fished out of prose.
  url <- json_chr(meta$raw, "source_url")
  if (is.na(url)) {
    knbs_abort(
      c(
        "The publication record carries no download URL.",
        "i" = "Publication: {.val {publication_id}}."
      ),
      class = "knbs_error_download_failed"
    )
  }

  record <- knbs_download_file(
    url,
    destination = destination,
    resource_id = meta$resource_id,
    source_id = src$source_id,
    overwrite = overwrite,
    verify = verify,
    sidecar = sidecar,
    quiet = quiet
  )
  invisible(record)
}
