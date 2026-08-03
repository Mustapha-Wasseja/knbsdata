# `knbsdata`: Detailed Implementation Plan

## 1. Purpose of this document

This document is a build-ready specification for an R package called **`knbsdata`**.

The package should provide a consistent, reproducible, and user-friendly interface for discovering, retrieving, standardising, validating, documenting, and citing official data and statistical products published by the Kenya National Bureau of Statistics (KNBS).

The initial goal is not to ingest every KNBS product immediately. The goal is to create a strong technical foundation, implement a useful minimum viable product, and make future expansion straightforward.

Treat this document as:

1. A product specification.
2. A proposed package architecture.
3. A phased development plan.
4. A set of function contracts.
5. A testing and quality-assurance checklist.
6. A source of implementation tasks that can be converted into GitHub issues.

---

# 2. Package vision

## 2.1 One-sentence description

> `knbsdata` is an R client and standardisation layer for discovering, downloading, documenting, and analysing official KNBS statistics.

## 2.2 Intended users

The package should serve:

- KNBS analysts.
- Analysts in Kenyan ministries, departments, and agencies.
- County government analysts.
- Universities and research institutes.
- Development partners.
- Journalists and civil-society organisations.
- Data scientists building dashboards.
- Students using Kenyan official statistics.
- Reproducible-research workflows.
- Automated reporting pipelines.

## 2.3 Main user problem

KNBS statistics may be distributed across multiple systems and formats, including:

- Data catalogues.
- Indicator portals.
- Web pages.
- CSV files.
- Excel workbooks.
- Statistical publications.
- Survey metadata.
- Public-use microdata.
- PDF reports.
- Geographic reference tables.
- Classification documents.

Users often need to:

1. Find the correct dataset.
2. Understand its metadata and access status.
3. Download one or more files.
4. Read inconsistent file formats.
5. Rename and standardise variables.
6. reconcile geography and time-period fields.
7. preserve the correct source and release information.
8. cite the data correctly.
9. determine whether a newer release is available.
10. reproduce the same analysis later.

`knbsdata` should make these steps substantially easier.

---

# 3. Product principles

The implementation must follow these principles.

## 3.1 Official-source first

The package must prefer data obtained directly from KNBS-controlled or KNBS-authorised systems.

Do not silently substitute third-party mirrors.

If an unofficial mirror is ever supported, it must be:

- Clearly labelled.
- Disabled by default.
- Accompanied by provenance metadata.
- Used only when legally and institutionally appropriate.

## 3.2 Do not bypass access controls

The package must not circumvent:

- Registration requirements.
- Licence agreements.
- Approval processes.
- Authentication controls.
- Confidentiality restrictions.
- Terms of use.
- Rate limits.
- Robots exclusions.
- Human verification mechanisms.

A dataset that requires authorised access should be represented in the catalogue, but the package should not download it unless the user has completed the official access process and the source provides a legitimate machine-access method.

## 3.3 Metadata is part of the data

Every downloaded object should preserve, where available:

- Dataset title.
- Indicator title.
- Dataset identifier.
- Indicator identifier.
- Producing institution.
- Source system.
- Source URL.
- Release date.
- Reference period.
- Retrieval timestamp.
- Revision status.
- Version or edition.
- Unit of measure.
- Frequency.
- Geographic level.
- Classification used.
- Methodological notes.
- Access conditions.
- Citation.
- Licence.
- File checksum.
- Package version.

## 3.4 Reproducibility over convenience

The package should support both:

```r
knbs_get_indicator("CPI_ALL_ITEMS", release = "latest")
```

and, where source versions exist:

```r
knbs_get_indicator(
  "CPI_ALL_ITEMS",
  release = "2026-06-30"
)
```

The package should warn users when `"latest"` may produce different results later.

## 3.5 Stable public interface

Users should interact with a small, coherent set of exported functions.

Source-specific complexity should remain internal.

For example, users should not need to know whether an indicator came from:

- JSON.
- CSV.
- Excel.
- SDMX.
- A NADA catalogue.
- A CKAN-style portal.
- A static file repository.

## 3.6 Explicit failure

The package must fail clearly when:

- A source is unavailable.
- A file format has changed.
- Required metadata are missing.
- A filter is unsupported.
- Multiple indicators match an ambiguous query.
- Authentication is required.
- A dataset cannot legally be downloaded.
- A response schema is not recognised.

Do not return silently incomplete data.

## 3.7 Tidy output

Most functions should return:

- Tibbles for tabular results.
- `sf` objects for spatial boundaries.
- Structured S3 objects for metadata-rich downloads.
- Character vectors or lists only when clearly appropriate.

## 3.8 Minimal scraping

Prefer, in order:

1. Documented APIs.
2. Stable machine-readable endpoints.
3. Official CSV or Excel downloads.
4. Stable catalogue metadata endpoints.
5. Structured HTML.
6. HTML scraping only as a last resort.
7. PDF extraction only as an explicitly experimental feature.

---

# 4. Scope

## 4.1 Version 0.1.0 scope

The first release should focus on four capabilities:

### A. Survey catalogue discovery

- Search studies.
- Retrieve study metadata.
- Search variables.
- List files and documentation.
- Record access conditions.
- Download publicly available documentation.
- Download public-use microdata only when officially and directly supported.

### B. Publication discovery

- Search KNBS publications.
- Filter by topic, year, series, and publication type.
- Retrieve publication metadata.
- Download official files.
- Generate citations.

### C. Geographic and classification reference data

- County reference table.
- Geographic levels and codes where authoritative data are available.
- Classification metadata.
- Historical names and code concordances where they can be verified.

### D. Limited aggregate indicators

Start with a small number of high-value indicator families, for example:

- Consumer prices.
- National accounts.
- Population.
- Labour market.
- Poverty.
- External trade.

The exact first indicator families should be selected only after a source-discovery audit.

## 4.2 Out of scope for version 0.1.0

Do not initially attempt:

- Universal extraction from arbitrary PDFs.
- Automatic interpretation of all KNBS Excel workbooks.
- Bypassing licensed-data access processes.
- A full Shiny application.
- A Python client.
- A central hosted KNBS API unless KNBS formally supports it.
- Small-area estimation.
- Survey weighting and variance estimation.
- Disclosure-control processing.
- Automated statistical imputation.
- Reproduction of official estimates from microdata.
- Unverified geographic boundary distribution.
- An internal KNBS data warehouse.

These may be future extensions or separate packages.

---

# 5. Proposed user experience

## 5.1 Package installation

Development installation:

```r
pak::pak("OWNER/knbsdata")
```

Eventually, if published on CRAN:

```r
install.packages("knbsdata")
```

Load the package:

```r
library(knbsdata)
```

## 5.2 Search across supported resources

```r
results <- knbs_search("consumer price index")
results
```

Expected columns:

```text
resource_id
resource_type
title
description
topic
frequency
geography
reference_start
reference_end
release_date
access
source_id
source_url
```

## 5.3 List indicators

```r
indicators <- knbs_indicators(
  topic = "prices",
  frequency = "monthly"
)
```

## 5.4 Retrieve an indicator

```r
cpi <- knbs_get_indicator(
  indicator = "CPI_ALL_ITEMS",
  start = "2020-01",
  end = "2026-06"
)
```

Expected data columns:

```text
indicator_id
indicator_name
period
value
unit
frequency
geo_code
geo_name
geo_level
sex
age_group
category
status
release_date
```

Optional dimensions should be present only when relevant, or represented consistently through a dimensions column or long schema.

## 5.5 Retrieve several indicators

```r
macro <- knbs_get_indicator(
  indicator = c(
    "GDP_REAL",
    "CPI_ALL_ITEMS",
    "UNEMPLOYMENT_RATE"
  ),
  start = 2015
)
```

## 5.6 Search survey studies

```r
studies <- knbs_search_surveys("household budget")
```

Expected columns:

```text
survey_id
title
acronym
reference_years
producer
geographic_coverage
unit_of_analysis
access_type
catalogue_url
metadata_updated
```

## 5.7 Retrieve study metadata

```r
metadata <- knbs_survey_metadata("KIHBS-2015")
print(metadata)
```

## 5.8 Search variables within a survey

```r
variables <- knbs_variables(
  survey = "KIHBS-2015",
  search = "consumption expenditure"
)
```

Expected columns:

```text
survey_id
file_id
file_name
variable_name
variable_label
question_text
universe
value_labels
concept
metadata_url
```

## 5.9 List survey files

```r
files <- knbs_survey_files("KIHBS-2015")
```

Expected columns:

```text
file_id
file_name
file_type
format
size
access_type
downloadable
download_url
checksum
```

## 5.10 Download public-use files

```r
paths <- knbs_download_microdata(
  survey = "KIHBS-2015",
  files = c("household", "consumption"),
  destination = "data/kihbs"
)
```

Expected behaviour:

