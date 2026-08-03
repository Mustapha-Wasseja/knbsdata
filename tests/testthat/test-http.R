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
