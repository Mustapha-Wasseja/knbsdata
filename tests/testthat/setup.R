# No test may reach the network. Every source's entry point is mocked where a
# test needs it; a request that slips past fails here instead of quietly
# depending on a live service - and on the network of whoever runs the tests.
httr2::local_mocked_responses(
  function(req) stop("A test made a real HTTP request: ", req$url, call. = FALSE),
  env = testthat::teardown_env()
)

# Nor may a test write to the user's own cache: every test that does not set
# its own temporary cache gets this one.
withr::local_options(
  list(knbsdata.cache_dir = file.path(tempdir(), "knbsdata-test-cache")),
  .local_envir = testthat::teardown_env()
)