- Confirm that files are marked public.
- Refuse downloads that require unauthorised access.
- Preserve original file names.
- Calculate checksums.
- Write a manifest.
- Return local file paths.
- Record retrieval information.

## 5.11 Search publications

```r
pubs <- knbs_publications(
  topic = "economic survey",
  year = 2026
)
```

## 5.12 Download a publication

```r
path <- knbs_download_publication(
  publication_id = "ECONOMIC_SURVEY_2026",
  destination = "data/publications"
)
```

## 5.13 Retrieve geography reference data

```r
counties <- knbs_geographies(
  level = "county",
  vintage = 2019
)
```

## 5.14 Retrieve boundaries

Only implement when official, reusable, and legally distributable files are identified.

```r
county_sf <- knbs_boundaries(
  level = "county",
  vintage = 2019
)
```

Return an `sf` object with:

```text
geo_code
geo_name
geo_level
vintage
geometry
source
```

## 5.15 Produce a citation

```r
knbs_cite(cpi)
```

Example:

```text
Kenya National Bureau of Statistics. Consumer Price Index,
release dated 30 June 2026. Retrieved 3 August 2026 using
knbsdata version 0.1.0.
```

## 5.16 Inspect metadata

```r
knbs_metadata(cpi)
```

## 5.17 Inspect package-supported sources

```r
knbs_sources()
```

## 5.18 Test source health

```r
knbs_status()
```

---

# 6. Proposed package architecture

## 6.1 High-level architecture

```text
User-facing functions
        |
        v
Argument validation and query normalisation
        |
        v
Resource registry and source selection
        |
        v
Source-specific adapter
        |
        v
HTTP/file retrieval layer
        |
        v
Parser
        |
        v
Schema mapping and standardisation
        |
        v
Validation
        |
        v
Metadata attachment
        |
        v
Tibble / sf / knbs_* S3 object
```

## 6.2 Core architectural layers

### Layer 1: Public interface

Exported functions such as:

- `knbs_search()`
- `knbs_get_indicator()`
- `knbs_search_surveys()`
- `knbs_variables()`
- `knbs_publications()`
- `knbs_geographies()`
- `knbs_cite()`

### Layer 2: Query objects

Convert user arguments into internal query objects.

Example internal class:

```r
new_knbs_query <- function(
  resource_type,
  resource_id = NULL,
  filters = list(),
  source = NULL,
  release = "latest",
  language = "en"
) {
  structure(
    list(
      resource_type = resource_type,
      resource_id = resource_id,
      filters = filters,
      source = source,
      release = release,
      language = language
    ),
    class = "knbs_query"
  )
}
```

### Layer 3: Source registry

A registry describes each supported source.

Each source entry should specify:

- Source ID.
- Name.
- Owner.
- Base URL.
- Source type.
- Supported operations.
- Authentication requirements.
- Rate-limit policy.
- Data formats.
- Adapter function.
- Stability level.
- Last verified date.
- Terms-of-use URL.
- Notes.

### Layer 4: Source adapters

Each source adapter implements a standard interface.

Suggested internal generic operations:

```r
source_search(source, query)
source_list(source, resource_type, filters)
source_fetch(source, resource_id, filters)
source_metadata(source, resource_id)
source_files(source, resource_id)
source_download(source, resource_id, destination)
source_health(source)
```

### Layer 5: Retrieval

Use a modern HTTP client, preferably `httr2`.

Responsibilities:

- Build requests.
- Add user agent.
- Apply timeouts.
- Respect redirects.
- Handle retries.
- Implement backoff.
- Validate content type.
- Capture status codes.
- Cache raw responses when appropriate.
- Avoid logging secrets.
- Provide informative errors.

### Layer 6: Parsing

Parsers should be separate from network retrieval.

Potential parsers:

- JSON.
- CSV.
- TSV.
- Excel.
- XML.
- SDMX.
- NADA metadata.
- HTML tables.
- ZIP archives.
- Shapefiles or GeoPackages.
- PDF metadata only.

### Layer 7: Standardisation

Convert source-specific fields into canonical schemas.

### Layer 8: Validation

Validate:

- Required columns.
- Column types.
- Unique identifiers.
- Duplicate rows.
- Missing keys.
- Date formats.
- Units.
- Geographic codes.
- Dimension consistency.
- Unexpected schema changes.

### Layer 9: Metadata and classes

Attach metadata through an S3 class rather than using undocumented arbitrary attributes only.

Proposed classes:

- `knbs_data`
- `knbs_indicator`
- `knbs_catalogue`
- `knbs_survey`
- `knbs_publication`
- `knbs_geography`
- `knbs_metadata`

---

# 7. Recommended repository structure

```text
knbsdata/
├── .Rbuildignore
├── .gitignore
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   ├── data_source_change.yml
│   │   └── feature_request.yml
│   └── workflows/
│       ├── R-CMD-check.yaml
│       ├── test-sources.yaml
│       ├── pkgdown.yaml
│       └── lint.yaml
├── DESCRIPTION
├── LICENSE
├── LICENSE.md
├── NAMESPACE
├── NEWS.md
├── README.Rmd
├── README.md
├── _pkgdown.yml
├── codecov.yml
├── cran-comments.md
├── data-raw/
│   ├── build_geographies.R
│   ├── build_indicator_registry.R
│   ├── build_source_registry.R
│   ├── build_topic_dictionary.R
│   └── README.md
├── dev/
│   ├── source-discovery/
│   ├── fixtures/
│   └── notebooks/
├── inst/
│   ├── extdata/
│   │   ├── source-registry.yml
│   │   ├── indicator-registry.yml
│   │   ├── schemas/
│   │   └── examples/
│   └── CITATION
├── man/
├── R/
│   ├── knbs-package.R
│   ├── search.R
│   ├── indicators.R
│   ├── surveys.R
│   ├── publications.R
│   ├── geographies.R
│   ├── classifications.R
│   ├── metadata.R
│   ├── citations.R
│   ├── cache.R
│   ├── status.R
│   ├── options.R
│   ├── print.R
│   ├── conditions.R
│   ├── query.R
│   ├── registry.R
│   ├── source-generic.R
│   ├── adapter-kenada.R
│   ├── adapter-publications.R
│   ├── adapter-indicators.R
│   ├── adapter-static-files.R
│   ├── http.R
│   ├── parse-json.R
│   ├── parse-csv.R
│   ├── parse-excel.R
│   ├── parse-html.R
│   ├── parse-nada.R
│   ├── parse-sdmx.R
│   ├── standardise-indicators.R
│   ├── standardise-surveys.R
│   ├── standardise-publications.R
│   ├── validate.R
│   ├── utils.R
│   └── zzz.R
├── tests/
│   ├── testthat/
│   │   ├── fixtures/
│   │   ├── helper-fixtures.R
│   │   ├── helper-mocks.R
│   │   ├── test-search.R
│   │   ├── test-indicators.R
│   │   ├── test-surveys.R
│   │   ├── test-publications.R
│   │   ├── test-geographies.R
│   │   ├── test-metadata.R
│   │   ├── test-citations.R
│   │   ├── test-cache.R
│   │   ├── test-http.R
│   │   ├── test-registry.R
│   │   └── test-validation.R
│   └── testthat.R
└── vignettes/
    ├── getting-started.Rmd
    ├── survey-catalogue.Rmd
    ├── indicator-data.Rmd
    ├── reproducible-citations.Rmd
    ├── county-data.Rmd
    └── adding-a-source-adapter.Rmd
```

---

# 8. Package dependencies

## 8.1 Imports

Prefer a restrained dependency set.

Suggested imports:

```text
cli
curl
dplyr
httr2
jsonlite
lifecycle
purrr
readr
rlang
tibble
tidyr
vctrs
withr
yaml
```

Conditional imports depending on implemented features:

```text
readxl
xml2
rvest
sf
archive
digest
clock
stringr
```

## 8.2 Suggests

```text
arrow
covr
httptest2
knitr
mockery
pkgdown
rmarkdown
roxygen2
spelling
testthat
vcr
waldo
webfakes
```

## 8.3 Dependency principles

- Do not import the entire tidyverse.
- Use `httr2` instead of mixing several HTTP libraries.
- Use `vctrs` for stable custom classes.
- Use `cli` for messages, warnings, and errors.
- Use `rlang` conditions for structured errors.
- Keep `sf` optional until boundary support is implemented.
- Avoid Java-dependent packages.
- Avoid requiring a browser automation tool.
- Avoid system dependencies in the core package where possible.

---

# 9. Canonical schemas

## 9.1 Indicator catalogue schema

```text
indicator_id       character
indicator_name     character
description        character
topic              character
subtopic           character
unit               character
frequency          character
geo_levels         list-column
dimensions         list-column
reference_start    date or character
reference_end      date or character
latest_release     date
source_id          character
source_url         character
status             character
notes              character
```

## 9.2 Indicator observation schema

Required fields:

