# HTTP layer ------------------------------------------------------------------
#
# All network access goes through knbs_request() and knbs_perform(). Nothing
# else in the package may call httr2 directly, so that user agent, timeout,
# retry policy, throttling and error mapping are decided in exactly one place
# (plan section 15).

#' The user agent sent with every request
#'
#' Transparent by design: a source operator should be able to identify the
#' package from their logs.
#'
#' @noRd
knbs_user_agent <- function() {
  override <- knbs_option("user_agent")
  if (!is.null(override)) {
    return(override)
  }
  paste0(
    "knbsdata/", utils::packageVersion("knbsdata"),
    " (https://github.com/Mustapha-Wasseja/knbsdata)"
  )
}

# Only genuinely transient conditions are retried. A 400, 401, 403 or 404 is a
# statement about the request, and repeating it just adds load (plan 15.4).
knbs_is_transient <- function(resp) {
  httr2::resp_status(resp) %in% c(429L, 500L, 502L, 503L, 504L)
}

#' Build a request
#'
#' @param url Absolute URL.
#' @param throttle Optional maximum requests per second for this source.
#'
#' @return An `httr2_request`. Errors are *not* thrown by httr2; status is
#'   mapped by `knbs_perform()` instead.
#' @noRd
knbs_request <- function(url, throttle = NULL) {
  check_string(url, "url")
  if (!grepl("^https?://", url)) {
    knbs_abort(
      c("{.arg url} must be an absolute HTTP(S) URL.", "x" = "Got {.val {url}}."),
      class = "knbs_error_invalid_argument"
    )
  }

  req <- httr2::request(url)
  req <- httr2::req_user_agent(req, knbs_user_agent())
  req <- httr2::req_timeout(req, knbs_option("timeout"))
  req <- httr2::req_retry(
    req,
    max_tries = max(1L, as.integer(knbs_option("retries"))),
    backoff = function(i) min(60, 2^i),
    is_transient = knbs_is_transient
  )
  if (!is.null(throttle)) {
    req <- httr2::req_throttle(req, rate = throttle)
  }
  # Status is inspected in knbs_perform() so that every failure becomes a
  # classed knbsdata condition rather than an httr2 one.
  httr2::req_error(req, is_error = function(resp) FALSE)
}

#' Perform a request and map failures onto knbsdata conditions
#'
#' @param req An `httr2_request`.
#' @param source_id Source id, used in error messages.
#' @param expect Expected content type keyword, or `NULL` to skip the check.
#'
#' @return An `httr2_response`.
#' @noRd
#' @param body_check Optional function of the response, consulted before the
#'   generic status mapping. A source that describes its failures in the body
#'   can use it to raise a more specific condition than the status alone allows.
#' @param path Optional file to stream the body into, instead of memory.
#' @noRd
knbs_perform <- function(req,
                         source_id = NULL,
                         expect = NULL,
                         body_check = NULL,
                         path = NULL,
                         call = rlang::caller_env()) {
  perform <- function(req) {
    tryCatch(httr2::req_perform(req, path = path), error = function(cnd) cnd)
  }
  supplement <- knbs_tls_supplement(req$url)
  resp <- if (is.null(supplement)) {
    perform(req)
  } else {
    perform_supplemented(req, supplement, perform)
  }

  if (inherits(resp, "error")) {
    knbs_abort(
      c(
        "Could not reach {.val {source_id %||% 'the source'}}.",
        "x" = "{conditionMessage(resp)}",
        "i" = "The source may be unavailable, or the network may be blocked."
      ),
      class = "knbs_error_source_unavailable",
      call = call
    )
  }

  check_auth_gate(resp, source_id = source_id, call = call)
  if (!is.null(body_check)) {
    body_check(resp)
  }
  check_http_status(resp, source_id = source_id, call = call)
  if (!is.null(expect)) {
    check_content_type(resp, expect = expect, source_id = source_id, call = call)
  }
  resp
}

#' Certificates a server fails to send, for the hosts known to need them
#'
#' www.knbs.or.ke serves its certificate without the intermediates linking it
#' to a trusted root: audit F-06, resolved by F-11, and back since a renewal
#' (F-43). Browsers fetch missing intermediates themselves; libcurl with
#' OpenSSL does not, so every request failed with "unable to get local issuer
#' certificate". The package ships Let's Encrypt's Generation Y
#' intermediates, the cross-signed Generation Y roots, and ISRG Root X1 and X2
#' (`inst/extdata/tls/`). A request to these hosts that fails certificate
#' verification is retried once with that bundle as its trust store, and the
#' session remembers which store worked (`perform_supplemented()`).
#'
#' Verification is never switched off. The bundle verifies only a certificate
#' that names the host and chains through Let's Encrypt to an ISRG root. A host
#' that verifies normally never needs the bundle, so a server that is fixed, or
#' moves to another authority, needs no change here.
#'
#' @return The bundle's path, or `NULL` for any other host.
#' @noRd
knbs_tls_supplement <- function(url) {
  host <- tolower(httr2::url_parse(url)$hostname %||% "")
  if (!host %in% c("knbs.or.ke", "www.knbs.or.ke")) {
    return(NULL)
  }
  path <- system.file("extdata", "tls", "knbs-or-ke-chain.pem", package = "knbsdata")
  if (nzchar(path)) path else NULL
}

