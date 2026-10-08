# Download public-use microdata

**\[experimental\]**

The Kenya National Data Archive gates every download behind an account,
and this package does not automate sign-in, licence acceptance or
approval workflows, so the function reports what is required and stops.

## Usage

``` r
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

## Arguments

- survey:

  A study identifier.

- files:

  Files to download.

- destination:

  Directory to write to.

- overwrite:

  Whether to overwrite existing files.

- verify:

  Whether to verify downloads.

- manifest:

  Whether to write a download manifest.

- quiet:

  Whether to suppress progress messages.

## Value

Never returns; raises `knbs_error_authentication_required`.

## Details

It exists so that the refusal is explicit and points at the official
process, rather than the operation appearing to be unsupported by
oversight.

Microdata that their producers publish for anyone are another matter:
the FinAccess household and MSE Tracker surveys are listed by
[`knbs_finaccess_files()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_finaccess_files.md)
and downloaded by
[`knbs_download_finaccess()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_finaccess.md).
Files obtained through the archive's own process can be read with
[`knbs_read_microdata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_read_microdata.md).

## See also

[`knbs_survey_files()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_survey_files.md)
to see what a study holds and on what terms;
[`knbs_finaccess_files()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_finaccess_files.md)
for open microdata.

## Examples

``` r
if (FALSE) { # \dontrun{
# Raises an error explaining the official access process:
knbs_download_microdata("KEN-KNBS-KIHBS-2015-2016-v01")
} # }
```