```text
indicator_id       character
indicator_name     character
period             date or year-quarter/year-month class
value              numeric
unit               character
frequency          character
source_id          character
release_date       date
```

Recommended dimension fields:

```text
geo_code           character
geo_name           character
geo_level          character
sex                character
age_group          character
residence          character
industry           character
occupation         character
category           character
measure            character
price_basis        character
seasonal_adjustment character
status             character
```

Do not force all dimensions into every output when doing so creates dozens of entirely empty columns. Two acceptable strategies are:

### Strategy A: Stable wide schema

Always return all standard dimension columns.

Advantages:

- Predictable.
- Easy for users.
- Easier joins.

Disadvantages:

- Many empty columns.

### Strategy B: Core schema plus dynamic dimensions

Return core columns and source-specific dimensions.

Advantages:

- Cleaner.
- Flexible.

Disadvantages:

- Less predictable.

Recommended approach:

- Use stable core columns.
- Include recognised dimensions when present.
- Place uncommon dimensions in a `dimensions` list-column only when necessary.
- Document this clearly.

## 9.3 Survey catalogue schema

```text
survey_id
title
acronym
series
reference_years
country
geographic_coverage
producer
sponsor
collection_start
collection_end
unit_of_analysis
sampling_description
access_type
licence
catalogue_url
metadata_updated
source_id
```

## 9.4 Variable catalogue schema

```text
survey_id
file_id
file_name
variable_name
variable_label
question_text
universe
concept
value_labels
missing_values
variable_type
source_url
```

## 9.5 Publication schema

```text
publication_id
title
series
topic
edition
year
release_date
description
language
format
file_size
download_url
landing_page
source_id
checksum
access
```

## 9.6 Geography schema

```text
geo_code
geo_name
geo_level
parent_code
parent_name
vintage
valid_from
valid_to
status
alternative_names
source_id
source_url
```

## 9.7 Classification schema

```text
classification_id
classification_name
version
level
code
label
parent_code
valid_from
valid_to
source_id
source_url
```

## 9.8 Metadata schema

Use an S3 object backed by a named list:

```r
list(
  title = NULL,
  resource_id = NULL,
  resource_type = NULL,
  source_id = NULL,
  source_name = NULL,
  source_url = NULL,
  producer = "Kenya National Bureau of Statistics",
  release_date = NULL,
  reference_period = NULL,
  retrieved_at = NULL,
  version = NULL,
  revision_status = NULL,
  unit = NULL,
  frequency = NULL,
  geographic_level = NULL,
  licence = NULL,
  access = NULL,
  citation = NULL,
  checksum = NULL,
  notes = NULL,
  raw = NULL
)
```

---

# 10. S3 object design

## 10.1 `knbs_data`

A tibble subclass for downloaded data.

```r
new_knbs_data <- function(x, metadata) {
  stopifnot(tibble::is_tibble(x))
  structure(
    x,
    knbs_metadata = metadata,
    class = c("knbs_data", class(x))
  )
}
```

## 10.2 Required methods

Implement:

```r
print.knbs_data()
summary.knbs_data()
knbs_metadata.knbs_data()
knbs_cite.knbs_data()
as_tibble.knbs_data()
```

The print method should show a concise header:

```text
<knbs_indicator>
Indicator: Consumer Price Index
Rows: 78
Period: 2020-01 to 2026-06
Release: 2026-06-30
Source: Kenya National Bureau of Statistics
```

Then print the tibble normally.

## 10.3 Restoration

Because tibbles may lose custom attributes after some operations, decide how metadata should behave.

Possible options:

1. Accept that metadata may be dropped after unsupported transformations.
2. Implement `vctrs` restoration methods.
3. Provide `knbs_metadata()` before transformation.
4. Offer `knbs_retain_metadata()` for explicit use.

Recommended:

- Implement `vec_restore.knbs_data()`.
- Preserve metadata for common dplyr operations when safe.
- Warn in documentation that aggregating or combining objects may invalidate inherited metadata.
- Avoid pretending that a transformed object retains an unchanged official identity.

---

# 11. Function specifications

# 11.1 `knbs_search()`

## Purpose

Search across all supported KNBS resources.

## Signature

```r
knbs_search(
  query,
  type = c("all", "indicator", "survey", "publication", "geography", "classification"),
  topic = NULL,
  year = NULL,
  source = NULL,
  limit = 50,
  exact = FALSE
)
```

## Behaviour

- Validate that `query` is a non-empty character string.
- Search one or more supported catalogues.
- Standardise results into one schema.
- Rank results.
- Preserve source-specific resource identifiers.
- Return a `knbs_catalogue` tibble.
- Do not download full datasets.

## Search ranking

Suggested ranking components:

- Exact title match.
- Identifier match.
- Title token match.
- Description token match.
- Topic match.
- Recency.
- Source confidence.
- Official release status.

## Errors

- `knbs_error_invalid_query`
- `knbs_error_source_unavailable`

## Warnings

- Partial source failure should produce a warning and return results from working sources.
- If every source fails, raise an error.

---

# 11.2 `knbs_sources()`

## Signature

```r
knbs_sources(
  operation = NULL,
  status = NULL
)
```

## Output

```text
source_id
source_name
source_type
operations
stability
authentication
last_verified
base_url
```

---

# 11.3 `knbs_indicators()`

## Signature

```r
knbs_indicators(
  topic = NULL,
  frequency = NULL,
  geography = NULL,
  search = NULL,
  source = NULL,
  status = "active"
)
```

## Behaviour

- Return indicator definitions, not observations.
- Support vector filters.
- Standardise frequency labels.
- Include available dimensions.

---

# 11.4 `knbs_get_indicator()`

## Signature

```r
knbs_get_indicator(
  indicator,
  start = NULL,
  end = NULL,
  geography = NULL,
  geo_code = NULL,
  sex = NULL,
  age_group = NULL,
  category = NULL,
  release = "latest",
  source = NULL,
  tidy = TRUE,
  cache = knbs_option("cache"),
  refresh = FALSE
)
```

## Behaviour

1. Resolve indicator ID.
2. Reject ambiguous names.
3. Determine source.
4. Validate supported filters.
5. Query or download raw data.
6. Parse.
7. Standardise.
8. Filter.
9. Validate.
10. Attach metadata.
11. Cache.
12. Return `knbs_indicator`.

## Ambiguous names

If user supplies:

```r
knbs_get_indicator("unemployment")
```

and multiple indicators match, return an error listing likely matches and instruct the user to use an exact ID.

## Date handling

Support:

- Annual values such as `2024`.
- Quarterly values such as `"2024-Q2"`.
- Monthly values such as `"2024-06"`.
- Daily dates if any source supports them.

Internally, consider `clock` year-month and year-quarter types, but avoid making outputs difficult for ordinary users. A practical first release may use:

- Integer for annual.
- `Date` set to period start for monthly and quarterly.
- Separate `period_label`.
- Explicit `frequency`.

Document the convention.

## Duplicate observations

The key should normally be:

```text
indicator_id
period
geo_code
all dimension columns
release_date or vintage
```

Raise an error if duplicate keys remain after standardisation, unless the source explicitly defines multiple statuses or units.

---

# 11.5 `knbs_search_surveys()`

## Signature

```r
knbs_search_surveys(
  query = NULL,
  year = NULL,
  producer = NULL,
  access = NULL,
  collection = NULL,
  limit = 100
)
```

## Behaviour

- Search study-level metadata.
- Return one row per survey or study edition.
- Keep catalogue-specific IDs.
- Distinguish survey series from individual rounds.

---

# 11.6 `knbs_survey_metadata()`

## Signature

```r
knbs_survey_metadata(
  survey,
  include = c(
    "overview",
    "scope",
    "sampling",
    "collection",
    "processing",
    "access",
    "citation"
  )
)
```

## Return value

A `knbs_survey` metadata object.

## Print method

Show:

- Title.
- Survey ID.
- Reference period.
- Producer.
- Geographic coverage.
- Unit of analysis.
- Access type.
- Catalogue URL.

---

# 11.7 `knbs_variables()`

## Signature

```r
knbs_variables(
  survey,
  search = NULL,
  file = NULL,
  concept = NULL,
  name = NULL,
  limit = Inf
)
```

## Behaviour

- Retrieve variable metadata only.
- Search variable names, labels, question text, and concepts.
- Support exact name matching.
- Preserve file membership.
- Avoid downloading microdata unless explicitly requested.

## Performance

Large surveys may have thousands of variables.

Implement:

- Pagination where supported.
- Local cached metadata indexes.
- Deferred retrieval if possible.
- Optional maximum results.

---

# 11.8 `knbs_survey_files()`

## Signature

```r
knbs_survey_files(
  survey,
  type = NULL,
  access = NULL
)
```

## File types

Potential values:

- Microdata.
- Questionnaire.
- Codebook.
- Report.
- Technical document.
- Sampling document.
- Data dictionary.
- Syntax.
- Other.

