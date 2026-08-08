# WordPress adapter -----------------------------------------------------------
#
# Talks to a WordPress site's core REST API (`wp/v2`), reading its media library
# as a publications catalogue. Verified against www.knbs.or.ke on 2026-08-08;
# see the source audit, findings F-11 to F-14.
#
# Two deliberate boundaries:
#
#   - Only the media library is read. The site also runs Download Monitor,
#     whose REST routes answer 403 to anonymous callers (F-12); the package
#     does not go near authenticated routes.
#   - The `date` field is the upload date, not the publication's reference
#     period (F-13). The reference year is derived from the title or left NA,
#     never guessed from the date.

#' Build a wp/v2 API URL
#' @noRd
wp_url <- function(source, path) {
  paste0(sub("/+$", "", source$base_url), "/", path)
}

#' A wp/v2 GET
#'
#' Returns the parsed payload with the collection totals from the `X-WP-Total`
#' headers attached as attributes, since WordPress reports them out of band.
#' Throttled to one request per second, as for every source.
#'
#' @noRd
wp_get <- function(source, path, query = list(), call = rlang::caller_env()) {
  req <- knbs_request(wp_url(source, path), throttle = 1)
  if (length(query) > 0L) {
    req <- httr2::req_url_query(req, !!!query)
  }
  resp <- knbs_perform(
    req,
    source_id = source$source_id,
    expect = "json",
    body_check = function(resp) wp_body_check(resp, source$source_id, call = call),
    call = call
  )
  payload <- parse_json_response(resp, source_id = source$source_id, call = call)
  attr(payload, "wp_total") <- as.integer(
    httr2::resp_header(resp, "X-WP-Total") %||% NA_integer_
  )
  # Pagination must trust this header, not row counts: the live server returns
  # short pages even in the middle of the listing (99, 89, 100 rows observed
  # with per_page=100), so "fewer rows than asked for" does not mean "last
  # page" here.
  attr(payload, "wp_total_pages") <- as.integer(
    httr2::resp_header(resp, "X-WP-TotalPages") %||% NA_integer_
  )
  attr(payload, "knbs_http_status") <- httr2::resp_status(resp)
  payload
}

#' Map WordPress's own error bodies onto the right conditions
#'
#' An unknown id answers `404 {"code":"rest_post_invalid_id",...}`; treat it as
#' a missing resource with a message that says so, rather than a bare 404.
#'
#' @noRd
wp_body_check <- function(resp, source_id, call = rlang::caller_env()) {
  status <- httr2::resp_status(resp)
  if (status < 400L) {
    return(invisible(resp))
  }
  body <- tryCatch(httr2::resp_body_string(resp), error = function(cnd) "")
  if (grepl("rest_post_invalid_id", body, fixed = TRUE)) {
    knbs_abort(
      c(
        "The source has no publication with that identifier.",
        "i" = "Identifiers are the numeric ids from {.fn knbs_publications}."
      ),
      class = "knbs_error_resource_not_found",
      call = call
    )
  }
  if (grepl("rest_forbidden", body, fixed = TRUE)) {
    knbs_abort(
      c(
        "The source refused access to this route.",
        "i" = "Source: {.val {source_id}}.",
        "i" = "knbsdata only uses the site's public routes; this one is gated."
      ),
      class = "knbs_error_access_restricted",
      call = call
    )
  }
  invisible(resp)
}

#' Insist a payload is a collection / record of media objects
#'
#' @noRd
wp_expect_media <- function(payload, source_id, operation, call = rlang::caller_env()) {
  # A collection is an unnamed list of records; a record is a named list with
  # an id and a source_url. Anything else means the route changed.
  is_record <- function(x) is.list(x) && !is.null(x[["id"]]) && !is.null(x[["source_url"]])
  ok <- if (rlang::is_named(payload)) {
    is_record(payload)
  } else {
    length(payload) == 0L || all(vapply(payload, is_record, logical(1)))
  }
  if (ok) {
    return(invisible(payload))
  }
  knbs_abort(
    c(
      "The source returned an unexpected payload for {.field {operation}}.",
      "i" = "Source: {.val {source_id}}.",
      "i" = "The media route has probably changed shape; please report this."
    ),
    class = "knbs_error_schema_changed",
    call = call
  )
}

