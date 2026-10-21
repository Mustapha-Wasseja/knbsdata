# Write KNBS data to a file, with its provenance

**\[experimental\]**

Saves a table for colleagues who work in Excel, Stata, SPSS or anything
that reads CSV, without losing where it came from. The format follows
the file extension:

- `.xlsx` - an Excel workbook with the data on a `data` sheet and an
  `about` sheet carrying the title, source, licence, release date,
  retrieval time and a ready-made citation.

- `.csv` - UTF-8 CSV, with missing values as empty cells.

- `.dta` - Stata, with the title as the dataset label.

- `.sav` - SPSS, likewise.

- `.rds` - R, keeping the object whole, metadata included.

CSV, Stata and SPSS files get a `<file>.metadata.json` provenance
sidecar beside them, the same sidecar
[`knbs_download_publication()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_publication.md)
writes.

## Usage

``` r
knbs_write(
  x,
  path,
  format = NULL,
  metadata = NULL,
  overwrite = FALSE,
  quiet = knbs_option("quiet")
)
```

## Arguments

- x:

  A data frame: a result of this package, or any table.

- path:

  Where to write. The extension chooses the format.

- format:

  One of `"xlsx"`, `"csv"`, `"dta"`, `"sav"` or `"rds"`, to override the
  extension.

- metadata:

  The provenance to record. Defaults to `x`'s own.

- overwrite:

  Whether to replace an existing file.

- quiet:

  Whether to suppress the confirmation message.

## Value

The path written, invisibly.

## Details

Codes stay text: `"01"` is written as text in every format, never as the
number 1. In CSV that means a quoted string, which Excel may still turn
into a number when it opens the file; for Excel, write `.xlsx`.

List columns (the value labels of a survey's variables, for example)
have no equivalent in these formats; each cell is written as JSON text,
and the provenance says which columns were converted.

Stata limits variable names to 32 characters. Longer names are shortened

- keeping a `_code` or `_type` ending, and staying unique - and the full
  name becomes the variable's label; the provenance lists every rename.

A table derived with `summarise()` or a pivot is plain data and carries
no provenance of its own. Pass the source's with
`metadata = knbs_metadata(original)`; without it the file is still
written, with a warning, and the `about` sheet or sidecar says no
provenance was attached.

Excel output needs the writexl package and Stata or SPSS output the
haven package; you are asked to install them if they are missing.

## See also

[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md),
[`knbs_cite()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cite.md)

## Examples

``` r
# The FinAccess file catalogue ships with the package, provenance and all
files <- knbs_finaccess_files(content = "data")
path <- file.path(tempdir(), "finaccess-files.csv")
knbs_write(files, path)                        # + finaccess-files.csv.metadata.json
#> ✔ Wrote /tmp/RtmpUVZNuQ/finaccess-files.csv (14 rows), provenance in finaccess-files.csv.metadata.json.
if (FALSE) { # interactive()
gdp <- knbs_abstract_table("2.2")
knbs_write(gdp, file.path(tempdir(), "gdp-by-activity.xlsx"))   # data + about sheet
knbs_write(gdp, file.path(tempdir(), "gdp-by-activity.dta"))

# A derived table keeps the source's provenance when you pass it on
totals <- dplyr::summarise(gdp, value = sum(value), .by = period)
knbs_write(totals, file.path(tempdir(), "totals.csv"), metadata = knbs_metadata(gdp))
}
```