---

# 11.9 `knbs_download_microdata()`

## Signature

```r
knbs_download_microdata(
  survey,
  files = NULL,
  destination = ".",
  overwrite = FALSE,
  verify = TRUE,
  manifest = TRUE,
  quiet = FALSE
)
```

## Strict rules

- Download only files marked as legitimately downloadable.
- Require explicit destination.
- Never embed credentials in logs.
- Never automate acceptance of legal terms.
- Never bypass approval workflows.
- Verify content type and file extension.
- Calculate SHA-256 checksums.
- Preserve a manifest.

## Manifest structure

Write a CSV or JSON file containing:

```text
survey_id
file_id
original_name
local_path
download_url
downloaded_at
size_bytes
sha256
package_version
source_id
```

---

# 11.10 `knbs_publications()`

## Signature

```r
knbs_publications(
  query = NULL,
  topic = NULL,
  series = NULL,
  year = NULL,
  format = NULL,
  language = NULL,
  limit = 100
)
```

## Behaviour

- Search metadata.
- Do not parse the publication by default.
- Return latest and historical editions where available.

---

# 11.11 `knbs_download_publication()`

## Signature

```r
knbs_download_publication(
  publication_id,
  destination = ".",
  overwrite = FALSE,
  verify = TRUE
)
```

## Behaviour

- Preserve official filename.
- Add a sidecar metadata file, for example:

```text
Economic_Survey_2026.pdf
Economic_Survey_2026.metadata.json
```

---

# 11.12 `knbs_get_table()`

This should be experimental in early versions.

## Signature

```r
knbs_get_table(
  publication,
  table,
  sheet = NULL,
  range = NULL,
  clean = TRUE,
  source = NULL
)
```

## Constraints

Only support tables for which:

- A structured Excel, CSV, or API source exists.
- The table location is registered.
- The parser is tested.
- Column meanings are documented.

Do not advertise universal PDF extraction.

Mark with lifecycle status:

```r
lifecycle::badge("experimental")
```

---

# 11.13 `knbs_geographies()`

## Signature

```r
knbs_geographies(
  level = NULL,
  vintage = NULL,
  parent = NULL,
  status = "active"
)
```

## Behaviour

- Return official reference codes only.
- Distinguish administrative, electoral, census, and statistical geographies.
- Do not merge incompatible geography systems silently.
- Require a vintage where ambiguity exists.

---

# 11.14 `knbs_boundaries()`

## Signature

```r
knbs_boundaries(
  level,
  vintage,
  resolution = c("standard", "simplified"),
  crs = 4326,
  cache = TRUE,
  refresh = FALSE
)
```

## Constraints

Implement only after confirming:

- Official source.
- Reuse licence.
- File stability.
- Geographic vintage.
- Projection.
- Geometry validity.

## Validation

- `sf::st_is_valid()`
- Unique geographic codes.
- Expected feature count.
- No unexpected empty geometries.
- Correct CRS.
- Clear boundary vintage.

---

# 11.15 `knbs_classifications()`

## Signature

```r
knbs_classifications(
  classification = NULL,
  version = NULL,
  level = NULL,
  search = NULL
)
```

Potential classifications:

- Industry.
- Occupation.
- Product.
- Consumption.
- Education.
- Administrative area.
- Establishment activity.

Do not infer unsupported mappings.

---

# 11.16 `knbs_metadata()`

## Generic

```r
knbs_metadata(x, ...)
```

Methods:

```r
knbs_metadata.knbs_data()
knbs_metadata.knbs_survey()
knbs_metadata.knbs_publication()
knbs_metadata.character()
```

For a resource ID, retrieve metadata from the appropriate catalogue.

---

# 11.17 `knbs_cite()`

## Signature

```r
knbs_cite(
  x,
  style = c("plain", "bibtex", "ris"),
  include_retrieval_date = TRUE
)
```

## Return

Use a dedicated class such as `knbs_citation`.

## Citation inputs

Prioritise:

1. Source-provided citation.
2. Dataset title.
3. Producing institution.
4. Edition or release.
5. Reference year.
6. Persistent identifier.
7. Source URL.
8. Retrieval date.
9. Package version.

---

# 11.18 `knbs_status()`

## Signature

```r
knbs_status(
  source = NULL,
  live = interactive(),
  timeout = 10
)
```

## Output

```text
source_id
operation
status
http_status
response_time_ms
checked_at
message
```

## Important

CRAN tests must not depend on live network access.

`knbs_status()` may perform live checks only when explicitly called.

---

# 11.19 Cache functions

```r
knbs_cache_dir()
knbs_cache_info()
knbs_cache_clear()
knbs_cache_prune()
knbs_cache_path()
```

## Default cache

Use `tools::R_user_dir("knbsdata", "cache")`.

## Cache keys

Include:

- Source ID.
- Operation.
- Resource ID.
- Normalised query.
- Release.
- Parser version.
- Schema version.

## Cache invalidation

Use:

- Expiry time.
- ETag.
- Last-Modified.
- Release identifier.
- Checksum.
- Manual refresh.

---

# 11.20 Package options

```r
knbs_options(
  cache = TRUE,
  cache_dir = NULL,
  timeout = 30,
  retries = 3,
  user_agent = NULL,
  quiet = FALSE
)
```

Prefer ordinary R options internally:

```text
knbsdata.cache
knbsdata.cache_dir
knbsdata.timeout
knbsdata.retries
knbsdata.user_agent
knbsdata.quiet
```

---

# 12. Source registry design

## 12.1 YAML example

```yaml
schema_version: 1

sources:
  - source_id: kenada
    source_name: Kenya National Data Archive
    owner: Kenya National Bureau of Statistics
    source_type: survey_catalogue
    base_url: PLACEHOLDER_TO_VERIFY
    adapter: nada
    operations:
      - search_surveys
      - survey_metadata
      - variables
      - files
      - download_public_files
    authentication: source_defined
    formats:
      - html
      - xml
      - json
      - zip
    stability: beta
    last_verified: null
    terms_url: null
    notes:
      - Do not assume public microdata access.
      - Inspect the catalogue and documented endpoints during discovery.

  - source_id: knbs_publications
    source_name: KNBS Publications
    owner: Kenya National Bureau of Statistics
    source_type: publication_catalogue
    base_url: PLACEHOLDER_TO_VERIFY
    adapter: publications
    operations:
      - search_publications
      - publication_metadata
      - download_publication
    authentication: none
    formats:
      - html
      - pdf
      - xlsx
      - csv
    stability: experimental
    last_verified: null

  - source_id: knbs_indicators
    source_name: KNBS Aggregate Indicators
    owner: Kenya National Bureau of Statistics
    source_type: indicator_portal
    base_url: PLACEHOLDER_TO_VERIFY
    adapter: indicators
    operations:
      - list_indicators
      - get_indicator
      - indicator_metadata
    authentication: none
    formats:
      - json
      - csv
      - xlsx
      - sdmx
    stability: discovery
    last_verified: null
```

## 12.2 Registry validation

On package build or test:

- Every source ID must be unique.
- Every adapter must exist.
- Every operation must be recognised.
- URLs must use HTTPS unless unavoidable.
- Stability must be one of:
  - `discovery`
  - `experimental`
  - `beta`
  - `stable`
  - `deprecated`
- Last verified must be a valid date or null.
- Authentication type must be valid.

---

# 13. Indicator registry design

## 13.1 Purpose

Stable package-level indicator IDs should shield users from source naming changes.

## 13.2 Example

```yaml
schema_version: 1

indicators:
  - indicator_id: CPI_ALL_ITEMS
    indicator_name: Consumer Price Index, all items
    topic: prices
    unit: index
    frequency: monthly
    source_id: knbs_indicators
    source_indicator_id: PLACEHOLDER
    dimensions:
      - geography
      - category
    default_geography: national
    status: active
    notes:
      - Base year must be read from source metadata.
      - Do not hard-code a base year in the package.

  - indicator_id: CPI_INFLATION_YOY
    indicator_name: Consumer price inflation, year-on-year
    topic: prices
    unit: percent
    frequency: monthly
    source_id: knbs_indicators
    source_indicator_id: PLACEHOLDER
    status: active
```

## 13.3 Stable ID rules

- Uppercase snake case.
- Semantic rather than source-specific.
- Never encode a base year unless the series is genuinely fixed to it.
- Never reuse retired IDs.
- Use aliases for old names.
- Document changes in `NEWS.md`.

---

# 14. Source discovery phase

Before writing production adapters, create a structured discovery process.

## 14.1 Deliverable

Create:

```text
dev/source-discovery/source-audit.md
```

## 14.2 Audit each source

For every candidate source, document:

