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
#' The source ignores its own file-type parameter (audit F-22), so the
#' `format` filter is applied by the package — and because a page of recent
#' uploads may contain no matches at all, supplying `format` makes the search
#' page back through older uploads until it has `limit` matches or the
#' matches are exhausted. Expect a format-filtered search to take a few
#' seconds longer than a plain one.
#'
#' The reference-year filter is applied to the title-derived `year`, after
#' retrieval. With a narrow `query` this is exact; with a broad one it filters
#' only within the records retrieved.
#'
#' @param query Free-text search over titles and descriptions.
#' @param year Keep only publications whose title names this year, or a range
#'   `c(from, to)`.
#' @param format Keep only these file formats: any of `"pdf"`, `"xlsx"`,
#'   `"xls"`, `"docx"`, `"csv"`, `"zip"`.
#' @param limit Maximum number of records to return (at most 100).
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
#' @examplesIf interactive()
#' knbs_publications("economic survey")
#' knbs_publications("consumer price", format = "xlsx")
#' knbs_publications("census", year = c(2019, 2023))
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

  # The mime filter is still sent to the source, but the source ignores it
  # (audit F-22), so filtering is the package's job. Because a whole page of
  # recent uploads can contain no matching format at all, a format-filtered
  # search pages back through older uploads until it has enough matches.
  mime <- if (!is.null(format) && length(format) == 1L) {
    unname(knbs_publication_formats()[format])
  } else {
    NULL
  }

  fetch_page <- function(page, per_page) {
    page_query <- new_knbs_query(
      "publication",
      filters = compact_list(list(
        search = query,
        mime_type = mime,
        limit = as.integer(per_page),
        page = if (page > 1L) as.integer(page) else NULL
      )),
      source = src$source_id
    )
    cache_fetch(
      cache_key(src$source_id, "search_publications", page_query),
      fetch = function() source_search(src, page_query),
      cache = cache,
      refresh = refresh,
      ttl = knbs_cache_ttl("catalogue"),
      info = list(source_id = src$source_id, operation = "search_publications")
    )
  }

  matches_format <- function(batch) {
    if (is.null(format)) rep(TRUE, nrow(batch)) else batch$format %in% format
  }

  if (is.null(format)) {
    first <- fetch_page(1L, limit)
    meta <- knbs_metadata(first)
    collected <- tibble::as_tibble(first)
  } else {
    page_size <- 100L
    page_cap <- 50L
    page <- 1L
    first <- fetch_page(page, page_size)
    meta <- knbs_metadata(first)
    batch <- tibble::as_tibble(first)
    collected <- batch[matches_format(batch), ]

    # How far the listing goes comes from the source's own page count. Row
    # counts cannot be used: this server returns short pages mid-listing, so
    # "fewer rows than asked for" does not mean "last page".
    total_pages <- meta$raw$wp_total_pages %||% NA_integer_

    repeat {
      if (nrow(collected) >= limit) {
        break
      }
      more <- if (is.na(total_pages)) nrow(batch) > 0L else page < total_pages
      if (!more) {
        break
      }
      if (page >= page_cap) {
        knbs_warn(
          c(
            "Stopped after scanning {page_cap} pages of the listing.",
            "i" = "Only the matches found so far are returned; narrow with {.arg query}."
          ),
          class = "knbs_warning_partial_failure"
        )
        break
      }
      page <- page + 1L
      # Running one page past the end answers 400 rather than an empty page;
      # for any page after the first, that means "no more", not "bad query".
      batch <- tryCatch(
        tibble::as_tibble(fetch_page(page, page_size)),
        knbs_error_invalid_query = function(cnd) NULL
      )
      if (is.null(batch)) {
        break
      }
      collected <- rbind(collected, batch[matches_format(batch), ])
    }
    # An upload landing mid-scan shifts every later page by one, which can
    # repeat a boundary record; keep the first sighting.
    collected <- collected[!duplicated(collected$publication_id), ]
  }

  keep <- rep(TRUE, nrow(collected))
  if (!is.null(years$from)) {
    keep <- keep & !is.na(collected$year) &
      collected$year >= years$from & collected$year <= years$to
  }
  collected <- collected[keep, ]
  if (nrow(collected) > limit) {
    collected <- collected[seq_len(limit), ]
  }
  new_knbs_catalogue(collected, meta)
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
#' @param destination Directory to write into; created if needed. There is
#'   no default: nothing is written anywhere you have not named.
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
#' @examplesIf interactive()
#' pubs <- knbs_publications("economic survey", year = 2026)
#' knbs_download_publication(pubs$publication_id[[1]], tempdir())
#' @export
knbs_download_publication <- function(publication_id,
                                      destination,
                                      overwrite = FALSE,
                                      verify = TRUE,
                                      sidecar = TRUE,
                                      source = NULL,
                                      quiet = knbs_option("quiet")) {
  check_string(publication_id, "publication_id")
  if (missing(destination)) {
    abort_no_destination()
  }
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
