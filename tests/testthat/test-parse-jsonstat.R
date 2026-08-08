test_that("a dense JSON-stat dataset expands to one row per cell", {
  parsed <- parse_jsonstat(mini())
  table <- parsed$table

  expect_identical(nrow(table), 24L)
  expect_named(
    table,
    c("p18_vs1", "p18_vs1_label", "p11_vs1", "p11_vs1_label",
      "system_total", "system_total_label", "value")
  )
  # Row-major: the LAST dimension (territory) varies fastest.
  expect_identical(table$system_total[1:4], c("00", "01", "0101", "47"))
  expect_identical(table$p11_vs1[1:4], rep("T", 4))
  expect_identical(table$value[1:4], c(1000, 100, 10, 500))
  # Row 5 rolls territory back and advances sex.
  expect_identical(table$p11_vs1[[5]], "1")
  expect_identical(table$value[[5]], 600)
})

test_that("codes keep leading zeros and labels resolve", {
  table <- parse_jsonstat(mini())$table

  expect_type(table$system_total, "character")
  expect_true(all(c("00", "0101") %in% table$system_total))
  expect_identical(
    unique(table$system_total_label[table$system_total == "0101"]),
    "Changamwe"
  )
  expect_identical(unique(table$p11_vs1_label[table$p11_vs1 == "2"]), "Female")
})

test_that("a null value becomes NA, not zero and not an error", {
  table <- parse_jsonstat(mini())$table
  missing_cell <- table[table$p18_vs1 == "1" & table$p11_vs1 == "2" &
                          table$system_total == "0101", ]
  expect_identical(nrow(missing_cell), 1L)
  expect_true(is.na(missing_cell$value))
  expect_identical(sum(is.na(table$value)), 1L)
})

test_that("metadata carry label, source, updated and dimension labels", {
  meta <- parse_jsonstat(mini())$meta

  expect_identical(meta$label, "Census 2019 - Miniature fixture table")
  expect_identical(meta$source, "KNBS Population Census 2019")
  expect_identical(meta$updated, as.Date("2019-12-31"))
  expect_identical(
    unname(meta$dimension_labels),
    c("Marital Status", "Sex", "Territory")
  )
})

test_that("sparse values fill only their positions", {
  payload <- mini()
  payload$value <- list(`0` = 42, `23` = 7)
  table <- parse_jsonstat(payload)$table

  expect_identical(table$value[[1]], 42)
  expect_identical(table$value[[24]], 7)
  expect_identical(sum(!is.na(table$value)), 2L)
})

test_that("a status array aligns with the values", {
  payload <- mini()
  payload$status <- list(`2` = "p")
  table <- parse_jsonstat(payload)$table

  expect_identical(table$status[[3]], "p")
  expect_identical(sum(!is.na(table$status)), 1L)
})

test_that("a value count that does not fill the dimensions is refused", {
  payload <- mini()
  payload$value <- payload$value[1:10]
  expect_error(parse_jsonstat(payload), class = "knbs_error_validation_failed")
})

test_that("sparse keys outside the grid are refused", {
  payload <- mini()
  payload$value <- list(`99` = 1)
  expect_error(parse_jsonstat(payload), class = "knbs_error_schema_changed")
})

test_that("a payload that is not a dataset is a schema change", {
  expect_error(parse_jsonstat(list(version = "2.0", class = "collection")),
               class = "knbs_error_schema_changed")
  expect_error(parse_jsonstat(list(class = "dataset", id = list("a"))),
               class = "knbs_error_schema_changed")
})

test_that("a dimension described with the wrong cardinality is refused", {
  payload <- mini()
  payload$dimension$p11_vs1$category$index <- list(T = 0, `1` = 1)
  expect_error(parse_jsonstat(payload), class = "knbs_error_schema_changed")
})

test_that("an undescribed dimension is refused", {
  payload <- mini()
  payload$dimension$p18_vs1 <- NULL
  expect_error(parse_jsonstat(payload), class = "knbs_error_schema_changed")
})
