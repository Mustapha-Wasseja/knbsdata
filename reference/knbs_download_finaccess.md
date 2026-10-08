# Download FinAccess survey files

**\[experimental\]**

Downloads files listed by
[`knbs_finaccess_files()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_finaccess_files.md)
from the FinAccess portal, under their official names, and proves they
are the files the package catalogued. Before a transfer, a sixteen-byte
request confirms the file's served name and size, so a file that has
changed is refused before anything large moves. After it, the size is
checked again and the SHA-256 must equal the catalogued one. A
`<file>.metadata.json` sidecar beside each file records where it came
from, the producers and their terms, so that
[`knbs_read_microdata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_read_microdata.md)
and
[`knbs_cite()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cite.md)
can say so later.

## Usage

``` r
knbs_download_finaccess(
  file,
  destination = ".",
  overwrite = FALSE,
  verify = TRUE,
  quiet = knbs_option("quiet")
)
```

## Arguments

- file:

  File ids from
  [`knbs_finaccess_files()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_finaccess_files.md),
  such as `"hh2024-stata"`, or that function's result.

- destination:

  Directory to write into; created if needed.

- overwrite:

  Whether to replace a file already in `destination`.

- verify:

  Whether to hold each file to the catalogue. `FALSE` downloads whatever
  the link serves now, under the name it is served with: for when the
  producers have revised a file since the catalogue was made. A web page
  is refused either way.

- quiet:

  Whether to suppress messages and the progress bar.

## Value

Invisibly, a tibble with one row per file: `resource_id`, `file_id`,
`original_name`, `local_path`, `download_url`, `downloaded_at`,
`size_bytes`, `sha256`, `content_type`, `package_version` and
`source_id`. Pass it to
[`knbs_read_microdata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_read_microdata.md).

## Details

**Terms.** The portal states no licence. FSD Kenya's terms for the 2013
survey on Harvard Dataverse restrict the data to statistical and
scientific research, forbid redistributing it without FSD Kenya's
written agreement, rule out investigating specific individuals or
organisations, and ask publications to cite the source. Do not assume
wider reuse is allowed: ask the producers first. The package never
bundles these files. The first download in a session says so.

**Already downloaded.** A file already in `destination` is not
downloaded again if it is byte-identical to the catalogued one; its
record is returned instead. That makes
`knbs_read_microdata(knbs_download_finaccess("hh2024-stata"))` safe to
re-run. A file there that differs is left alone, and the call stops
unless `overwrite = TRUE`.

**Large files.** The 2024 files are 160 to 290 MB. Downloads stream to
disk and show progress unless `quiet`. They are not held to the
package's request timeout; a transfer is abandoned only once it has
stalled for that long. Google Drive serves a file too large for its
virus scan after a notice saying it could not be scanned; the package
requests the file directly, as the notice's own download button does,
and relies on the checks above.

**Registration.** Asking for the 2013 survey's Stata copy, which Harvard
Dataverse holds behind a registration form, raises
`knbs_error_authentication_required` with the page to visit. knbsdata
does not automate sign-in, licence acceptance or approval workflows.

## See also

[`knbs_finaccess_files()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_finaccess_files.md),
[`knbs_read_microdata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_read_microdata.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# The 2024 household survey, Stata format (160 MB)
fa <- knbs_read_microdata(knbs_download_finaccess("hh2024-stata", "data"))

# Every round's documentation
knbs_finaccess_files(content = c("questionnaire", "manual")) |>
  knbs_download_finaccess("docs")
} # }
```
