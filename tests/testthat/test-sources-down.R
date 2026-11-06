# A source that does not answer a catalogue search across every source is
# skipped by the later ones in the session, having said so once (see
# knbs_status()). The africa portal answering with a Cloudflare challenge, as
# it has since 2026-10-05, is the case in point.

local_gated_portal <- function(calls, env = parent.frame()) {
  local_knoema_api(list("." = function(path, query) {
    calls$n <- calls$n + 1L
    knbs_abort("The source answered with a human-verification challenge (Cloudflare).",
               class = "knbs_error_access_restricted")
  }), env = env)
}

test_that("a gated source is asked once, warned about once, then skipped", {
  local_cache()
  local_knbsapi()
  calls <- new.env()
  calls$n <- 0L
  local_gated_portal(calls)

  expect_warning(knbs_indicators(), regexp = "skip opendataforafrica for the rest of this session")
  asked <- calls$n
  expect_gt(asked, 0L)

  expect_no_warning(again <- knbs_indicators())
  expect_identical(calls$n, asked)
  expect_false("opendataforafrica" %in% again$source_id)
  expect_match(knbs_metadata(again)$notes, "Skipped, having not answered earlier this session: opendataforafrica",
               all = FALSE)

  # A search folds the same catalogue in, and does not ask either.
  expect_no_warning(hits <- knbs_search("population", type = "indicator"))
  expect_identical(calls$n, asked)
  expect_match(knbs_metadata(hits)$notes, "Skipped.*opendataforafrica", all = FALSE)
})

test_that("a named source, or a refresh, is always asked", {
  local_cache()
  local_knbsapi()
  calls <- new.env()
  calls$n <- 0L
  local_gated_portal(calls)
  suppressWarnings(knbs_indicators())
  asked <- calls$n

  expect_error(knbs_indicators(source = "opendataforafrica"),
               class = "knbs_error_access_restricted")
  expect_gt(calls$n, asked)
  asked <- calls$n
  expect_warning(knbs_indicators(refresh = TRUE), class = "knbs_warning_partial_failure")
  expect_gt(calls$n, asked)
})

test_that("an indicator not found names the skipped source and how to ask it", {
  local_cache()
  local_knbsapi()
  calls <- new.env()
  calls$n <- 0L
  local_gated_portal(calls)
  suppressWarnings(knbs_indicators())

  cnd <- expect_error(knbs_get_indicator("jhbzkjc"), class = "knbs_error_resource_not_found")
  text <- cli::ansi_strip(conditionMessage(cnd))
  expect_match(text, "Could not reach \"opendataforafrica\"", fixed = TRUE)
  expect_match(text, "source = \"opendataforafrica\"", fixed = TRUE)
})

test_that("the offline status reports the failure; a live check asks again", {
  local_cache()
  local_knbsapi()
  calls <- new.env()
  calls$n <- 0L
  local_gated_portal(calls)
  suppressWarnings(knbs_indicators())

  offline <- knbs_status("opendataforafrica", live = FALSE)
  expect_identical(offline$status, "unavailable")
  expect_match(offline$message, "Did not answer at [0-9]{2}:[0-9]{2} this session")
  expect_match(offline$message, "Cloudflare")

  # The portal answers again: a live check finds it, and searches use it.
  local_knoema_api()
  live <- knbs_status("opendataforafrica", live = TRUE)
  expect_identical(live$status, "ok")
  expect_identical(knbs_status("opendataforafrica", live = FALSE)$status, "not_checked")
  expect_no_warning(back <- knbs_indicators())
  expect_true("opendataforafrica" %in% back$source_id)
})

test_that("a live check that fails makes searches skip the source", {
  local_cache()
  local_knbsapi()
  calls <- new.env()
  calls$n <- 0L
  local_gated_portal(calls)

  expect_identical(knbs_status("opendataforafrica", live = TRUE)$status, "unavailable")
  asked <- calls$n
  expect_no_warning(knbs_indicators())
  expect_identical(calls$n, asked)
})

test_that("a schema change is never mistaken for an outage", {
  local_cache()
  local_knbsapi()
  local_knoema_api(list("." = function(path, query) {
    knbs_abort("The dataset listing changed shape; please report it.",
               class = "knbs_error_schema_changed")
  }))
  expect_warning(knbs_indicators(), class = "knbs_warning_partial_failure")
  # Still asked, and still reported, every time.
  expect_warning(knbs_indicators(), class = "knbs_warning_partial_failure")
  expect_null(source_down("opendataforafrica"))
})

test_that("a Cloudflare challenge says what it is", {
  resp <- fake_response(403L, headers = list(`cf-mitigated` = "challenge"),
                        body = "<html>Just a moment...</html>")
  cnd <- expect_error(check_http_status(resp, source_id = "opendataforafrica"),
                      class = "knbs_error_access_restricted")
  text <- cli::ansi_strip(conditionMessage(cnd))
  expect_match(text, "human-verification challenge (Cloudflare)", fixed = TRUE)
  expect_match(text, "never tries to get past such checks", fixed = TRUE)

  plain <- expect_error(check_http_status(fake_response(403L), source_id = "x"),
                        class = "knbs_error_access_restricted")
  expect_match(conditionMessage(plain), "refused access")
})
