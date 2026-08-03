test_that("the cache directory follows the option", {
  dir <- local_cache()
  expect_identical(knbs_cache_dir(), dir)
})

test_that("cache keys depend on everything that changes the answer", {
  q1 <- new_knbs_query("indicator", resource_id = "FAKE-CPI",
                       filters = list(start = "2020-01"))
  q2 <- new_knbs_query("indicator", resource_id = "FAKE-CPI",
                       filters = list(start = "2020-02"))

  expect_false(identical(cache_key("s", "fetch", q1), cache_key("s", "fetch", q2)))
  expect_false(identical(cache_key("s", "fetch", q1), cache_key("other", "fetch", q1)))
  expect_false(identical(cache_key("s", "fetch", q1), cache_key("s", "search", q1)))
})

test_that("filter order and value type do not change the key", {
  a <- new_knbs_query("indicator", filters = list(b = 2, a = "1"))
  b <- new_knbs_query("indicator", filters = list(a = 1, b = "2"))
  expect_identical(cache_key("s", "fetch", a), cache_key("s", "fetch", b))
})

test_that("values round-trip through the cache", {
  local_cache()
  key <- cache_key("fake_source", "fetch", new_knbs_query("indicator"))
  value <- list(rows = 1:3, note = "hello")

  cache_write(key, value)
  expect_identical(cache_read(key), value)
})

test_that("a cache hit avoids the fetch and refresh forces it", {
  local_cache()
  key <- cache_key("fake_source", "fetch", new_knbs_query("indicator"))
  calls <- 0L
  fetch <- function() {
    calls <<- calls + 1L
    "payload"
  }

  expect_identical(cache_fetch(key, fetch), "payload")
  expect_identical(calls, 1L)

  expect_identical(cache_fetch(key, fetch), "payload")
  expect_identical(calls, 1L)

  expect_identical(cache_fetch(key, fetch, refresh = TRUE), "payload")
  expect_identical(calls, 2L)
})

test_that("caching can be switched off entirely", {
  local_cache()
  key <- cache_key("fake_source", "fetch", new_knbs_query("indicator"))
  calls <- 0L
  fetch <- function() {
    calls <<- calls + 1L
    "payload"
  }

  cache_fetch(key, fetch, cache = FALSE)
  cache_fetch(key, fetch, cache = FALSE)

  expect_identical(calls, 2L)
  expect_identical(nrow(knbs_cache_info()), 0L)
})

test_that("expired entries are not served", {
  local_cache()
  key <- cache_key("fake_source", "fetch", new_knbs_query("indicator"))

  cache_write(key, "stale", ttl = -1)
  expect_null(cache_read(key))
})

test_that("an immutable entry never expires", {
  local_cache()
  key <- cache_key("fake_source", "fetch", new_knbs_query("indicator"))

  cache_write(key, "pinned", ttl = knbs_cache_ttl("immutable"))
  expect_identical(cache_read(key), "pinned")
  expect_true(is.na(knbs_cache_info()$expires_at))
})

test_that("a corrupt value is discarded rather than returned", {
  dir <- local_cache()
  key <- cache_key("fake_source", "fetch", new_knbs_query("indicator"))
  cache_write(key, "good")

  # Truncate the payload behind the cache's back.
  writeLines("not an rds file", file.path(dir, paste0(key, ".rds")))

  expect_null(cache_read(key))
  expect_false(file.exists(file.path(dir, paste0(key, ".rds"))))
  expect_false(file.exists(file.path(dir, paste0(key, ".json"))))
})

test_that("a value that no longer matches its checksum is discarded", {
  dir <- local_cache()
  key <- cache_key("fake_source", "fetch", new_knbs_query("indicator"))
  cache_write(key, "good")

  saveRDS("tampered", file.path(dir, paste0(key, ".rds")))

  expect_null(cache_read(key))
  expect_false(file.exists(file.path(dir, paste0(key, ".rds"))))
})

test_that("entries written by a different parser version are discarded", {
  dir <- local_cache()
  key <- cache_key("fake_source", "fetch", new_knbs_query("indicator"))
  cache_write(key, "good")

  meta_path <- file.path(dir, paste0(key, ".json"))
  meta <- jsonlite::fromJSON(meta_path, simplifyVector = TRUE)
  meta$parser_version <- 999L
  jsonlite::write_json(meta, meta_path, auto_unbox = TRUE, null = "null")

  expect_null(cache_read(key))
})

test_that("cache_info reports what is stored", {
  local_cache()
  expect_identical(nrow(knbs_cache_info()), 0L)

  key <- cache_key("fake_source", "fetch", new_knbs_query("indicator"))
  cache_write(key, "value", info = list(
    source_id = "fake_source", operation = "fetch", resource_id = "FAKE-CPI"
  ))

  info <- knbs_cache_info()
  expect_s3_class(info, "tbl_df")
  expect_identical(nrow(info), 1L)
  expect_identical(info$source_id, "fake_source")
  expect_identical(info$resource_id, "FAKE-CPI")
  expect_false(info$expired)
  expect_gt(info$size_bytes, 0)
})

test_that("prune removes only expired entries and clear removes everything", {
  local_cache()
  fresh <- cache_key("fake_source", "fetch", new_knbs_query("indicator", resource_id = "A"))
  stale <- cache_key("fake_source", "fetch", new_knbs_query("indicator", resource_id = "B"))
  cache_write(fresh, "keep")
  cache_write(stale, "drop", ttl = -1)

  expect_identical(knbs_cache_prune(quiet = TRUE), 1L)
  expect_identical(nrow(knbs_cache_info()), 1L)
  expect_identical(cache_read(fresh), "keep")

  expect_identical(knbs_cache_clear(quiet = TRUE), 1L)
  expect_identical(nrow(knbs_cache_info()), 0L)
})

test_that("clearing an empty cache is harmless", {
  local_cache()
  expect_identical(knbs_cache_clear(quiet = TRUE), 0L)
  expect_identical(knbs_cache_prune(quiet = TRUE), 0L)
})
