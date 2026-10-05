# Download a publication and verify what arrived

**\[experimental\]**

Downloads one publication file, preserving its official filename,
verifying that a document (not an error page) arrived, checksumming it,
and writing a `<file>.metadata.json` provenance sidecar next to it.

## Usage

``` r
knbs_download_publication(
  publication_id,
  destination = ".",
  overwrite = FALSE,
  verify = TRUE,
  sidecar = TRUE,
  source = NULL,
  quiet = knbs_option("quiet")
)
```

## Arguments

- publication_id:

  A `publication_id` from
  [`knbs_publications()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_publications.md).

- destination:

  Directory to write into.

- overwrite:

  Whether to replace an existing file of the same name.

- verify:

  Whether to refuse a response that is a web page rather than a
  document.

- sidecar:

  Whether to write the provenance sidecar.

- source:

  Source id.

- quiet:

  Whether to suppress the progress message.

## Value

Invisibly, a one-row tibble describing the download: `local_path`,
`download_url`, `downloaded_at`, `size_bytes`, `sha256` and the
identifying fields.

## See also

[`knbs_publications()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_publications.md)
to find identifiers,
[`knbs_cite()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cite.md)
to cite what you downloaded.

## Examples

``` r
if (FALSE) { # \dontrun{
pubs <- knbs_publications("economic survey", year = 2026)
knbs_download_publication(pubs$publication_id[[1]], "data/publications")
} # }
```
