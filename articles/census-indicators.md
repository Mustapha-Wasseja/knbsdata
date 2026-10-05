# Indicators: census tables and consumer prices

``` r

library(knbsdata)
```

[`knbs_indicators()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_indicators.md)
lists what every verified indicator source serves, and
[`knbs_get_indicator()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_get_indicator.md)
returns one indicator as tidy observations. Three families exist today:
tables from the **2019 Population and Housing Census** (CC BY 4.0), the
**monthly consumer price series** from the KNBS CPI Explorer, the **323
economic dataflows of the KNBS Data Portal** — GDP, trade, balance of
payments, county government finance and much else, in SDMX form — and
the **202 datasets republished by Kenya Open Data for Africa**, which
carry the one thing no first-party portal serves as data: Gross County
Product.

``` r

knbs_indicators()                  # all families, source_id says which
cpi <- knbs_get_indicator("CPI_ALL_ITEMS", start = "2020-01")
gdp <- knbs_get_indicator("DF_NAT_GDPCP")
pop <- knbs_get_indicator("POPCEN0001", geo_level = "county")
gcp <- knbs_get_indicator("jhbzkjc") # Gross County Product, 2013-2020
```

## The Data Portal (SDMX)

Every dataflow keeps its SDMX id (`DF_NAT_GDPCP`, `DF_BOP_A`,
`DF_CPI_R`…); `knbs_indicators(source = "knbs_opendata")` lists all 323
with their statistical domain as `topic`. Annual flows carry
integer-year periods; monthly and quarterly ones carry first-of-period
`Date`s, so `start` and `end` behave as everywhere else. Dimensions vary
per flow and keep their SDMX ids as `<dim>`/`<dim>_label` column pairs,
except single-category dimensions (“Prices = Current prices”, “Unit =
Kenya Shillings”), which are facts about the whole dataflow and fold
into
[`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
notes instead of constant columns.

Two cautions: the portal states **no licence**, and its geography codes
are **SDMX area codes, not census territories** — `geo_level` is `NA`
there, and they must never be joined against
[`knbs_geographies()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_geographies.md).

Chunks that contact the services are shown but not run, so building this
vignette never depends on them.

## Open Data for Africa (the republisher)

`knbs_indicators(source = "opendataforafrica")` lists the 202 datasets
of `kenya.opendataforafrica.org`, the Knoema-operated portal on KNBS’s
own portals page — 169 sourced from KNBS, the rest from the Central Bank
of Kenya, ministries and agencies. Dataset ids are the portal’s own
opaque slugs, so name search is the natural way in:

``` r

knbs_indicators(source = "opendataforafrica", search = "county product")
gcp <- knbs_get_indicator("jhbzkjc")
gcp[gcp$table == "T3" & gcp$period == 2020, ]  # current-price GCP, 2020
```

Three behaviours to know:

- **Mixed frequencies.** One dataset may hold annual, quarterly and
  monthly series side by side. Annual periods are integer years and
  sub-annual ones are `Date`s, which cannot share a column, so a mixed
  dataset refuses to pick silently — say `frequency = "annual"` (or
  `"quarterly"`, `"monthly"`) to choose.
- **Republished provenance.**
  [`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
  names the portal, the original producer, the dataset’s own licence
  label (most KNBS-sourced datasets state “Public Domain”) and the
  portal’s publication and update dates — the data vintage is visible,
  and can lag the producer’s newest PDFs.
- **Geography codes are the portal’s region codes** (`KE`, `KE-110-NA`,
  …), `geo_level` is `NA`, and they must never be joined against
  [`knbs_geographies()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_geographies.md).

## Consumer prices

Three indicators, all monthly, all from one underlying series:

| id                  | measure               | unit         |
|---------------------|-----------------------|--------------|
| `CPI_ALL_ITEMS`     | the index level       | index points |
| `CPI_INFLATION_YOY` | year-on-year change   | percent      |
| `CPI_INFLATION_MOM` | month-on-month change | percent      |

`period` is a `Date` at the first of the month, with a `period_label`
like `"2026-06"`. `start` and `end` take a year, a `"YYYY-MM"` month, or
a date.

``` r

knbs_get_indicator("CPI_INFLATION_YOY", start = 2015, end = 2020)
```

### CPI geography is not census geography

The default is the national series. The other level is `"region"` — the
CPI collection strata: the Nairobi income bands, Nairobi Combined, and
Rest of Urban.

``` r

knbs_get_indicator("CPI_ALL_ITEMS", geo_level = "region")
knbs_get_indicator("CPI_ALL_ITEMS", geo_code = c("national", "1"))
```

