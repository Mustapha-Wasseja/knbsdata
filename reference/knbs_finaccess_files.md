# List the FinAccess survey files

**\[experimental\]**

The FinAccess household survey, Kenya's survey of financial inclusion
run by the Central Bank of Kenya, KNBS and FSD Kenya, publishes its
anonymised, weighted microdata openly, with no account needed: six
rounds from 2006 to 2024, and two waves of the FinAccess MSE Tracker
Survey of micro and small enterprises (2022 and 2023). This lists every
file, with the questionnaires, manuals and reports, from a catalogue
kept with the package; nothing is contacted.

Download files with
[`knbs_download_finaccess()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_finaccess.md)
and read them with
[`knbs_read_microdata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_read_microdata.md).

## Usage

``` r
knbs_finaccess_files(year = NULL, survey = NULL, content = NULL, format = NULL)
```

## Arguments

- year:

  Survey years to keep.

- survey:

  `"household"` or `"mse_tracker"`.

- content:

  Any of `"data"`, `"questionnaire"`, `"manual"` and `"report"`.

- format:

  Any of `"stata"`, `"spss"`, `"excel"` and `"pdf"`. For an archive, the
  format of the data inside it.

## Value

A `knbs_catalogue` tibble with one row per file: `file_id`, `title`,
`survey`, `year`, `wave`, `content`, `format`, `file_name`,
`size_bytes`, `sha256`, `archive`, `access`, `url` and `notes`.

## Details

The catalogue records what each link on the portal actually serves,
which is not always what its label says: the MSE Tracker Wave II "SPSS"
link serves the Stata file and the reverse, the Wave I "Stata" link
serves the SPSS file, and the 2006 and 2009 "Questionnaire" archives
hold the survey data too. The `notes` column says where a label was
corrected. The portal's 2019 heading lists no files.

The 2013 survey's Stata copy is held on Harvard Dataverse behind a
registration form; it is listed with `access = "registration"` and never
downloaded. Its SPSS copy is open.

## See also

[`knbs_download_finaccess()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_download_finaccess.md),
[`knbs_read_microdata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_read_microdata.md)

## Examples

``` r
knbs_finaccess_files()
#> <knbs_catalogue>
#> Title: FinAccess survey files
#> Rows: 22
#> Source: Central Bank of Kenya, Kenya National Bureau of Statistics and FSD Kenya
#> 
#> # A tibble: 22 × 14
#>    file_id   title survey  year wave  content format file_name size_bytes sha256
#>    <chr>     <chr> <chr>  <int> <chr> <chr>   <chr>  <chr>          <dbl> <chr> 
#>  1 hh2024-s… FinA… house…  2024 NA    data    stata  2024_Fin…  159531918 fe2d1…
#>  2 hh2024-s… FinA… house…  2024 NA    data    spss   2024_Fin…  200306898 94c01…
#>  3 hh2024-e… FinA… house…  2024 NA    data    excel  2024_Fin…  293682571 55e90…
#>  4 hh2024-q… FinA… house…  2024 NA    questi… pdf    2024 Fin…    2792871 70d82…
#>  5 hh2024-m… FinA… house…  2024 NA    manual  pdf    FinAcces…    1835742 132af…
#>  6 hh2024-r… FinA… house…  2024 NA    report  pdf    FINACCES…   34679994 21d86…
#>  7 hh2021-s… FinA… house…  2021 NA    data    stata  Updated …   26335790 b4310…
#>  8 hh2021-s… FinA… house…  2021 NA    data    spss   Updated …   17395099 86dac…
#>  9 hh2021-e… FinA… house…  2021 NA    data    excel  Updated …  202169688 c5c72…
#> 10 hh2021-q… FinA… house…  2021 NA    questi… excel  2021 Fin…    1268290 36c33…
#> # ℹ 12 more rows
#> # ℹ 4 more variables: archive <lgl>, access <chr>, url <chr>, notes <chr>
knbs_finaccess_files(year = 2024, content = "data")
#> <knbs_catalogue>
#> Title: FinAccess survey files
#> Rows: 3
#> Source: Central Bank of Kenya, Kenya National Bureau of Statistics and FSD Kenya
#> 
#> # A tibble: 3 × 14
#>   file_id    title survey  year wave  content format file_name size_bytes sha256
#>   <chr>      <chr> <chr>  <int> <chr> <chr>   <chr>  <chr>          <dbl> <chr> 
#> 1 hh2024-st… FinA… house…  2024 NA    data    stata  2024_Fin…  159531918 fe2d1…
#> 2 hh2024-sp… FinA… house…  2024 NA    data    spss   2024_Fin…  200306898 94c01…
#> 3 hh2024-ex… FinA… house…  2024 NA    data    excel  2024_Fin…  293682571 55e90…
#> # ℹ 4 more variables: archive <lgl>, access <chr>, url <chr>, notes <chr>
knbs_finaccess_files(survey = "mse_tracker")
#> <knbs_catalogue>
#> Title: FinAccess survey files
#> Rows: 5
#> Source: Central Bank of Kenya, Kenya National Bureau of Statistics and FSD Kenya
#> 
#> # A tibble: 5 × 14
#>   file_id    title survey  year wave  content format file_name size_bytes sha256
#>   <chr>      <chr> <chr>  <int> <chr> <chr>   <chr>  <chr>          <dbl> <chr> 
#> 1 mse2023-s… FinA… mse_t…  2023 Wave… data    stata  FinAcces…    3973642 cc47d…
#> 2 mse2023-s… FinA… mse_t…  2023 Wave… data    spss   FinAcces…    6679828 0d72c…
#> 3 mse2022-s… FinA… mse_t…  2022 Wave… data    spss   FinAcces…    7647196 c528b…
#> 4 mse2023-r… FinA… mse_t…  2023 NA    report  pdf    FinAcces…   14444279 c3575…
#> 5 mse2023-r… FinA… mse_t…  2023 NA    report  pdf    FinAcces…   29269595 d16fd…
#> # ℹ 4 more variables: archive <lgl>, access <chr>, url <chr>, notes <chr>
```