# Operations ------------------------------------------------------------------

#' @export
source_search.knbs_source_wordpress <- function(source, query, ...) {
  check_operation(source, "search_publications")
  check_source_verified(source)
  check_supported_filters(query, c("search", "after", "before", "mime_type", "limit", "page"))

  filters <- query$filters
  params <- compact_list(list(
    media_type = "application",
    search = filters$search,
    after = filters$after,
    before = filters$before,
    mime_type = filters$mime_type,
    per_page = filters$limit %||% 100L,
    page = filters$page,
    orderby = "date",
    order = "desc"
  ))
  params <- lapply(params, as.character)

  payload <- wp_get(source, "media", params)
  wp_expect_media(payload, source$source_id, "search_publications")

  out <- if (length(payload) == 0L) {
    empty_tibble(knbs_publication_columns())
  } else {
    standardise_wp_publications(payload, source$source_id)
  }

  new_knbs_catalogue(
    out,
    new_knbs_metadata(
      title = paste0(source$source_name, " catalogue"),
      resource_type = "publication",
      source_id = source$source_id,
      source_name = source$source_name,
      source_url = source$landing_page %||% source$base_url,
      producer = source$owner,
      access = "open",
      notes = paste0(
        "Matched ", attr(payload, "wp_total") %||% length(payload),
        " documents in the site's media library."
      ),
      # Structured pagination facts for the public layer, which needs them to
      # page a format-filtered search honestly.
      raw = list(
        wp_total = attr(payload, "wp_total"),
        wp_total_pages = attr(payload, "wp_total_pages")
      )
    )
  )
}

#' @export
source_metadata.knbs_source_wordpress <- function(source, resource_id, ...) {
  check_operation(source, "publication_metadata")
  check_source_verified(source)
  check_string(resource_id, "resource_id")
  if (!grepl("^[0-9]+$", resource_id)) {
    knbs_abort(
      c(
        "Publication identifiers are numeric.",
        "x" = "Got {.val {resource_id}}.",
        "i" = "Find them in the {.field publication_id} column of {.fn knbs_publications}."
      ),
      class = "knbs_error_invalid_argument"
    )
  }

  payload <- wp_get(source, paste0("media/", resource_id))
  wp_expect_media(payload, source$source_id, "publication_metadata")
  record <- standardise_wp_publications(list(payload), source$source_id)

  new_knbs_metadata(
    title = record$title,
    resource_id = record$publication_id,
    resource_type = "publication",
    source_id = source$source_id,
    source_name = source$source_name,
    source_url = record$landing_page,
    producer = source$owner,
    release_date = record$release_date,
    reference_period = if (is.na(record$year)) NULL else as.character(record$year),
    unit = NULL,
    access = "open",
    notes = c(
      paste0("File: ", record$file_name, " (", record$format, ", ",
             pretty_number(record$file_size), " bytes)"),
      paste0("Download URL: ", record$download_url),
      "The release date is the site's upload date, not the reference period."
    ),
    raw = payload
  )
}

#' @export
source_health.knbs_source_wordpress <- function(source, ...) {
  started <- Sys.time()
  outcome <- tryCatch(
    {
      payload <- wp_get(source, "media", list(media_type = "application", per_page = "1"))
      list(
        status = "ok",
        http_status = attr(payload, "knbs_http_status") %||% NA_integer_,
        message = paste0(
          "Media library answered; ",
          attr(payload, "wp_total") %||% "?", " documents listed."
        )
      )
    },
    knbs_error = function(cnd) {
      list(
        status = "unavailable",
        http_status = cnd$http_status %||% NA_integer_,
        message = conditionMessage(cnd)
      )
    }
  )
  tibble::tibble(
    source_id = source$source_id,
    operation = "search_publications",
    status = outcome$status,
    http_status = as.integer(outcome$http_status),
    response_time_ms = as.numeric(difftime(Sys.time(), started, units = "secs")) * 1000,
    checked_at = started,
    message = outcome$message
  )
}