- Source name.
- Official owner.
- Landing page.
- Data catalogue type.
- Search capability.
- Machine-readable endpoints.
- API documentation.
- Network requests triggered by the site.
- Response formats.
- Pagination.
- Filters.
- Authentication.
- Download workflow.
- Terms of use.
- Rate limits.
- Robots policy.
- Persistent IDs.
- Version fields.
- Release date fields.
- Geography fields.
- Metadata quality.
- Expected stability.
- Risks.
- Recommendation.

## 14.3 Discovery rules

- Use public, documented endpoints where possible.
- Do not hard-code endpoints discovered from temporary session tokens.
- Do not commit credentials or cookies.
- Do not reverse-engineer protected systems.
- Do not automate restricted downloads.
- Record reproducible `curl` examples only for public endpoints.
- Store small, non-sensitive response fixtures for tests.
- Redact personal or authentication information.

## 14.4 Initial decision gate

At the end of discovery, classify each source:

### Tier 1: Production-ready

- Documented or stable machine endpoint.
- Clear access conditions.
- Predictable schema.
- Legal to access programmatically.

### Tier 2: Supported with caution

- Undocumented but stable public endpoint.
- Structured source.
- Tests and monitoring required.

### Tier 3: Metadata only

- Searchable but downloads are restricted.
- Package can expose metadata and links.

### Tier 4: Do not automate

- CAPTCHA.
- Interactive licence acceptance.
- Unclear legal status.
- Session-bound private API.
- Highly unstable HTML.
- Sensitive content.

---

# 15. HTTP implementation

## 15.1 User agent

Use a transparent user agent:

```text
knbsdata/{version} ({project URL}; contact: package maintainer)
```

## 15.2 Request builder

Create an internal helper:

```r
knbs_request <- function(url, source_id) {
  httr2::request(url) |>
    httr2::req_user_agent(knbs_user_agent()) |>
    httr2::req_timeout(knbs_option("timeout")) |>
    httr2::req_retry(
      max_tries = knbs_option("retries"),
      backoff = ~ min(60, 2 ^ .x)
    )
}
```

## 15.3 Status handling

Handle:

- `200`: success.
- `204`: no content.
- `301/302`: redirect.
- `304`: cached response valid.
- `400`: invalid request.
- `401`: authentication required.
- `403`: access prohibited.
- `404`: resource not found.
- `409`: conflict.
- `429`: rate limit.
- `500+`: source failure.

## 15.4 Retry policy

Retry only:

- Network failures.
- Timeouts.
- `429`.
- Selected `500`, `502`, `503`, and `504` responses.

Do not retry:

- `400`.
- `401`.
- `403`.
- `404`.
- Parsing errors without refreshing source knowledge.

## 15.5 Rate limiting

Implement source-specific minimum intervals when necessary.

A simple approach:

- Store last-request timestamp per source in session state.
- Sleep only when required.
- Honour `Retry-After`.
- Avoid parallel requests by default.

## 15.6 Download safety

For file downloads:

- Stream to a temporary file.
- Verify success.
- Validate file type.
- Calculate checksum.
- Move atomically to destination.
- Clean temporary files on failure.

---

# 16. Parsing strategy

## 16.1 JSON

Use:

```r
jsonlite::fromJSON(..., simplifyVector = FALSE)
```

Then parse explicitly rather than trusting automatic simplification.

## 16.2 CSV

Use `readr::read_csv()` with:

- Explicit column specifications for registered datasets.
- UTF-8 handling.
- Locale controls.
- Preservation of leading zeros in codes.
- NA strings configured per source.

## 16.3 Excel

Use `readxl`.

Do not guess blindly across workbooks.

Create registered Excel parsers with:

- Expected sheet.
- Header row.
- Column ranges.
- Footnote handling.
- Merged-cell handling.
- Unit extraction.
- Source edition.

Example parser specification:

```yaml
publication_id: ECONOMIC_SURVEY_2026
table_id: EMPLOYMENT_INDUSTRY
sheet: Employment
header_row: 6
data_start_row: 7
expected_columns:
  - industry
  - 2022
  - 2023
  - 2024
unit: thousands
```

## 16.4 HTML

Use `rvest` only when:

- The page is public.
- There is no better machine-readable endpoint.
- Structure is stable enough to test.
- Terms permit access.

Select by semantic identifiers rather than brittle absolute XPath where possible.

## 16.5 XML and SDMX

If a source provides SDMX:

- Use an SDMX parser or `rsdmx` as a suggested dependency.
- Map dimensions into the canonical schema.
- Preserve codelist metadata.
- Preserve observation status.

## 16.6 ZIP archives

- Inspect file names before extraction.
- Prevent path traversal.
- Extract only expected files.
- Preserve checksums for the archive and extracted files.

## 16.7 PDFs

Version 0.1.0 should:

- Catalogue PDFs.
- Download PDFs.
- Preserve metadata.
- Avoid pretending to produce guaranteed tables.

Any PDF table extraction must be:

- Experimental.
- Limited to registered publications and tables.
- Covered by fixture tests.
- Validated against known values.

---

# 17. Standardisation rules

## 17.1 Column names

Use lowercase snake case.

## 17.2 Geographic codes

Always read as character.

Never allow:

```text
001 -> 1
```

## 17.3 Missing values

Convert source-specific missing-value codes to `NA`, but preserve status in a separate field when meaningful.

Examples requiring careful handling:

- Suppressed.
- Not available.
- Not applicable.
- Provisional.
- Revised.
- Confidential.
- Negligible.
- Zero.

Do not convert all non-numeric symbols to plain `NA` without preserving meaning.

Suggested fields:

```text
value
observation_status
source_value
```

## 17.4 Units

Standardise common units:

```text
count
persons
households
percent
index
kenyan_shillings
million_kenyan_shillings
billion_kenyan_shillings
usd
tonnes
hectares
kilometres
```

Preserve original unit label in metadata.

## 17.5 Frequencies

Canonical values:

```text
daily
weekly
monthly
quarterly
semiannual
annual
decennial
irregular
```

## 17.6 Sex labels

Canonical values:

```text
female
male
total
other
not_stated
```

Do not impose categories unsupported by the source.

## 17.7 Dates

Preserve:

- Reference period.
- Release date.
- Retrieval date.

These are not interchangeable.

## 17.8 Provisional and revised data

Include:

```text
revision_status
release_date
vintage
```

Do not overwrite historical vintages in cache unless the user explicitly requests refresh.

---

# 18. Error and condition system

## 18.1 Structured errors

Create package-specific error classes:

```text
knbs_error
knbs_error_invalid_argument
knbs_error_ambiguous_resource
knbs_error_resource_not_found
knbs_error_access_restricted
knbs_error_authentication_required
knbs_error_source_unavailable
knbs_error_rate_limited
knbs_error_schema_changed
knbs_error_parse_failed
knbs_error_validation_failed
knbs_error_download_failed
knbs_error_cache_corrupt
```

## 18.2 Example

```r
cli::cli_abort(
  c(
    "Indicator name is ambiguous.",
    "i" = "Found {length(matches)} possible indicators.",
    "i" = "Use an exact {.field indicator_id}.",
    "*" = "{paste(matches$indicator_id, collapse = ', ')}"
  ),
  class = "knbs_error_ambiguous_resource"
)
```

## 18.3 Warnings

Use warnings for:

- Partial search-source failure.
- Stale cache.
- Experimental adapter.
- Provisional data.
- Missing non-essential metadata.
- A `"latest"` release request.
- Unsupported optional dimension being ignored only when explicitly allowed.

Do not downgrade core data errors to warnings.

---

# 19. Authentication and restricted access

## 19.1 General policy

The package should not initially implement credential storage unless an official source clearly supports token-based access.

## 19.2 If authentication becomes necessary

Use:

- Environment variables.
- `keyring` as a suggested package.
- Source-provided personal tokens.
- OAuth only where officially supported.

Never store secrets in:

- YAML registry files.
- Package options persisted to disk.
- Git history.
- Error logs.
- Download manifests.
- Test fixtures.

## 19.3 Restricted dataset behaviour

Example:

```r
knbs_download_microdata("RESTRICTED_SURVEY")
```

Should return an error such as:

```text
This survey is listed in the catalogue but is not available for
unauthenticated programmatic download.

Access type: Licensed
Action: Complete the official KNBS access process and use the
download method provided by the catalogue.
```

The error object may contain the official access page as structured metadata.

---

# 20. Caching strategy

## 20.1 Cache levels

### Catalogue cache

Short-lived:

- Search results.
- Indicator lists.
- Publication lists.
- Survey metadata.

Suggested default expiry: 24 hours.

### Data cache

Longer-lived:

- Released indicator datasets.
- Documentation.
- Geographic reference tables.

Suggested default expiry: 7 days or release-aware.

### Immutable version cache

Never automatically expire when tied to an explicit release identifier.

## 20.2 Cache metadata

For each cached item, store:

