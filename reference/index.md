# Package index

## Search

One search across every catalogue the package reads, each result with
the call that retrieves it.

- [`knbs_search()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_search.md)
  **\[experimental\]** : Search everything the package can retrieve

## Surveys

Discovering studies and their documentation in the Kenya National Data
Archive. Metadata only: the archive gates its microdata behind an
account.

- [`knbs_search_surveys()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_search_surveys.md)
  **\[experimental\]** : Search official survey and census studies
- [`knbs_survey_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_survey_metadata.md)
  **\[experimental\]** : Retrieve the full metadata record for a study
- [`knbs_variables()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_variables.md)
  **\[experimental\]** : Search the variables described by a study
- [`knbs_survey_files()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_survey_files.md)
  **\[experimental\]** : List the data files belonging to a study
- [`knbs_download_microdata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_microdata.md)
  **\[experimental\]** : Download public-use microdata

## Open microdata

The FinAccess household and MSE Tracker surveys, whose anonymised,
weighted microdata are published openly: verified downloads and a reader
that keeps labels and provenance.

- [`knbs_finaccess_files()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_finaccess_files.md)
  **\[experimental\]** : List the FinAccess survey files
- [`knbs_download_finaccess()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_finaccess.md)
  **\[experimental\]** : Download FinAccess survey files
- [`knbs_read_microdata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_read_microdata.md)
  **\[experimental\]** : Read a microdata file into R

## Publications

Statistical releases, reports and workbooks from the KNBS website, with
verified, checksummed downloads.

- [`knbs_publications()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_publications.md)
  **\[experimental\]** : Search official KNBS publications
- [`knbs_download_publication()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_publication.md)
  **\[experimental\]** : Download a publication and verify what arrived
- [`knbs_releases()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_releases.md)
  **\[experimental\]** : What KNBS has released lately
- [`knbs_release_series()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_release_series.md)
  **\[experimental\]** : KNBS's regular release series

## Statistical Abstract tables

Curated, validated extraction of the Statistical Abstract’s chapter
workbooks into tidy tables.

- [`knbs_abstract_tables()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_abstract_tables.md)
  **\[experimental\]** : List the curated Statistical Abstract tables
- [`knbs_abstract_table()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_abstract_table.md)
  **\[experimental\]** : Retrieve one Statistical Abstract table as tidy
  observations

## Indicators and prices

Census tables (CC BY 4.0), the monthly consumer price series, and the
retail prices of the CPI basket commodities.

- [`knbs_indicators()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_indicators.md)
  **\[experimental\]** : List available aggregate indicators
- [`knbs_get_indicator()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_get_indicator.md)
  **\[experimental\]** : Retrieve an indicator as tidy observations
- [`knbs_retail_prices()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_retail_prices.md)
  **\[experimental\]** : National average retail prices of the CPI
  basket commodities

## Geography

The coded territorial hierarchy of the 2019 census frame — the join keys
the census tables themselves use — and official county codes for county
names written any way.

- [`knbs_geographies()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_geographies.md)
  **\[experimental\]** : Kenya's geographic reference codes
- [`knbs_county_code()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_county_code.md)
  **\[experimental\]** : Official county codes for county names written
  any way
- [`knbs_match_counties()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_match_counties.md)
  **\[experimental\]** : See how county names were matched

## Sources

What the package knows about each KNBS source, and how far that source
has been verified.

- [`knbs_sources()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_sources.md)
  : Supported KNBS sources
- [`knbs_status()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_status.md)
  : Report on the health of supported sources

## Provenance

Every object the package returns carries where it came from, when it was
retrieved and how to cite it — and keeps it when written to Excel, CSV,
Stata or SPSS.

- [`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
  : Inspect the provenance of a knbsdata object
- [`knbs_cite()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cite.md)
  : Cite a knbsdata object
- [`knbs_write()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_write.md)
  **\[experimental\]** : Write KNBS data to a file, with its provenance

## Configuration

Session options controlling caching, timeouts and retries.

- [`knbs_option()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_option.md)
  : Get a knbsdata option
- [`knbs_options()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_options.md)
  : Set knbsdata options

## Cache

Inspecting and clearing locally cached responses.

- [`knbs_cache_dir()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cache_dir.md)
  : Where knbsdata stores cached responses
- [`knbs_cache_info()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cache_info.md)
  : What is in the cache
- [`knbs_cache_clear()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cache_clear.md)
  : Empty the cache
- [`knbs_cache_prune()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cache_prune.md)
  : Remove expired cache entries