#' Perform a request to a host with shipped intermediates
#'
#' One trust store is tried, and on a certificate failure the other: the
#' default store, or the shipped bundle. Certificates are verified either way.
#' Whichever worked is remembered for the session, so later requests to the
#' host start there instead of failing first. On an older httr2 that retries
#' failed connections with backoff, a failing first attempt cost about ten
#' seconds per request, and `knbs_releases()` makes dozens.
#'
#' @param perform The caller's `perform()`, which returns an error condition
#'   rather than throwing it.
#' @noRd
perform_supplemented <- function(req, supplement, perform) {
  host <- tolower(httr2::url_parse(req$url)$hostname)
  bundle_first <- host %in% the$tls_bundle_hosts
  stores <- list(req, httr2::req_options(req, cainfo = supplement))
  if (bundle_first) stores <- rev(stores)

  resp <- perform(stores[[1]])
  if (inherits(resp, "error") && is_certificate_failure(resp)) {
    resp <- perform(stores[[2]])
    if (!inherits(resp, "error")) {
      # The other store worked: start with it from now on.
      the$tls_bundle_hosts <- if (bundle_first) {
        setdiff(the$tls_bundle_hosts, host)
      } else {
        union(the$tls_bundle_hosts, host)
      }
    }
  }
  resp
}

#' Whether a failed request failed certificate verification
#'
#' Some versions of the curl package class the error
#' (`curl_error_peer_failed_verification`); others raise a plain error, so its
#' message, or a parent's, is read as well.
#'
#' @noRd
is_certificate_failure <- function(cnd) {
  while (!is.null(cnd)) {
    if (inherits(cnd, "curl_error_peer_failed_verification") ||
        grepl("certificate", conditionMessage(cnd), ignore.case = TRUE)) {
      return(TRUE)
    }
    cnd <- cnd$parent
  }
  FALSE
}

#' Detect a login gate that does not use a redirect status
#'
#' KeNADA answers a request for gated material with `200 OK`, an empty body and
#' a `Refresh` header pointing at its login page (source audit finding F-03).
#' Because that is a header and not a 3xx, both `curl -L` and httr2 follow
#' nothing and hand back a perfectly successful, perfectly empty response. Left
#' unchecked it would be reported to the user as an empty dataset.
#'
#' @noRd
check_auth_gate <- function(resp, source_id = NULL, call = rlang::caller_env()) {
  refresh <- httr2::resp_header(resp, "Refresh")
  if (is.null(refresh) || !grepl("login", refresh, ignore.case = TRUE)) {
    return(invisible(resp))
  }

  target <- sub("^.*url=", "", refresh, ignore.case = TRUE)
  knbs_abort(
    c(
      "This resource requires an account with the source.",
      "i" = "Sign in and complete the official access process at {.url {target}}.",
      "i" = "knbsdata does not automate sign-in, licence acceptance or approval workflows."
    ),
    class = "knbs_error_authentication_required",
    call = call,
    access_url = target,
    source_id = source_id
  )
}

#' Map an HTTP status onto a knbsdata condition
#'
#' @noRd
check_http_status <- function(resp, source_id = NULL, call = rlang::caller_env()) {
  status <- httr2::resp_status(resp)
  if (status < 400L) {
    return(invisible(resp))
  }

  url <- resp$url %||% "<unknown>"
  info <- switch(
    as.character(status),
    "400" = list("knbs_error_invalid_query", "The source rejected the query as invalid."),
    "401" = list("knbs_error_authentication_required", "The source requires authentication."),
    "403" = list("knbs_error_access_restricted", "The source refused access to this resource."),
    "404" = list("knbs_error_resource_not_found", "The source has no such resource."),
    "409" = list("knbs_error_source_unavailable", "The source reported a conflict."),
    "429" = list("knbs_error_rate_limited", "The source is rate limiting requests."),
    if (status >= 500L) {
      list("knbs_error_source_unavailable", "The source failed to answer.")
    } else {
      list("knbs_error_source_unavailable", "The source returned an unexpected status.")
    }
  )

  bullets <- c(
    info[[2]],
    "x" = "HTTP {status} from {.url {url}}.",
    "i" = "Source: {.val {source_id %||% 'unknown'}}."
  )
  if (status == 429L) {
    retry_after <- httr2::resp_header(resp, "Retry-After")
    if (!is.null(retry_after)) {
      bullets <- c(bullets, "i" = "The source asked to wait {retry_after} seconds.")
    }
  }

  knbs_abort(bullets, class = info[[1]], call = call, http_status = status, url = url)
}

#' Verify the response is the kind of thing we asked for
#'
#' A source that starts returning an HTML error page where JSON used to be is a
#' schema change, not a parse failure of the user's making.
#'
#' @noRd
check_content_type <- function(resp,
                               expect,
                               source_id = NULL,
                               call = rlang::caller_env()) {
  observed <- httr2::resp_content_type(resp) %||% "<none>"
  if (grepl(expect, observed, fixed = TRUE)) {
    return(invisible(resp))
  }
  knbs_abort(
    c(
      "The source returned an unexpected content type.",
      "x" = "Expected {.val {expect}} but got {.val {observed}}.",
      "i" = "Source: {.val {source_id %||% 'unknown'}}.",
      "i" = "This usually means the source changed; please report it."
    ),
    class = "knbs_error_schema_changed",
    call = call
  )
}
