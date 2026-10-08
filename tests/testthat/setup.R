# No test may reach the network. Every source's entry point is mocked where a
# test needs it; a request that slips past fails here instead of quietly
# depending on a live service - and on the network of whoever runs the tests.
httr2::local_mocked_responses(
  function(req) stop("A test made a real HTTP request: ", req$url, call. = FALSE),
  env = testthat::teardown_env()
)
