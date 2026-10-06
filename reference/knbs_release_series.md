# KNBS's regular release series

**\[experimental\]**

The series
[`knbs_releases()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_releases.md)
recognises, with the id to ask for each by. Curated from the titles in
the KNBS website's publications library.

## Usage

``` r
knbs_release_series()
```

## Value

A tibble with columns `series_id`, `series` and `frequency`.

## See also

[`knbs_releases()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_releases.md)

## Examples

``` r
knbs_release_series()
#> # A tibble: 14 × 3
#>    series_id        series                                             frequency
#>    <chr>            <chr>                                              <chr>    
#>  1 cpi              Consumer Price Indices and Inflation Rates         monthly  
#>  2 lei              Leading Economic Indicators                        monthly  
#>  3 ppi              Producer Price Indices                             quarterly
#>  4 cipi             Construction Input Price Indices                   quarterly
#>  5 rppi             Residential Property Price Index                   quarterly
#>  6 qgdp             Quarterly Gross Domestic Product                   quarterly
#>  7 qbop             Quarterly Balance of Payments and International T… quarterly
#>  8 qlfs             Quarterly Labour Force Report                      quarterly
#>  9 county_abstract  County Statistical Abstract                        annual   
#> 10 abstract         Statistical Abstract                               annual   
#> 11 economic_survey  Economic Survey                                    annual   
#> 12 facts_figures    Facts and Figures                                  annual   
#> 13 gcp              Gross County Product                               annual   
#> 14 release_calendar Advance Release Calendar                           annual   
```
