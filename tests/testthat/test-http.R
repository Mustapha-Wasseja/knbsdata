test_that("the user agent identifies the package and is overridable", {
  expect_match(knbs_user_agent(), "^knbsdata/")
  expect_match(knbs_user_agent(), "github.com/Mustapha-Wasseja/knbsdata", fixed = TRUE)

  withr::local_options(list(knbsdata.user_agent = "custom/1.0"))
  expect_identical(knbs_user_agent(), "custom/1.0")
})

test_that("requests carry the configured user agent and timeout", {
  withr::local_options(list(knbsdata.timeout = 17, knbsdata.retries = 2))
  req <- knbs_request("https://example.invalid/api")

  expect_s3_class(req, "httr2_request")
  expect_identical(req$options$timeout_ms, 17 * 1000)
  expect_match(req$options$useragent, "^knbsdata/")
})

test_that("only absolute HTTP(S) URLs are accepted", {
  expect_error(knbs_request("example.invalid/api"), class = "knbs_error_invalid_argument")
  expect_error(knbs_request("ftp://example.invalid"), class = "knbs_error_invalid_argument")
  expect_error(knbs_request(42), class = "knbs_error_invalid_argument")
})

test_that("only transient statuses are treated as retryable", {
  for (status in c(429L, 500L, 502L, 503L, 504L)) {
    expect_true(knbs_is_transient(fake_response(status)))
  }
  for (status in c(200L, 400L, 401L, 403L, 404L)) {
    expect_false(knbs_is_transient(fake_response(status)))
  }
})

test_that("a Refresh header pointing at a login page is an auth error", {
  # KeNADA answers gated requests with 200, an empty body and this header
  # (source audit F-03). Without this check the caller would see success.
  resp <- fake_response(
    200L,
    headers = list(
      Refresh = "0;url=https://statistics.knbs.or.ke/nada/index.php/auth/login/?destination=catalog/13/get-microdata"
    ),
    body = ""
  )

  expect_error(check_auth_gate(resp), class = "knbs_error_authentication_required")
  expect_error(check_auth_gate(resp), regexp = "requires an account")

  cnd <- rlang::catch_cnd(check_auth_gate(resp))
  expect_match(cnd$access_url, "auth/login", fixed = TRUE)
})

test_that("an ordinary response passes the auth gate untouched", {
  expect_silent(check_auth_gate(fake_response(200L, body = "{}")))
  expect_silent(check_auth_gate(fake_response(200L, headers = list(Refresh = "5;url=/home"))))
})

test_that("HTTP statuses map onto specific condition classes", {
  expectations <- list(
    "400" = "knbs_error_invalid_query",
    "401" = "knbs_error_authentication_required",
    "403" = "knbs_error_access_restricted",
    "404" = "knbs_error_resource_not_found",
    "429" = "knbs_error_rate_limited",
    "500" = "knbs_error_source_unavailable",
    "503" = "knbs_error_source_unavailable"
  )
  for (status in names(expectations)) {
    expect_error(
      check_http_status(fake_response(as.integer(status)), source_id = "test"),
      class = expectations[[status]]
    )
  }
})

test_that("successful statuses pass through and carry the status on the condition", {
  expect_silent(check_http_status(fake_response(200L)))
  expect_silent(check_http_status(fake_response(204L)))

  cnd <- rlang::catch_cnd(check_http_status(fake_response(429L)))
  expect_identical(cnd$http_status, 429L)
})

test_that("a rate-limit response reports the requested wait", {
  resp <- fake_response(429L, headers = list(`Retry-After` = "30"))
  expect_error(check_http_status(resp), regexp = "30 seconds")
})

test_that("an unexpected content type is reported as a schema change", {
  html <- fake_response(200L, headers = list(`Content-Type` = "text/html"), body = "<html>")
  expect_error(
    check_content_type(html, expect = "json", source_id = "test"),
    class = "knbs_error_schema_changed"
  )

  json <- fake_response(
    200L,
    headers = list(`Content-Type` = "application/json; charset=utf-8"),
    body = "{}"
  )
  expect_silent(check_content_type(json, expect = "json"))
})

# The certificate error www.knbs.or.ke caused before the package shipped its
# missing intermediates (audit F-43), as curl reports it.
incomplete_chain_error <- function() {
  stop("SSL peer certificate or SSH remote key was not OK: [www.knbs.or.ke] ",
       "SSL certificate problem: unable to get local issuer certificate")
}

