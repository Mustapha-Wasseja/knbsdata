# Search official KNBS publications

**\[experimental\]**

Searches the documents in the KNBS website's media library: statistical
releases, survey reports, the Economic Survey and other published files.

## Usage

``` r
knbs_publications(
  query = NULL,
  year = NULL,
  format = NULL,
  limit = 100,
  source = NULL,
  cache = knbs_option("cache"),
  refresh = FALSE
)
```

## Arguments

- query:

  Free-text search over titles and descriptions.

- year:

  Keep only publications whose title names this year, or a range
  `c(from, to)`.

- format:

  Keep only these file formats: any of `"pdf"`, `"xlsx"`, `"xls"`,
  `"docx"`, `"csv"`, `"zip"`.

- limit:

  Maximum number of records to return (at most 100).

- source:

  Source id. Defaults to the first verified publications source.

- cache:

  Whether to use the local cache.

- refresh:

  Whether to bypass any cached response.

## Value

A `knbs_catalogue` tibble with columns `publication_id`, `title`,
`year`, `release_date`, `modified`, `description`, `format`,
`file_size`, `file_name`, `download_url`, `landing_page`, `source_id`,
`checksum` and `access`.

## Details

Two honesty notes about this source. First, `release_date` is the date
the file was uploaded to the site, not the publication's reference
period; the `year` column is read from the title, and is `NA` when the
title names none. Second, the media library also holds speeches, launch
remarks and forms — narrowing to what you mean is the job of `query` and
`format`.

The source ignores its own file-type parameter (audit F-22), so the
`format` filter is applied by the package — and because a page of recent
uploads may contain no matches at all, supplying `format` makes the
search page back through older uploads until it has `limit` matches or
the matches are exhausted. Expect a format-filtered search to take a few
seconds longer than a plain one.

The reference-year filter is applied to the title-derived `year`, after
retrieval. With a narrow `query` this is exact; with a broad one it
filters only within the records retrieved.

## See also

[`knbs_download_publication()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_publication.md)

## Examples

``` r
if (FALSE) { # interactive()
knbs_publications("economic survey")
knbs_publications("consumer price", format = "xlsx")
knbs_publications("census", year = c(2019, 2023))
}
```
