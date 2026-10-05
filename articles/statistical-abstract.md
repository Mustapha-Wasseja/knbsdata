# The Statistical Abstract as tidy tables

``` r
library(knbsdata)
```

The Statistical Abstract is KNBS’s annual compendium, and since the 2025
edition its chapter tables ship as Excel workbooks on the KNBS website —
eighteen chapters from Land & Water to Social & Economic Inclusion.
[`knbs_publications()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_publications.md)
finds those workbooks and
[`knbs_download_publication()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_publication.md)
fetches them verified; this vignette is about the step beyond: reading a
table *inside* a workbook as clean tidy observations.

## Curated, not guessed

A published spreadsheet is a print layout, not a dataset: title rows,
merged headers, section headings, footnote lines, dot leaders,
provisional marks. A universal spreadsheet-to-tidy converter would have
to guess its way through all of that, and a wrong guess produces
plausible, wrong data — the worst outcome this package knows.

So extraction here is **curated**. Each supported table has a
hand-verified recipe in the package’s registry: which sheet, which title
anchor, which rows are section headings, what the unit is, and several
reference values read from the workbook by hand at curation time. Every
extraction re-checks all of it. If KNBS reshuffles a sheet or revises a
pinned figure, you get `knbs_error_schema_changed` or
`knbs_error_validation_failed` with an explanation — never silently
re-arranged numbers.

Curated so far: **Chapter 2, National Accounts** — fifteen tables
covering the production accounts, GDP by activity at current and
constant prices, expenditure on GDP, capital formation, national income,
and saving. The registry is the extension point for further chapters.

## Listing and fetching

``` r
knbs_abstract_tables()
#> <knbs_catalogue>
#> Title: 2025 Statistical Abstract: curated tables
#> Rows: 15
#> Source: Kenya National Bureau of Statistics
#> 
#> # A tibble: 15 × 6
#>    table_id title                                   chapter unit  sheet workbook
#>    <chr>    <chr>                                   <chr>   <chr> <chr> <chr>   
#>  1 2.1      Annual Production Accounts by Industry… Chapte… KSh … Tabl… NA-Stat…
#>  2 2.2      Gross Domestic Product by Activity, 20… Chapte… KSh … Tabl… NA-Stat…
#>  3 2.3      Contribution to Gross Domestic Product… Chapte… per … Tabl… NA-Stat…
#>  4 2.4      Gross Domestic Product by Activity, 20… Chapte… KSh … Tabl… NA-Stat…
#>  5 2.5      Growth of Gross Domestic Product by Ac… Chapte… per … Tabl… NA-Stat…
#>  6 2.6a     Expenditure on the Gross Domestic Prod… Chapte… KSh … Tabl… NA-Stat…
#>  7 2.6b     Expenditure on the Gross Domestic Prod… Chapte… per … Tabl… NA-Stat…
#>  8 2.6c     Expenditure on the Gross Domestic Prod… Chapte… KSh … Tabl… NA-Stat…
#>  9 2.6d     Growth in Expenditure on the Gross Dom… Chapte… per … Tabl… NA-Stat…
#> 10 2.7a     Gross Fixed Capital Formation, 2015 - … Chapte… KSh … Tabl… NA-Stat…
#> 11 2.7b     Share of Gross Fixed Capital Formation… Chapte… per … Tabl… NA-Stat…
#> 12 2.7c     Gross Fixed Capital Formation, 2015 - … Chapte… KSh … Tabl… NA-Stat…
#> 13 2.7d     Growth in Gross Fixed Capital Formatio… Chapte… per … Tabl… NA-Stat…
#> 14 2.8      Gross Domestic Product and Gross Natio… Chapte… KSh … Tabl… NA-Stat…
#> 15 2.9      National Disposable Income and Saving,… Chapte… KSh … Tabl… NA-Stat…
```

``` r
gdp <- knbs_abstract_table("2.2")     # GDP by activity, current prices
gdp[gdp$industry == "GDP at market prices", c("period", "status", "value")]
#> # A tibble: 10 x 3
#>    period status         value
#>     <int> <chr>          <dbl>
#>  1   2015 NA           6884326
#>  2   2016 NA           7594064
#>  ...
#>  9   2023 revised     15033610
#> 10   2024 provisional 16224478
```

A table id works, and so does enough of a title:

``` r
saving <- knbs_abstract_table("disposable income")   # resolves to 2.9
```

## Reading the columns

- `period` is the integer year, and `status` carries the source’s own
  year flags: `"provisional"` (printed `*`), `"revised"` (printed `+`),
  `NA` for final years.
- The row dimension keeps its meaning as a named column: `industry` for
  the GDP tables, `expenditure_category`, `purpose` for capital
  formation.
- Sectioned tables carry their section as a second named column. In the
  production accounts (`"2.1"`), `industry` is the section and `measure`
  the row — output, intermediate consumption, value added, compensation.
- A row the source prints without figures — “Less: Subsidies” in the
  production accounts — is kept with `NA` values, because that is what
  the source shows.
- Units are stated in
  [`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md),
  not repeated on every row; a mixed-unit table (2.8 carries KSh million
  aggregates *and* per-capita KSh) says so there.

## Into the tidyverse

Every result is a tibble, so dplyr verbs work directly — and they keep
the provenance: filter it, rank it, transform it, and
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
still answers on the result. Aggregations and reshapes return plain
tibbles, because a derived table is your data, not the source’s.

``` r
library(dplyr)
library(tidyr)

# The largest industries in 2024, straight off the table
knbs_abstract_table("2.2") |>
  filter(period == 2024, industry != "GDP at market prices") |>
  slice_max(value, n = 5) |>
  select(industry, value, status)

# Recreate the printed-table look: industries by year, wide
knbs_abstract_table("2.4") |>
  filter(industry %in% c("Agriculture, forestry and fishing",
                         "Manufacturing", "GDP at market prices")) |>
  select(industry, period, value) |>
  pivot_wider(names_from = period, values_from = value)

# Sectioned tables group naturally
knbs_abstract_table("2.1") |>
  filter(measure == "Gross value added at basic prices", period == 2024) |>
  arrange(desc(value))

# And straight into ggplot2
library(ggplot2)
knbs_abstract_table("2.5") |>
  filter(industry == "GDP at market prices") |>
  ggplot(aes(period, value)) +
  geom_col() +
  labs(title = "Real GDP growth", y = "per cent")
```

To hand the data to something that dislikes subclasses, drop the wrapper
with
[`tibble::as_tibble()`](https://tibble.tidyverse.org/reference/as_tibble.html).

## Provenance travels

``` r
meta <- knbs_metadata(gdp)
meta$source_url   # the workbook on knbs.or.ke
meta$notes        # edition, sheet, workbook SHA-256, flag legend
knbs_cite(gdp)
```

The workbook itself is downloaded once through the package’s verify
layer — an HTML page arriving where a spreadsheet was expected is
refused — cached locally, and hashed; the SHA-256 in the notes says
exactly which file the numbers came from.

## What this is not

- **Not a universal parser.** Only curated tables extract; everything
  else in the workbooks remains available as verified downloads through
  [`knbs_download_publication()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_publication.md).
- **Not a modelling of the tables’ arithmetic.** Aggregate rows (“GDP at
  market prices”, “Total”) are rows like any other, as printed; nothing
  is summed, derived or reconciled for you.
- **Not immune to source revisions — by design.** A changed workbook
  stops extraction until the registry is re-verified against it. That is
  the honest failure mode.