# Mock the network: `fail(req)` decides whether an attempt fails; every
# attempt's trust store is recorded in `attempts`.
local_tls_server <- function(fail, env = parent.frame()) {
  attempts <- new.env()
  attempts$cainfo <- character(0)
  old <- the$tls_bundle_hosts
  the$tls_bundle_hosts <- NULL
  withr::defer(the$tls_bundle_hosts <- old, envir = env)
  withr::local_options(knbsdata.retries = 1, .local_envir = env)
  httr2::local_mocked_responses(function(req) {
    attempts$cainfo <- c(attempts$cainfo, req$options$cainfo %||% "<default>")
    if (fail(req)) incomplete_chain_error()
    httr2::response(200L, url = req$url,
                    headers = list(`Content-Type` = "application/json"),
                    body = charToRaw("[]"))
  }, env = env)
  attempts
}

test_that("only knbs.or.ke hosts get the shipped intermediates", {
  bundle <- knbs_tls_supplement("https://www.knbs.or.ke/wp-json/wp/v2/media")
  expect_true(file.exists(bundle))
  expect_identical(knbs_tls_supplement("https://knbs.or.ke/reports/"), bundle)
  # Six intermediates, two cross-signed roots, ISRG Root X1 and X2.
  expect_identical(sum(grepl("BEGIN CERTIFICATE", readLines(bundle))), 10L)

  expect_null(knbs_tls_supplement("https://statistics.knbs.or.ke/nada/"))
  expect_null(knbs_tls_supplement("https://www.knbs.or.ke.example.invalid/"))
  expect_null(knbs_tls_supplement("https://example.invalid/www.knbs.or.ke"))
})

test_that("a certificate failure at knbs.or.ke is retried once with them", {
  attempts <- local_tls_server(function(req) is.null(req$options$cainfo))
  resp <- knbs_perform(knbs_request("https://www.knbs.or.ke/wp-json/wp/v2/media"),
                       source_id = "knbs_publications", expect = "json")

  expect_identical(httr2::resp_status(resp), 200L)
  expect_length(attempts$cainfo, 2L)
  expect_identical(attempts$cainfo[[1]], "<default>")
  expect_match(attempts$cainfo[[2]], "knbs-or-ke-chain.pem", fixed = TRUE)
})

test_that("the session remembers which trust store a host needs", {
  media <- function() {
    knbs_perform(knbs_request("https://www.knbs.or.ke/wp-json/wp/v2/media"))
  }

  # The server leaves out its intermediates: only the bundle verifies. Once
  # it was needed, later requests start with it instead of failing first.
  attempts <- local_tls_server(function(req) is.null(req$options$cainfo))
  media()
  media()
  expect_identical(basename(attempts$cainfo),
                   c("<default>", "knbs-or-ke-chain.pem", "knbs-or-ke-chain.pem"))
  expect_identical(the$tls_bundle_hosts, "www.knbs.or.ke")

  # The server moves to another authority: only the default store verifies.
  # It is tried next, and becomes the first choice again.
  attempts <- local_tls_server(function(req) !is.null(req$options$cainfo))
  the$tls_bundle_hosts <- "www.knbs.or.ke"
  media()
  media()
  expect_identical(basename(attempts$cainfo),
                   c("knbs-or-ke-chain.pem", "<default>", "<default>"))
  expect_length(the$tls_bundle_hosts, 0L)
})

test_that("a retry that fails too is reported, not retried again", {
  attempts <- local_tls_server(function(req) TRUE)
  expect_error(
    knbs_perform(knbs_request("https://www.knbs.or.ke/wp-json/wp/v2/media"),
                 source_id = "knbs_publications"),
    class = "knbs_error_source_unavailable"
  )
  expect_length(attempts$cainfo, 2L)
})

test_that("other hosts and other failures are never retried with them", {
  attempts <- local_tls_server(function(req) TRUE)
  expect_error(
    knbs_perform(knbs_request("https://statistics.knbs.or.ke/nada/index.php/api/catalog"),
                 source_id = "kenada"),
    class = "knbs_error_source_unavailable"
  )
  expect_identical(attempts$cainfo, "<default>")

  withr::local_options(knbsdata.retries = 1)
  timeouts <- 0L
  httr2::local_mocked_responses(function(req) {
    timeouts <<- timeouts + 1L
    stop("Timeout was reached: Operation timed out after 30000 milliseconds")
  })
  expect_error(
    knbs_perform(knbs_request("https://www.knbs.or.ke/wp-json/wp/v2/media")),
    class = "knbs_error_source_unavailable"
  )
  expect_identical(timeouts, 1L)
})

test_that("certificate failures are recognised by class or by message", {
  expect_true(is_certificate_failure(tryCatch(incomplete_chain_error(), error = identity)))
  classed <- structure(
    class = c("curl_error_peer_failed_verification", "error", "condition"),
    list(message = "peer failed verification", call = NULL)
  )
  expect_true(is_certificate_failure(classed))
  wrapped <- rlang::catch_cnd(
    rlang::abort("Failed to perform HTTP request.", parent = classed)
  )
  expect_true(is_certificate_failure(wrapped))
  expect_false(is_certificate_failure(simpleError("Could not resolve host")))
})