```json
{
  "cache_key": "...",
  "source_id": "...",
  "operation": "...",
  "resource_id": "...",
  "query": {},
  "retrieved_at": "...",
  "expires_at": "...",
  "etag": "...",
  "last_modified": "...",
  "release": "...",
  "content_type": "...",
  "sha256": "...",
  "parser_version": 1,
  "schema_version": 1
}
```

## 20.3 Cache corruption

- Verify checksums.
- Delete corrupt items.
- Retry retrieval.
- Raise a clear error if retrieval also fails.

---

# 21. Testing strategy

## 21.1 No live network in ordinary unit tests

CRAN and continuous-integration tests should run using:

- Stored fixtures.
- Mock HTTP servers.
- Recorded responses with sensitive data removed.
- Small representative files.

## 21.2 Test categories

### Unit tests

Test:

- Query construction.
- Argument validation.
- Registry validation.
- Parser behaviour.
- Standardisation.
- Metadata attachment.
- Citation formatting.
- Cache keys.
- Error classes.

### Contract tests

Each adapter must satisfy a common adapter contract.

Example:

```r
test_adapter_contract <- function(adapter) {
  expect_true(is.function(adapter$search))
  expect_true(is.function(adapter$fetch))
  expect_true(is.function(adapter$metadata))
}
```

### Fixture tests

For each source, store small fixture responses representing:

- Normal response.
- Empty response.
- Pagination.
- Missing field.
- Changed field.
- Restricted resource.
- Error response.
- Duplicate records.
- Provisional data.

### Snapshot tests

Use sparingly for:

- Print methods.
- Error messages.
- Metadata summaries.

### Integration tests

Run on a schedule, not on every pull request.

For example:

- Weekly.
- Manual workflow dispatch.
- Source health checks.
- Schema comparison.
- Publication discovery.

## 21.3 Schema-change detection

For each live integration source:

1. Fetch a small known resource.
2. Record field names and types.
3. Compare with expected schema.
4. Open an issue automatically if changed.
5. Do not automatically modify parsers.

## 21.4 Core test cases

At minimum:

- Indicator ID resolves correctly.
- Ambiguous search raises correct error.
- Leading-zero county codes survive parsing.
- Missing-value symbols preserve status.
- Restricted files are not downloaded.
- Public files are checksummed.
- Cache hit avoids HTTP call.
- `refresh = TRUE` performs retrieval.
- Metadata include retrieval date.
- Citation includes source and release.
- Partial source failure produces warning.
- Duplicate observations fail validation.
- Unexpected content type fails safely.
- ZIP path traversal is blocked.
- `knbs_status(live = FALSE)` does not access network.

---

# 22. Continuous integration

## 22.1 R CMD check workflow

Run on:

- Ubuntu latest.
- Windows latest.
- macOS latest.

R versions:

- Release.
- Old release.
- Development, allowed to fail initially.

## 22.2 Additional workflows

### Lint

Use `lintr`.

### Coverage

Use `covr` and Codecov if desired.

### Documentation

Build pkgdown site.

### Source monitor

Weekly live checks for supported sources.

### Security

Use dependency review where available.

## 22.3 Branch protection

Require:

- R CMD check.
- Unit tests.
- Lint.
- Review.
- No secrets detected.

---

# 23. Documentation plan

## 23.1 README

The README should include:

- Package purpose.
- Installation.
- Quick start.
- Search example.
- Indicator example.
- Survey example.
- Citation example.
- Access-control statement.
- Source-status warning.
- Contribution link.

## 23.2 Vignettes

### `getting-started`

- Installation.
- Package concepts.
- Search.
- Metadata.
- Caching.
- Citations.

### `survey-catalogue`

- Search studies.
- Inspect metadata.
- Search variables.
- List files.
- Understand access status.

### `indicator-data`

- Discover indicator IDs.
- Download data.
- Filter dimensions.
- Handle vintages.
- Plot results.

### `reproducible-citations`

- Retrieve data.
- Inspect provenance.
- Pin releases.
- Generate citations.
- Record package version.

### `county-data`

- Geographic codes.
- Joining indicators.
- Vintage mismatches.
- Optional mapping.

### `adding-a-source-adapter`

- Adapter contract.
- Registry update.
- Parser.
- Standardisation.
- Fixtures.
- Tests.
- Documentation.

---

# 24. Security and ethical considerations

## 24.1 Confidentiality

The package should be designed primarily around:

- Public aggregate data.
- Public metadata.
- Public-use microdata.

It should not process confidential KNBS unit records unless KNBS later develops a formal internal extension.

## 24.2 Personal data

Do not log:

- User names.
- Email addresses.
- Tokens.
- Cookies.
- Download authorisation details.
- Microdata contents.

## 24.3 Terms and licensing

Every adapter must document:

- Terms URL.
- Access type.
- Licence if available.
- Redistribution limitations.

## 24.4 Responsible load

- Cache responses.
- Avoid unnecessary repeated requests.
- Use serial requests by default.
- Respect rate limits.
- Provide source-contact information where appropriate.

## 24.5 Data interpretation

The package should not imply that combining indicators from different reference years creates a single contemporaneous dataset.

Consider adding helper warnings for incompatible joins only in a future version. For now, preserve reference period and release metadata clearly.

---

# 25. Development phases

# Phase 0: Repository bootstrap

## Objectives

- Create package skeleton.
- Add governance files.
- Configure testing and CI.
- Define core classes and registries.

## Tasks

- Initialise package with `usethis`.
- Add MIT licence or another approved licence.
- Configure `testthat` edition 3.
- Add `roxygen2`.
- Add GitHub Actions.
- Add pkgdown.
- Add linting.
- Add code of conduct.
- Add contributing guide.
- Add issue templates.
- Add security policy.
- Create `knbs-package.R`.
- Add package options.
- Add condition classes.

## Exit criteria

- `R CMD check` passes.
- CI passes.
- A minimal pkgdown site builds.
- No network access in tests.

---

# Phase 1: Source discovery and registries

## Objectives

- Identify viable official sources.
- Document access and technical characteristics.
- Build source registry.

## Tasks

- Audit survey catalogue.
- Audit publications catalogue.
- Audit aggregate indicator portals.
- Audit geography reference sources.
- Identify APIs and machine-readable downloads.
- Record terms and access restrictions.
- Build `source-registry.yml`.
- Build registry validator.
- Write source audit.
- Classify sources by support tier.

## Exit criteria

- At least one survey source is implementation-ready.
- At least one publication source is implementation-ready.
- At least one aggregate indicator family is implementation-ready.
- Every chosen source has fixtures and documented legal access.

---

# Phase 2: Core infrastructure

## Objectives

- Implement HTTP, caching, parsing, metadata, and adapter interfaces.

## Tasks

- Build `knbs_request()`.
- Build retry and error handling.
- Build cache.
- Build registry loader.
- Build query object.
- Build base adapter contract.
- Build JSON, CSV, and HTML parsers as needed.
- Build metadata classes.
- Build `knbs_cite()`.
- Build print methods.
- Add fixture test helpers.

## Exit criteria

- A mock source can be searched and fetched end to end.
- Cache behaviour is tested.
- Metadata survive supported operations.
- Errors use package-specific classes.

---

# Phase 3: Survey catalogue MVP

## Objectives

- Deliver useful survey discovery without requiring microdata downloads.

## Tasks

- Implement survey adapter.
- Implement `knbs_search_surveys()`.
- Implement `knbs_survey_metadata()`.
- Implement `knbs_variables()`.
- Implement `knbs_survey_files()`.
- Classify access types.
- Add documentation download for public files.
- Add microdata download only where explicitly supported.
- Add survey vignette.

## Exit criteria

A user can:

1. Find a survey.
2. Read its metadata.
3. Search its variables.
4. List its documentation and data files.
5. Understand access requirements.
6. Download public documentation.
7. Download public-use data only when legitimately available.

---

# Phase 4: Publications MVP

## Objectives

- Make official KNBS publications searchable and reproducibly downloadable.

## Tasks

- Implement publication adapter.
- Implement `knbs_publications()`.
- Implement `knbs_download_publication()`.
- Add metadata sidecar.
- Add checksums.
- Add citation support.
- Add publication examples.

## Exit criteria

A user can search for a publication by topic and year, download it, verify it, and generate a citation.

---

# Phase 5: Aggregate indicators MVP

## Objectives

- Support a small, high-quality indicator collection.

## Tasks

- Select one stable indicator source.
- Build indicator registry.
- Implement `knbs_indicators()`.
- Implement `knbs_get_indicator()`.
- Implement period filtering.
- Implement dimension filtering.
- Implement release metadata.
- Add validation.
- Add indicator vignette.
- Add at least three indicator families.

## Suggested first families

Order of preference should be based on source quality, not importance alone.

Possible sequence:

1. Consumer prices.
2. Population.
3. National accounts.
4. Labour.
5. Poverty.
6. Trade.

## Exit criteria

