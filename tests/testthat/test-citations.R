test_that("a plain citation names the producer, title and retrieval", {
  meta <- new_knbs_metadata(
    title = "Fake consumer price index",
    producer = "Offline test source",
    release_date = as.Date("2020-04-10"),
    source_url = "https://example.invalid/fake/FAKE-CPI",
    retrieved_at = as.POSIXct("2026-08-03 09:00:00", tz = "UTC"),
    package_version = "0.0.0.9000"
  )

  text <- format(knbs_cite(meta))

  expect_match(text, "Offline test source", fixed = TRUE)
  expect_match(text, "Fake consumer price index", fixed = TRUE)
  expect_match(text, "10 April 2020", fixed = TRUE)
  expect_match(text, "03 August 2026", fixed = TRUE)
  expect_match(text, "knbsdata version 0.0.0.9000", fixed = TRUE)
})

test_that("a citation supplied by the source takes precedence", {
  meta <- new_knbs_metadata(
    title = "Ignored title",
    citation = "Offline test source. Fake Household Survey 2020, version v01.",
    retrieved_at = as.POSIXct("2026-08-03 09:00:00", tz = "UTC")
  )

  text <- format(knbs_cite(meta))
  expect_match(text, "Fake Household Survey 2020", fixed = TRUE)
  expect_false(grepl("Ignored title", text, fixed = TRUE))
})

test_that("an unpunctuated source citation does not run into what follows", {
  # KeNADA states citations without a closing full stop, which ran straight
  # into the retrieval sentence.
  meta <- new_knbs_metadata(
    citation = "2015-2016 Kenya Integrated Household Budget Survey",
    source_url = "https://example.invalid/study"
  )

  text <- format(knbs_cite(meta))
  expect_match(text, "Budget Survey. Available at", fixed = TRUE)
  expect_false(grepl("Survey Available", text, fixed = TRUE))

  # A citation that is already punctuated is left alone.
  punctuated <- new_knbs_metadata(citation = "Producer. Title, 2020.")
  expect_false(grepl("2020\\.\\.", format(knbs_cite(punctuated))))
})

test_that("the retrieval date can be omitted", {
  meta <- new_knbs_metadata(title = "X", release_date = as.Date("2020-04-10"))
  expect_false(grepl("Retrieved", format(knbs_cite(meta, include_retrieval_date = FALSE))))
  expect_true(grepl("Retrieved", format(knbs_cite(meta))))
})

test_that("bibtex output is well formed", {
  meta <- new_knbs_metadata(
    title = "Fake consumer price index",
    resource_id = "FAKE-CPI",
    producer = "Offline test source",
    release_date = as.Date("2020-04-10"),
    source_url = "https://example.invalid/fake/FAKE-CPI"
  )

  lines <- format(knbs_cite(meta, style = "bibtex"))

  expect_match(lines[[1]], "^@misc\\{FAKECPI,")
  expect_true(any(grepl("title = \\{Fake consumer price index\\}", lines)))
  expect_true(any(grepl("author = \\{\\{Offline test source\\}\\}", lines)))
  expect_true(any(grepl("year = \\{2020\\}", lines)))
  expect_identical(lines[[length(lines)]], "}")
})

test_that("ris output carries the required tags", {
  meta <- new_knbs_metadata(
    title = "Fake consumer price index",
    resource_id = "FAKE-CPI",
    release_date = as.Date("2020-04-10")
  )

  lines <- format(knbs_cite(meta, style = "ris"))

  expect_identical(lines[[1]], "TY  - DATA")
  expect_true(any(startsWith(lines, "TI  - Fake consumer price index")))
  expect_true(any(startsWith(lines, "PY  - 2020")))
  expect_identical(lines[[length(lines)]], "ER  - ")
})

test_that("the year falls back to the reference period when there is no release", {
  meta <- new_knbs_metadata(title = "X", reference_period = "2018-01-01/2018-12-31")
  expect_true(any(grepl("year = \\{2018\\}", format(knbs_cite(meta, style = "bibtex")))))
})

test_that("unknown styles and uncitable objects are rejected", {
  meta <- new_knbs_metadata(title = "X")
  expect_error(knbs_cite(meta, style = "harvard"))
  expect_error(knbs_cite(tibble::tibble(a = 1)), class = "knbs_error_invalid_argument")
  expect_error(knbs_cite("FAKE-CPI"), class = "knbs_error_invalid_argument")
})

test_that("citations print as text", {
  citation <- knbs_cite(new_knbs_metadata(title = "X"))
  expect_s3_class(citation, "knbs_citation")
  expect_output(print(citation), "X")
})
