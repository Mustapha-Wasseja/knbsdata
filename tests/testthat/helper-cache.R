# Point the cache at a throwaway directory for the duration of a test, so no
# test can ever read or write the user's real cache.
local_cache <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  withr::local_options(list(knbsdata.cache_dir = dir), .local_envir = env)
  dir
}

# Build an httr2 response without a server.
fake_response <- function(status = 200L,
                          headers = list(),
                          body = "",
                          url = "https://example.invalid/resource") {
  httr2::response(
    status_code = status,
    url = url,
    method = "GET",
    headers = headers,
    body = charToRaw(body)
  )
}