- At least three indicator families work.
- Data use canonical schema.
- Release metadata are preserved.
- Citations work.
- Fixtures cover schema changes and missing statuses.

---

# Phase 6: Geographies and classifications

## Objectives

- Provide reliable join keys.

## Tasks

- Build county reference data.
- Add code-vintage metadata.
- Implement `knbs_geographies()`.
- Add aliases carefully.
- Add classification retrieval.
- Add optional boundaries only after source review.
- Add county-data vignette.

## Exit criteria

- All county codes remain character.
- Vintage is explicit.
- No unverified geographic crosswalk is presented as official.
- Tests validate expected feature counts if boundaries are included.

---

# Phase 7: Hardening and first public release

## Objectives

- Prepare version 0.1.0.

## Tasks

- Run reverse dependency check if relevant.
- Improve errors.
- Complete documentation.
- Complete source-status table.
- Add lifecycle badges.
- Add citation file.
- Review licences.
- Review terms.
- Run security scan.
- Run full R CMD check.
- Test fresh installation.
- Tag release.
- Publish pkgdown.
- Optionally submit to rOpenSci review before CRAN.

## Exit criteria

- No ERRORs or WARNINGs in R CMD check.
- Network-dependent tests are excluded from CRAN.
- All exported functions documented.
- Source limitations clearly stated.
- Access controls verified.
- README examples work.

---

# 26. Prioritised backlog

## Priority 0: Foundation

- [ ] Create package skeleton.
- [ ] Add licence.
- [ ] Add testthat.
- [ ] Add CI.
- [ ] Add pkgdown.
- [ ] Add condition classes.
- [ ] Add package options.
- [ ] Add source registry format.
- [ ] Add registry validation.
- [ ] Add source audit document.

## Priority 1: Survey catalogue

- [ ] Discover public study-search endpoint.
- [ ] Discover study metadata endpoint.
- [ ] Discover variable metadata endpoint.
- [ ] Discover file-list endpoint.
- [ ] Implement survey parser.
- [ ] Implement survey standardiser.
- [ ] Add fixtures.
- [ ] Add `knbs_search_surveys()`.
- [ ] Add `knbs_survey_metadata()`.
- [ ] Add `knbs_variables()`.
- [ ] Add `knbs_survey_files()`.
- [ ] Add access classification.
- [ ] Add citation support.

## Priority 2: Publications

- [ ] Discover publications catalogue.
- [ ] Implement publication search.
- [ ] Implement metadata extraction.
- [ ] Implement safe downloads.
- [ ] Add checksum and sidecar metadata.
- [ ] Add publication citation.
- [ ] Add fixtures.

## Priority 3: Indicators

- [ ] Discover indicator source.
- [ ] Select first families.
- [ ] Create stable IDs.
- [ ] Build indicator registry.
- [ ] Implement list and fetch.
- [ ] Implement period parser.
- [ ] Implement dimension standardiser.
- [ ] Implement release tracking.
- [ ] Add data validation.
- [ ] Add fixtures.

## Priority 4: Reference data

- [ ] Identify official county code source.
- [ ] Build reproducible data-raw script.
- [ ] Add geography schema.
- [ ] Add `knbs_geographies()`.
- [ ] Identify classification sources.
- [ ] Add classifications.
- [ ] Assess boundary licence.

## Priority 5: User experience

- [ ] Improve print methods.
- [ ] Add progress indicators for downloads.
- [ ] Add cache-management functions.
- [ ] Add `knbs_status()`.
- [ ] Add vignettes.
- [ ] Add examples.
- [ ] Add source-status page.

---

# 27. Suggested GitHub issues

## Issue 1: Bootstrap package repository

**Goal:** Create the initial R package with CI, tests, documentation, and governance files.

**Acceptance criteria:**

- Package installs.
- R CMD check passes.
- GitHub Actions run.
- `testthat` works.
- pkgdown builds.

## Issue 2: Define source registry schema

**Goal:** Implement YAML-based source registration.

**Acceptance criteria:**

- Registry loads.
- Invalid source IDs fail.
- Unknown operations fail.
- Duplicate IDs fail.
- Unit tests cover validation.

## Issue 3: Implement HTTP client

**Goal:** Create a consistent request layer.

**Acceptance criteria:**

- User agent set.
- Timeout configurable.
- Retry policy tested.
- Rate-limit response handled.
- Structured errors emitted.

## Issue 4: Implement cache

**Goal:** Cache catalogues and downloaded data.

**Acceptance criteria:**

- Stable cache keys.
- Cache hit avoids request.
- Refresh bypasses cache.
- Corrupt cache detected.
- Cache can be cleared.

## Issue 5: Survey catalogue discovery

**Goal:** Document viable public catalogue endpoints.

**Acceptance criteria:**

- Search endpoint identified.
- Metadata endpoint identified.
- Variable endpoint identified or limitation documented.
- Access-control behaviour documented.
- Fixtures stored.

## Issue 6: Implement survey search

**Acceptance criteria:**

- Query returns standard schema.
- Pagination supported.
- Empty result handled.
- Partial metadata handled.
- Search covered by fixtures.

## Issue 7: Implement variable search

**Acceptance criteria:**

- Search by label.
- Search by name.
- File membership preserved.
- Large result set handled.
- No microdata downloaded.

## Issue 8: Implement publication search and download

**Acceptance criteria:**

- Search by topic and year.
- Download verifies content type.
- Checksum generated.
- Metadata sidecar written.
- Citation generated.

## Issue 9: Implement first indicator family

**Acceptance criteria:**

- Stable indicator ID.
- Metadata recorded.
- Time filters work.
- Unit recorded.
- Release date recorded.
- Duplicate validation works.
- Tests use fixtures.

## Issue 10: Add county reference table

**Acceptance criteria:**

- Source documented.
- Codes stored as character.
- Vintage field present.
- Data-raw build script reproducible.
- Tests check uniqueness.

---

# 28. Implementation sequence

Follow this sequence and avoid attempting all features at once.

## Step 1: Inspect the repository

If starting from an existing repository:

- Read `DESCRIPTION`.
- Read `NAMESPACE`.
- Inspect existing `R/`.
- Inspect tests.
- Run `R CMD check`.
- Record baseline failures.
- Do not overwrite existing work.

If starting from an empty directory:

- Initialise a standard R package.
- Use `usethis` conventions.
- Create the repository structure in this document.

## Step 2: Create a project tracking file

Create:

```text
dev/IMPLEMENTATION_STATUS.md
```

Include:

- Current phase.
- Completed tasks.
- Open decisions.
- Blockers.
- Source audit status.
- Next three tasks.
- Known risks.

Update this file after each significant implementation step.

## Step 3: Build foundation before source adapters

Implement first:

- Conditions.
- Options.
- Registry.
- Query object.
- HTTP layer.
- Cache.
- Metadata class.
- Citation class.
- Tests.

## Step 4: Use a fake adapter

Before connecting to KNBS sources, create an internal fake adapter and fixture data.

This confirms that public functions and internal contracts work independently of network complexity.

## Step 5: Complete source discovery

Do not guess production endpoints.

Document and verify them.

## Step 6: Implement one vertical slice

The first vertical slice should be:

```text
search survey
-> retrieve metadata
-> standardise
-> attach provenance
-> print
-> cite
```

Finish and test this end to end before adding a second source.

## Step 7: Add publication support

## Step 8: Add one indicator family

## Step 9: Add geography reference data

## Step 10: Harden, document, and release

---

# 29. Coding standards

## 29.1 Style

Follow tidyverse style where sensible.

Use:

- Two-space indentation.
- Explicit, descriptive names.
- Small functions.
- Early validation.
- `snake_case`.
- Internal helpers prefixed when useful.

## 29.2 Documentation

Every exported function must include:

- Title.
- Description.
- Parameters.
- Return value.
- Details.
- Errors or access notes where relevant.
- Examples that do not require live internet during checks.

## 29.3 Namespacing

Use explicit namespace calls internally where it improves clarity:

```r
tibble::tibble()
dplyr::mutate()
httr2::request()
```

## 29.4 Avoid hidden global state

Use options only for user-configurable defaults.

Do not store mutable data in package namespace environments unless carefully controlled.

## 29.5 No silent guessing

Do not silently infer:

- Indicator IDs.
- Units.
- Geographic vintages.
- Release dates.
- Missing-value meanings.
- Access permissions.

---

# 30. Definition of done for a source adapter

A source adapter is complete only when all items below are satisfied.

- [ ] Official ownership documented.
- [ ] Terms and access reviewed.
- [ ] Supported operations documented.
- [ ] Public endpoints identified.
- [ ] Pagination implemented.
- [ ] Errors handled.
- [ ] Rate limiting respected.
- [ ] Fixtures stored.
- [ ] Parser implemented.
- [ ] Standardiser implemented.
- [ ] Required schema validated.
- [ ] Metadata preserved.
- [ ] Citation supported.
- [ ] Cache behaviour tested.
- [ ] Live health check available.
- [ ] User documentation added.
- [ ] Source limitations documented.
- [ ] No credentials committed.
- [ ] No access controls bypassed.