These region codes are the source’s own and mean nothing outside it.
**Do not join them against
[`knbs_geographies()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_geographies.md)**
— different coding system, different concept, and the package keeps them
apart deliberately.

Two more honesty notes, both from the source audit:

- The region list also names the former provinces (Central, Coast,
  Eastern, North Eastern, Nyanza, Rift Valley, Western), but **they
  carry no data in any period**. Asking for one returns zero rows,
  because that is the source’s answer.
- The portal states **no licence** and does not state the index base
  period.
  [`knbs_metadata()`](https://Mustapha-Wasseja.github.io/knbsdata/reference/knbs_metadata.md)
  on any result says both, so the caveat travels with the data rather
  than living only in this vignette.

### Retail prices

The same portal publishes the monthly **national average retail prices**
of the 22 commodities tracked for the CPI basket, in Kenya Shillings per
stated unit:

``` r

knbs_retail_prices(commodity = "petrol", start = 2024)
knbs_retail_prices(start = "2026-06", end = "2026-06")   # one month, all 22
```

One row per commodity per month: `commodity_code` (`CPI001`–`CPI022`),
`commodity`, `unit`, `quantity`, `period`, `price`. National only — the
source holds no regional retail prices — and the licence caveat above
applies here too.

## Census tables

### What the census source is, and is not

Three properties worth knowing before you use it:

- **It is census data.** Every table describes 2019. There are no time
  series here: `period` is 2019 throughout, and `frequency` is `NA`
  because a census table is not a recurring release. Consumer prices,
  GDP and other running indicators are *not* in this source (see the
  source-status vignette for where that work stands).
- **It is served over plain HTTP.** The API host has no TLS listener, so
  traffic to it is unencrypted in transit. It carries only public census
  aggregates and no credentials; the registry records the exception
  explicitly.
- **It is first-party.** The service is operated by KNBS (built with
  Istat, Italy’s national statistical institute) and linked from KNBS’s
  own portals page.

### Finding a table

``` r

knbs_indicators()
knbs_indicators(topic = "Population")
knbs_indicators(search = "marital")
```

Thirty-two tables across four populated themes at the time of writing.

### Getting observations

``` r

pop <- knbs_get_indicator("POPCEN0001")
pop
```

You can pass a name instead of an id; if several tables match you get an
error listing the candidates rather than a silently chosen one.

The result has one row per cell:

- **Core columns:** `indicator_id`, `indicator_name`, `period`, `value`.
- **Geography**, where the table has it: `geo_code`, `geo_name`,
  `geo_level`. Codes keep their leading zeros — `"00"` is Kenya, two
  digits are counties, four digits are sub-counties — and `geo_level`
  says which (`"national"`, `"county"`, `"subcounty"`).
- **Sex**, where the table has it, using the source’s own categories
  (the 2019 census enumerated intersex as well as female and male).
- **Every other dimension** keeps its source id: a code column named for
  the dimension (for example `p18_vs1`) and a matching `<id>_label`
  column (“Marital Status”). The dimension names are in
  `knbs_metadata(pop)$notes`.

### Filtering geography

``` r

counties <- knbs_get_indicator("POPCEN0001", geo_level = "county")
nairobi  <- knbs_get_indicator("POPCEN0001", geo_code = "47")
```

Filters are applied after retrieval — the API serves whole tables — so
the first call and the second cost the same request. Tables are cached
for seven days by default.

### A worked example

County population aged 12+, both sexes, all marital statuses:

``` r

pop <- knbs_get_indicator("POPCEN0001", geo_level = "county")
totals <- pop[pop$sex == "total" & pop$p18_vs1 == "T",
              c("geo_code", "geo_name", "value")]
totals[order(-totals$value), ]
```

Because `geo_code` is character with leading zeros intact, these codes
join cleanly against any other dataset keyed the same way.

### Provenance and citation

``` r

knbs_metadata(pop)
knbs_cite(pop)
```

The metadata carry the licence statement, the release date
(`2019-12-31`), the source statement (“KNBS Population Census 2019”) and
the dimension list; the citation is built from them.

### Honesty notes

- `unit` is `NA` in the catalogue: the source does not state units, and
  counts-versus-proportions is knowable only from each table’s name. The
  package does not guess.
- An unknown table id is reported as *not found*. (The API itself
  answers those requests with HTTP 200 and a body reading `errore`; the
  package translates.)
- The service checks the *shape* of everything it parses. If the API
  changes, you get `knbs_error_schema_changed`, not a plausible-looking
  wrong table.
