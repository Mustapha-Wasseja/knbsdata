# Read a microdata file into R

**\[experimental\]**

Reads a Stata (`.dta`), SPSS (`.sav`, `.zsav`, `.por`) or Excel
(`.xlsx`, `.xls`) file, or the data file inside a `.zip` archive,
keeping its variable and value labels. Pass it a path or what
[`knbs_download_finaccess()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_finaccess.md)
returns. When the file has a knbsdata provenance sidecar beside it, the
result carries that provenance:
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
says where it came from and
[`knbs_cite()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cite.md)
cites it.

## Usage

``` r
knbs_read_microdata(x, file = NULL, ...)
```

## Arguments

- x:

  A path, or a download record from
  [`knbs_download_finaccess()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_finaccess.md)
  holding one data file.

- file:

  For an archive, the entry to read. Needed only when it holds more than
  one data file.

- ...:

  Passed to the reader:
  [`haven::read_dta()`](https://haven.tidyverse.org/reference/read_dta.html),
  [`haven::read_sav()`](https://haven.tidyverse.org/reference/read_spss.html),
  [`haven::read_por()`](https://haven.tidyverse.org/reference/read_spss.html)
  or
  [`readxl::read_excel()`](https://readxl.tidyverse.org/reference/read_excel.html).
  `col_select` reads only some variables of a large Stata or SPSS file,
  and `n_max` only its first rows.

## Value

A tibble. With a provenance sidecar, a `knbs_microdata` tibble whose
metadata records the source, the producers, the file's checksum and its
terms.

## Details

Stata and SPSS files are read with haven, which must be installed. Value
labels arrive as
[`haven::labelled()`](https://haven.tidyverse.org/reference/labelled.html)
columns:
[`haven::as_factor()`](https://forcats.tidyverse.org/reference/as_factor.html)
turns them into factors and
[`haven::zap_labels()`](https://haven.tidyverse.org/reference/zap_labels.html)
drops them. Each column's question text is in its `"label"` attribute.

An archive is unpacked to a temporary directory, which is removed once
the file is read. If it holds more than one data file, name the one to
read with `file`.

A first variable name that begins with the remnant of a byte-order mark,
an encoding slip that puts a stray character or two in front of a name
such as `interview__key`, is repaired, and the repair is noted in the
metadata.

## See also

[`knbs_download_finaccess()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_finaccess.md),
[`knbs_cite()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_cite.md)

## Examples

``` r
if (FALSE) { # \dontrun{
fa <- knbs_read_microdata(knbs_download_finaccess("hh2024-stata", "data"))
knbs_cite(fa)

# Only some variables of a large file
knbs_read_microdata("data/2024_Finaccess_Publicdata.dta",
                    col_select = c(1:5))
} # }
```