---

# 31. Definition of done for version 0.1.0

Version 0.1.0 should not be released until:

- [ ] Package passes R CMD check.
- [ ] CI passes on major operating systems.
- [ ] At least one survey catalogue is supported.
- [ ] At least one publication catalogue is supported.
- [ ] At least three aggregate indicator families are supported, or the limitation is explicitly accepted.
- [ ] County reference data are available.
- [ ] Citations work.
- [ ] Metadata are attached.
- [ ] Caching works.
- [ ] Restricted access is handled safely.
- [ ] Documentation is complete.
- [ ] All live-source tests are separated from ordinary tests.
- [ ] Source-status and limitations are published.
- [ ] Licences and terms have been reviewed.
- [ ] Package has a clear maintainer and contact route.

---

# 32. Example internal implementation skeleton

## 32.1 Search wrapper

```r
knbs_search <- function(
  query,
  type = c(
    "all",
    "indicator",
    "survey",
    "publication",
    "geography",
    "classification"
  ),
  topic = NULL,
  year = NULL,
  source = NULL,
  limit = 50,
  exact = FALSE
) {
  type <- rlang::arg_match(type)

  query <- validate_search_query(query)
  limit <- validate_limit(limit)

  sources <- resolve_search_sources(
    type = type,
    source = source
  )

  results <- purrr::map(
    sources,
    search_one_source,
    query = query,
    type = type,
    topic = topic,
    year = year,
    limit = limit,
    exact = exact
  )

  failures <- purrr::keep(results, inherits, "knbs_source_failure")
  successes <- purrr::discard(results, inherits, "knbs_source_failure")

  if (length(successes) == 0L) {
    cli::cli_abort(
      "All KNBS sources failed.",
      class = "knbs_error_source_unavailable"
    )
  }

  if (length(failures) > 0L) {
    cli::cli_warn(
      "{length(failures)} source{?s} could not be searched."
    )
  }

  successes |>
    dplyr::bind_rows() |>
    rank_search_results(query = query, exact = exact) |>
    dplyr::slice_head(n = limit) |>
    new_knbs_catalogue()
}
```

## 32.2 Indicator wrapper

```r
knbs_get_indicator <- function(
  indicator,
  start = NULL,
  end = NULL,
  geography = NULL,
  geo_code = NULL,
  sex = NULL,
  age_group = NULL,
  category = NULL,
  release = "latest",
  source = NULL,
  tidy = TRUE,
  cache = knbs_option("cache"),
  refresh = FALSE
) {
  definition <- resolve_indicator(
    indicator = indicator,
    source = source
  )

  query <- new_knbs_query(
    resource_type = "indicator",
    resource_id = definition$indicator_id,
    source = definition$source_id,
    release = release,
    filters = compact_list(
      start = start,
      end = end,
      geography = geography,
      geo_code = geo_code,
      sex = sex,
      age_group = age_group,
      category = category
    )
  )

  raw <- source_fetch_cached(
    source_id = definition$source_id,
    query = query,
    cache = cache,
    refresh = refresh
  )

  parsed <- parse_source_response(
    source_id = definition$source_id,
    operation = "get_indicator",
    raw = raw
  )

  standard <- standardise_indicator(
    parsed,
    definition = definition
  )

  validate_indicator_data(
    standard,
    definition = definition
  )

  metadata <- build_indicator_metadata(
    definition = definition,
    response = raw,
    data = standard,
    query = query
  )

  new_knbs_indicator(
    tibble::as_tibble(standard),
    metadata = metadata
  )
}
```

---

# 33. Suggested first README example

```r
library(knbsdata)

# Search the supported KNBS catalogues
knbs_search("consumer price index")

# List available price indicators
knbs_indicators(topic = "prices")

# Download an indicator
cpi <- knbs_get_indicator(
  indicator = "CPI_ALL_ITEMS",
  start = "2020-01"
)

# Inspect provenance
knbs_metadata(cpi)

# Generate a citation
knbs_cite(cpi)

# Search survey metadata
knbs_search_surveys("household budget")

# Search variables without downloading microdata
knbs_variables(
  survey = "KIHBS-2015",
  search = "food expenditure"
)
```

---

# 34. Future roadmap

## Version 0.2.0

- More indicator families.
- Better revision-vintage support.
- Additional classifications.
- More robust geography concordances.
- Public-use microdata import helpers.
- Optional Arrow output.
- Data dictionaries.
- Improved offline workflows.

## Version 0.3.0

- Registered Excel table extraction.
- Optional SDMX support.
- Cross-source indicator search.
- Dataset update notifications.
- Reproducibility manifests.
- Quarto integration.
- `pins` integration.

## Version 0.4.0

- Optional Shiny or Plumber service.
- County dashboard helpers.
- Metadata export in JSON-LD or DataCite-like formats.
- Workflow support for KNBS internal teams, subject to institutional agreement.

## Version 1.0.0

- Stable source contracts.
- Stable indicator IDs.
- Broad documentation.
- Governance and maintenance plan.
- Formal KNBS endorsement if possible.
- CRAN and possibly rOpenSci review.

---

# 35. Open decisions

Record these in `dev/IMPLEMENTATION_STATUS.md` and do not resolve them silently.

1. What licence should the package use?
2. Will the package be formally affiliated with KNBS?
3. Which official KNBS source is stable enough for aggregate indicators?
4. Does the survey catalogue expose a supported machine-readable API?
5. Which public-use microdata can legally be downloaded programmatically?
6. Which geographic codes and boundaries have clear official licences?
7. Should `sf` be an import or suggested dependency?
8. Should indicator periods use `Date`, `yearmon`, `yearquarter`, or `clock` classes?
9. Should the package preserve all dimensions as columns or use a dimensions list-column?
10. Should source-provided citations override package-generated citations?
11. How long should catalogue caches remain valid?
12. Should explicit historical releases be stored indefinitely?
13. Should the package support Swahili metadata if sources provide it?
14. Should the first public release target CRAN or GitHub only?
15. Should the package seek rOpenSci software review?

---

# 36. Risks and mitigations

## Risk: Source websites change

Mitigation:

- Adapter isolation.
- Fixtures.
- Weekly health checks.
- Schema-change alerts.
- Stable registry.
- Clear error messages.

## Risk: No documented API

Mitigation:

- Prefer official file downloads.
- Support metadata only where necessary.
- Avoid brittle scraping.
- Encourage KNBS to expose a stable API.

## Risk: Access restrictions misunderstood

Mitigation:

- Explicit access fields.
- No automatic legal acceptance.
- Conservative download rules.
- Source-specific access tests.

## Risk: Geographic codes lose leading zeros

Mitigation:

- Read as character.
- Explicit column specifications.
- Validation tests.

## Risk: Data revisions break reproducibility

Mitigation:

- Preserve release date.
- Support explicit release where possible.
- Store checksums.
- Cache immutable vintages.

## Risk: Package appears officially endorsed when it is not

Mitigation:

- Add a clear disclaimer until KNBS formally endorses it.
- Avoid using protected branding without permission.
- State source ownership separately from package authorship.

## Risk: Too much scope

Mitigation:

- Strict 0.1.0 scope.
- One vertical slice at a time.
- Do not implement universal PDF extraction.
- Prioritise high-quality sources over many sources.

## Risk: Maintenance burden

Mitigation:

- Source registry.
- Common adapter interface.
- Automated source monitoring.
- Contributor documentation.
- Small dependency footprint.

---

# 37. Proposed disclaimer

Until formal institutional approval exists, include wording similar to:

> `knbsdata` is an independent open-source software project designed to facilitate access to publicly available statistics and metadata published by the Kenya National Bureau of Statistics. It is not an official KNBS product unless and until KNBS formally adopts or endorses it. Users should consult the original KNBS source for authoritative definitions, revisions, access conditions, and official releases.

---

# 38. Final instruction

Start with repository inspection and Phase 0.

Do not begin by scraping many KNBS pages.

The correct first implementation sequence is:

1. Create or inspect the package.
2. Establish tests and CI.
3. Build the registry, HTTP, cache, metadata, and error infrastructure.
4. Create a fake adapter.
5. Complete a documented source-discovery audit.
6. Implement one survey-catalogue vertical slice.
7. Implement publications.
8. Implement one high-quality aggregate indicator family.
9. Add geographic reference data.
10. Harden and document the package.

At every stage:

- Run tests.
- Run `R CMD check`.
- Update `dev/IMPLEMENTATION_STATUS.md`.
- Avoid undocumented assumptions.
- Preserve metadata.
- Respect access controls.
- Keep source-specific logic internal.
- Add fixtures before expanding functionality.
- Prefer a small reliable package over a broad fragile scraper.
