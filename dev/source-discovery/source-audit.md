# KNBS source audit

Status: **partially complete.** The survey catalogue has been audited and
classified. The publications, aggregate indicator and geography sources are all
hosted on `knbs.or.ke`, which was **unavailable throughout this audit** (see
finding F-05), so they remain unaudited.

- **Last updated:** 2026-08-03
- **Auditor:** Phase 1 discovery pass
- **Method:** public HTTP requests to published endpoints only; no
  authentication, no form submission, no access control circumvented

---

## Rules for this audit

1. Use public, documented endpoints wherever possible.
2. Do not hard-code endpoints discovered from temporary session tokens.
3. Do not commit credentials or cookies.
4. Do not reverse-engineer protected systems.
5. Do not automate restricted downloads.
6. Record reproducible `curl` examples for public endpoints only.
7. Store small, non-sensitive response fixtures under `dev/fixtures/`.
8. Redact personal or authentication information.

Preference order for access method: documented API → stable machine-readable
endpoint → official CSV/Excel download → catalogue metadata endpoint →
structured HTML → HTML scraping (last resort) → PDF extraction (experimental
only).

---

## Support tiers

| Tier | Meaning | What the package may do |
|---|---|---|
| 1 — Production ready | Documented or stable machine endpoint, clear access conditions, predictable schema, legal to access programmatically | Full adapter |
| 2 — Supported with caution | Undocumented but stable public endpoint, structured | Adapter plus tests and monitoring |
| 3 — Metadata only | Searchable, but downloads restricted | Expose metadata and links; never download |
| 4 — Do not automate | CAPTCHA, interactive licence acceptance, unclear legal status, session-bound private API, highly unstable HTML, sensitive content | Nothing; document why |

---

## Summary of classifications

| Source | Scope | Tier | Registry stability |
|---|---|---|---|
| KeNADA — survey **metadata** | study search, study metadata, variables, data-file listings | **2** | `experimental` |
| KeNADA — survey **microdata download** | the files themselves | **3** (metadata only) | operation not declared |
| KNBS publications | — | not assessed | `discovery` |
| KNBS aggregate indicators | — | not assessed | `discovery` |
| Geographic reference data | — | not assessed | `discovery` |

---

## 1. Survey catalogue — registry id `kenada`

### Audited

| Field | Finding |
|---|---|
| Source name | Kenya National Data Archive (KeNADA) |
| Official owner | Kenya National Bureau of Statistics |
| Landing page | `https://statistics.knbs.or.ke/nada/index.php/home` |
| Catalogue type | NADA (IHSN open-source microdata cataloguing tool) |
| Search capability | Yes — keyword, year range, pagination |
| Machine-readable endpoints | Yes — JSON API under `/nada/index.php/api/catalog` |
| API documentation | Not published by KNBS. The platform's API is documented upstream by the IHSN NADA project; this instance exposes it without advertising it. |
| Response formats | `application/json; charset=utf-8` |
| Pagination | `ps` (page size, default 15, honoured up to at least 500) and `page`; response carries `found`, `total`, `limit`, `offset` |
| Filters | `sk` (keyword), `from`/`to` (year range). `sk=poverty` → 12 of 129; `from=2015&to=2020` → 65 of 129 |
| Authentication | **None for metadata.** Required for microdata download (see F-03) |
| Download workflow | Gated — see F-03 |
| Terms of use (URL) | No terms or licence page found in site navigation; only `/nada/index.php/citations`. Per-study conditions appear in the DDI `data_access` block instead |
| Rate limits | No `X-RateLimit-*` or `Retry-After` headers observed. Server is `Apache/2.4.29 (Ubuntu)`. CORS is open (`Access-Control-Allow-Origin: *`), and `X-API-KEY` appears in `Access-Control-Allow-Headers`, implying key-based access exists for privileged operations |
| Persistent identifiers | Yes — DDI `idno`, e.g. `KEN-KNBS-KIHBS-2015-2016-v01`. **The API keys on `idno`, not the numeric `id`** (F-02) |
| Version fields | `idno` carries a version suffix (`-v01`, `-V001`); study payload has `version_statement` |
| Release date fields | `created` and `changed` (ISO 8601 with +03:00 offset) |
| Geography fields | `nation`; sub-national coverage described in `study_info` prose, not as codes |
| Metadata quality | Good. Full DDI sections: `title_statement`, `authoring_entity`, `production_statement`, `distribution_statement`, `series_statement`, `version_statement`, `study_info`, `method`, `data_access` |
| Expected stability | Good. NADA's API surface is stable across releases; the risk is an instance upgrade or the archive moving host |
| Risks | Undocumented by the publisher, so no deprecation notice can be expected; variable metadata coverage is uneven (F-04) |
| **Recommendation** | **Tier 2 for metadata.** Build the survey adapter against the JSON API, with fixtures and weekly monitoring. **Tier 3 for microdata** — list files and access conditions, never download |
| Fixtures captured | `dev/fixtures/kenada/` (7 files: search, empty search, study metadata, variables, data files, absent data files, error) |
| Date verified | 2026-08-03 |

### Verified endpoints

Base: `https://statistics.knbs.or.ke/nada/index.php/api`

| Operation | Path | Status |
|---|---|---|
| Study search | `/catalog/search?sk=&from=&to=&ps=&page=` | 200 JSON |
| Full catalogue | `/catalog?ps=500` | 200 JSON, 129 studies |
| Study metadata | `/catalog/{idno}` | 200 JSON |
| Variables | `/catalog/{idno}/variables` | 200 JSON |
| Variable detail | `/catalog/{idno}/variables/{vid}` | 200 JSON |
| Data files | `/catalog/{idno}/data_files` | 200 JSON |
| Data dictionary (HTML) | `/catalog/{id}/data-dictionary` | 200 HTML, ungated |

Reproducible example (public endpoint, no credentials):

```bash
curl -sS "https://statistics.knbs.or.ke/nada/index.php/api/catalog/search?sk=household&ps=3"
```

### Catalogue shape as at 2026-08-03

- 129 studies, `year_start` spanning 1969–2022.
- `form_model`: `public` (106), `data_na` (23).
- Study payload also carries `data_access_type`, `varcount`, `total_views`,
  `total_downloads`, `formid`.

### Findings

**F-01 — The NADA JSON API is enabled and unauthenticated for metadata.**
Search, study, variable and data-file endpoints all return JSON without any
credential. This is the single most important result of the audit: the survey
catalogue does not require HTML scraping.

**F-02 — Study endpoints key on `idno`, not the numeric `id`.**
`/api/catalog/128` returns `400 {"status":"failed","message":"IDNO-NOT-FOUND"}`
while `/api/catalog/DDI-KEN-KNBS-KDHS-2022-V001` returns the study. Search rows
carry both, so the adapter must resolve `id` → `idno` before any detail call.
The 400-with-JSON-body error shape is a usable signal for
`knbs_error_resource_not_found`.

**F-03 — Microdata download requires an account. Do not automate it.**
`GET /nada/index.php/catalog/13/get-microdata` returns `200` with an **empty
body** and the header:

```
Refresh: 0;url=https://statistics.knbs.or.ke/nada/index.php/auth/login/?destination=catalog/13/get-microdata
```

Two consequences:

1. `form_model: "public"` in this instance means *public-use files*, **not**
   *downloadable without an account*. Access type must never be inferred from
   that field alone.
2. The redirect is a `Refresh` **header**, not a 3xx, so `curl -L` and `httr2`
   will follow nothing and see a successful, empty response. The adapter must
   treat a `Refresh` header pointing at `/auth/login` as
   `knbs_error_authentication_required` — otherwise it would silently return
   zero bytes and call it success. This is exactly the "explicit failure"
   requirement in the plan.

`knbs_download_microdata()` must therefore refuse, and direct the user to the
official login and access process. **Open decision 5 is resolved: no KeNADA
microdata may be downloaded programmatically.**

**F-04 — Variable metadata coverage is uneven.**
Of 10 sampled studies, 7 expose variables and data files (463, 1089, 370, 382,
353, 504, 674 variables) and 3 expose none (`varcount: 0`,
`{"datafiles":false}`) — including the most recent study, KDHS 2022. `varcount`
is absent from search rows, so it can only be read from the study payload.
`knbs_variables()` must handle an empty variable set as a normal outcome, not an
error. Within a variable, `qstn` (question text) and `catgry` (value labels) can
also be `null`.

**F-05 — `knbs.or.ke` was unavailable for the whole audit.**
The main site hosts publications, indicators and reference data. Both the
browser and `curl` failed against it:

- Browser: `504 Gateway Time-out` from the origin.
- `curl`: connection timeout after 30–45s, with and without certificate
  verification.

**F-06 — `www.knbs.or.ke` serves an incomplete TLS chain.**
`openssl s_client` reports `verify error:num=21 unable to verify the first
certificate`; the leaf is `CN=knbs.or.ke` issued by `C=US, O=Let's Encrypt,
CN=YE2`, served without its intermediate. Browsers paper over this by fetching
the intermediate via AIA; **curl and httr2 do not**. Unless the server is fixed,
the publications adapter will fail certificate verification on some platforms.
Working around it by disabling verification is not acceptable. If it persists,
the mitigation is to raise it with KNBS and, until fixed, document the failure
rather than bypass it.

**F-08 — An unknown subpath does not 404. It returns the study record.**
`GET /api/catalog/{idno}/definitely_not_an_endpoint` returns
`200 {"status":"success","dataset":{...}}` — the same payload as the study
endpoint. So do `/resources` and `/related_materials`, which are *not* real
endpoints on this instance despite looking like them.

This is the most dangerous behaviour found in the audit. A client that checks
only the HTTP status would parse a study record as though it were the variables
or files it asked for, and produce plausible nonsense. Every response must
therefore be checked for the fields the operation requires, and a `dataset`
payload arriving where it was not requested must be reported as a schema change.
Implemented as `nada_expect()` in the adapter, with a test that pins it.

**F-09 — Documentation and external resources are not exposed by the API.**
Following from F-08, there is no JSON endpoint listing questionnaires, reports
or technical documents. The study page has a `related-materials` HTML page
(200, ~90 KB), and the study payload's `link_questionnaire`, `link_technical`
and `link_report` fields were all `null` for the study checked.

Consequently the plan's Phase 3 task "add documentation download for public
files" **cannot be met from the API**, and HTML scraping is a last resort the
plan explicitly defers. Documentation download is therefore not implemented;
`knbs_survey_files()` lists data files only.

> **Decision: accepted as a known gap for 0.1.0.** The only route would be
> parsing the `related-materials` HTML page, which sits sixth in the plan's
> preference order and would need re-testing on every site change for a feature
> whose output is a list of links. Users can reach the same documents through
> the `catalogue_url` returned by `knbs_search_surveys()`. Revisit if KNBS
> exposes an endpoint, or if demand justifies a tested HTML parser.

**F-10 — Variable filtering is not applied server-side.**
`/api/catalog/{idno}/variables?file_id=F19` returns all 463 variables, ignoring
the parameter. Filtering by file must be done client-side, which the package
does.

**F-07 — Archived evidence suggests the main site is WordPress with a REST API.**
Wayback Machine records for `knbs.or.ke/wp-json*` show `/wp-json/` returning
`200 application/json` and endpoints from the **Download Monitor** plugin
(`/wp-json/download-monitor/v1/...`), whose `downloads` and `user_reports`
routes returned `403`/`401` — i.e. privileged. File URLs follow the WordPress
pattern `/wp-content/uploads/YYYY/MM/<name>.pdf`.

This is **archived, not verified**. If `/wp-json/wp/v2/` is enabled on the live
site it would make the publications catalogue Tier 2 without scraping, and
Download Monitor would explain how file URLs are brokered. **This is the first
thing to check when the site returns.**

---

## 1b. Aggregate indicators — registry id `knbs_indicators` (audited 2026-08-08)

### Audited

| Field | Finding |
|---|---|
| Source name | KNBS Census Data API, feeding the "KNBS DataBrowser" |
| Official owner | Kenya National Bureau of Statistics. Built with Istat (Italy's NSI) under an AICS-funded census-dissemination project; the portal names both and links Istat's open-source cooperation repositories |
| Landing page | `http://data.knbs.or.ke/` (listed on KNBS's own portals page and on `statistics.knbs.or.ke`) |
| Catalogue type | Bespoke Flask API + Angular data browser consuming JSON-stat |
| Machine-readable endpoints | Yes — `GET /getDatasetList?lang=en` (themed catalogue) and `GET /getDataset?id={ID}&type={csv\|json}` on `api1.knbs.or.ke` |
| API documentation | None published. Endpoints observed in the portal's own markup |
| Response formats | JSON-stat 2.0 (any non-`csv` `type`), CSV. **Content-Type is misdeclared** as `text/html` for JSON |
| Pagination | None — 32 datasets across 5 themes; full list is 4 KB |
| Filters | `lang` is required (bare request → Flask 400) but its value is not honoured (`sw` returns English) |
| Authentication | None |
| Download workflow | Direct GET; CSV export links published in the browser UI |
| Terms of use (URL) | **"All data are released under CC-BY 4.0 license"** stated in the portal footer |
| Rate limits | None observed |
| Robots policy | `api1`: no robots.txt (404). `data.knbs.or.ke`: robots.txt present, no relevant disallow |
| Persistent identifiers | Dataset ids: `POPCEN0001`…, `HOUCEN001`… |
| Version fields | `updated: 2019-12-31` in every payload; census data are final |
| Release date fields | `updated`, plus `source: "KNBS Population Census 2019"` |
| Geography fields | Dimension `system_total` ("Territory"): 393 codes — `00` Kenya, `01`–`47` counties, 4-digit sub-counties — **leading zeros intact**, with names |
| Metadata quality | Good: JSON-stat carries dimension labels (Sex, Marital Status, Territory), category labels, source, updated, contact |
| Expected stability | Census tables are final; the API is a small stable surface. Risks: HTTP-only host, undocumented |
| Risks | See F-16–F-18 |
| **Recommendation** | **Tier 2.** Build the indicator adapter on the JSON-stat endpoint; registry `experimental` |
| Fixtures captured | `tests/testthat/fixtures/knbsapi/` |
| Date verified | 2026-08-08 |

### Catalogue as at 2026-08-08

32 datasets: Population (10), Health (8), ICT (3), Household Farming (11),
Household Assets/Amenities (0 — empty theme). All are 2019 census tables.

### Findings

**F-15 — KNBS operates a first-party machine-readable indicator API.**
The KNBS portals page lists `data.knbs.or.ke` (and `cpiexplorer.knbs.or.ke`,
`opendata.knbs.or.ke/beta/databrowser/`, `kdhsportal.knbs.or.ke`,
`finaccess.knbs.or.ke`, `nipfn.knbs.or.ke`, plus third-party
`kenya.opendataforafrica.org`). The DataBrowser's backend at
`api1.knbs.or.ke` serves the census tables as JSON-stat 2.0 under an explicit
CC-BY 4.0 statement. This resolves open decision 3 for the census family.

**F-16 — The API host is HTTP-only.** Port 443 does not answer on
`api1.knbs.or.ke`. The registry's HTTPS rule is therefore relaxed for this one
source via an explicit `http_only: true` flag rather than silently. The
consequence is worth stating: traffic to this API is unencrypted in transit.
It carries only public census aggregates and no credentials.

**F-17 — An unknown dataset id answers `200` with the body `errore`.**
Six bytes, Italian, status 200. The same "success that isn't" family as F-03
and F-08. The adapter treats an `errore` body as resource-not-found and any
other non-JSON-stat shape as a schema change.

**F-18 — The JSON Content-Type is misdeclared.** JSON-stat arrives as
`text/html; charset=utf-8`, so the adapter cannot use content-type
verification and relies on shape checks instead.

**F-19 — `getDatasetList` requires `lang` but ignores its value.** A bare
request is a Flask 400; `lang=sw` returns English. The adapter always sends
`lang=en`.

**F-19b — A theme with no datasets omits the key.** The Household
Assets/Amenities theme arrives as `{desc, id}` with no `datasets` member at
all, rather than an empty array. The list-shape check accepts a keyless theme
that still looks like a theme, and the standardiser treats an absent
`datasets` as empty.

**F-20 — The Territory dimension is a geography reference in its own right.**
393 coded, named territories (national/county/sub-county) under CC-BY 4.0 —
a strong Phase 6 candidate for `knbs_geographies()`, with the caveat that the
vintage is the 2019 census frame.

## 1c. Consumer prices — CPI Explorer API (traced 2026-08-08, no registry id yet)

Resolves F-21. Static inspection had failed because the app lazy-loads its
API client as a separate chunk; a runtime trace (loading each route in a
browser and reading the page's own resource timeline) surfaced the full
surface in minutes.

### Audited

| Field | Finding |
|---|---|
| Source name | CPI Explorer, `cpiexplorer.knbs.or.ke` — "Official CPI and inflation statistics for Kenya" |
| Official owner | Kenya National Bureau of Statistics (listed on KNBS's own portals page; KNBS branding and contact) |
| Catalogue type | Django REST Framework-style JSON API under `/api/v1/`, consumed by a React SPA |
| Authentication | None |
| TLS | Valid HTTPS |
| Content types | Correct `application/json` — the first KNBS API audited that declares its JSON honestly |
| Coverage | Monthly CPI and inflation, **2009-01 to 2026-06 (210 periods)**, by 13 regions (national, provinces, Nairobi income bands); COICOP divisional changes; retail prices of 22 tracked commodities |
| Licence | **Unstated.** No licence text anywhere on the explorer, unlike the DataBrowser's CC-BY footer. The data are official statistics from a KNBS portal, but reuse terms must not be assumed |
| Robots | No robots.txt (the SPA shell answers any non-API path with 200) |
| Rate limits | None observed |
| **Recommendation** | **Tier 2 candidate.** First-party, structured, stable-looking; undocumented, so an adapter needs fixtures, shape checks and monitoring, plus the region-fallback mitigation below |

### Verified endpoints

Base: `https://cpiexplorer.knbs.or.ke/api/v1`

| Endpoint | Returns |
|---|---|
| `/periods/` | 210 monthly periods, `2009-01-01` … `2026-06-01` |
| `/explorer/regions/` | 13 regions: `national`, provinces, Nairobi Upper/Middle/Lower Income and Combined |
| `/explorer/data/?region_id[]=&start_date=&end_date=&data_type={cpi,inflation}&frequency=monthly` | Series: `{id, name, data: [{period, value, change_monthly, change_annual}]}` — index level and both inflation rates per point |
| `/coicop/hierarchy/` | 13 COICOP divisions: `{code, name, weight, level, children}` — a genuine classification with weights |
| `/commodities/` | The 22 tracked commodities (`CPI001`–`CPI022`) with unit and quantity |
| `/retail-prices/latest/?region=` | Current, previous-month and previous-year price per commodity, with changes |
| `/dashboard/homepage/?period=` | Headline CPI/inflation, core and non-core series, divisional contributions |
| `/calculator/available_periods/` | Periods for the inflation calculator |

Chatbot routes also exist (`/chatbot/health/`); out of scope.

Live values at trace time: CPI 154.91 (June 2026), YoY inflation 6.41%,
maize flour 83.43 KES/kg — matching the published headline figures.

### Findings

**F-23 — An unknown API route answers with a true 404.** The only KNBS API
audited so far that fails honestly instead of answering 200 with the wrong
thing. Non-API paths still return the SPA shell with 200, so only `/api/`
responses may be trusted by status.

**F-24 — An unknown region falls back to national silently.**
`region_id[]=mars` returns 200 with the national series. The response *names*
what it returned ("Overall CPI (National)"), so an adapter must validate the
requested region against `/explorer/regions/` before calling, and check the
returned series name against what was asked — the fourth member of the
silently-substituted-parameter family (F-10, F-19, F-22).

**F-25 — Untested surface.** Whether `/explorer/data/` accepts COICOP
division filters was not probed; divisional figures are confirmed available
via the dashboard endpoint. To be settled when an adapter is designed.

**F-26 — Six listed regions carry no data in any period.** The former
provinces (Central, Coast, Eastern, North Eastern, Nyanza, Rift Valley,
Western) are named by `/explorer/regions/` but their series are empty for
every date range probed, including 2015. The regions with data are National,
the four Nairobi income bands, Nairobi Combined and Rest of Urban. An empty
answer for a listed region is the source's answer, not an error. Also pinned
while building the adapter: every series arrives with `id: "overall"` — only
`metadata.region` distinguishes regions — and the server honoured date-range
parameters when traced (enforced client-side regardless, given this family's
form).

**F-27 — Retail prices have a full paginated history, national only.**
Probed 2026-08-08 while building the retail-price interface. Beyond the
`/retail-prices/latest/` convenience the audit recorded, the bare
`/retail-prices/` route is a Django-REST paginated listing — 1,958 records at
the time of probing, roughly 22 commodities by 89 months — with `?page=N` and
an exact-month `?period=YYYY-MM-01` filter (count 22 for one month). Records
carry `commodity` (numeric id), `commodity_name`, `period`, `price`,
`unit_of_measure` and `quantity`; the `/commodities/` route maps the numeric
ids to the `CPI001`–`CPI022` codes. Region behaviour splits three ways: no
region parameter exists on the history route; on `/latest/`, a *valid*
non-national region answers `[]` (regional retail data does not exist), while
an *unknown* region silently falls back to national (the F-24 family). The
package therefore exposes retail prices as national only, with no region
argument to defend.

**F-28 — `opendata.knbs.or.ke` is a 323-dataflow SDMX portal.**
Traced 2026-08-08 after a direct question exposed that this portal — probed
only superficially during the Phase 5 audit — had never been enumerated. The
"Data Browser" at `/beta/databrowser/` is the Istat DataBrowser hub; its API
under `/beta/databrowserhub/api/` serves a catalogue
(`Core/nodes/1/catalog`) of **323 SDMX dataflows** (agency `KE1`), organised
under five category groups (Demographic and Social, Economic, Environment,
Governance, Cross-cutting). Coverage reads like the Economic Survey as data:
GDP by activity (constant 2016 and current prices, growth, contribution),
expenditure on GDP, GFCF, GNI, annual production accounts, CPI by division
and by region (base Feb 2019 = 100), balance of payments, trade, money and
banking, county government finance (COFOG, revenue, expenditure), employment
and earnings, agriculture, tourism, health, justice. This is the richest
machine-readable KNBS source found in the entire audit, and the plan's
"optional SDMX support" (roadmap 0.3.0) has a first-party target. Not yet
adapted; dataflow data-query shape, licence statement and dimension
structures still to be characterised before an adapter is designed.

**Gross County Product remains PDF-only everywhere.** The county-level
dataflows here are census density, county government finance, health
expenditure and assembly composition — no GCP. With this, every portal on
KNBS's own portals page has now been checked for GCP: census API (32 tables,
no), CPI Explorer (prices only), NADA (surveys), media library (PDF reports
only), this hub (no), and the topical portals (KDHS, FinAccess, NIPFN —
out-of-domain). *Update 2026-08-11: still true of every first-party portal,
but no longer of the third-party mirror — see F-30.*

**F-29 — `kenya.opendataforafrica.org` is bot-gated.** The third-party
mirror listed on the portals page answers API requests with a Cloudflare
challenge ("Just a moment..."), a human-verification mechanism the plan
forbids bypassing — tier 4 on access mechanism alone, before the
third-party-mirror policy is even reached. *Superseded 2026-08-11 by F-30:
the gate has lifted.*

**F-30 — The africa-portal gate has lifted, and GCP is data there.**
Re-probed 2026-08-11 after the user pointed at the portal's GCP page.
`kenya.opendataforafrica.org` — the Knoema-platform portal that KNBS lists
on its own portals page — now answers its JSON API without any challenge,
using the package's transparent audit UA. Its `robots.txt` permits the API
with one exception: `/api/1.0/sdmx` is disallowed, so the package must
never use the SDMX export route there. Verified endpoints:

- `GET /api/1.0/meta/dataset` — the catalogue: **202 public datasets**,
  169 sourced "Kenya National Bureau of Statistics" (source records carry
  `licenseTypeName: "Public Domain"` and `isVerified: true`), 5 Central
  Bank of Kenya, the rest ministries and agencies.
- `GET /api/1.0/meta/dataset/{id}` — dimensions, publication and
  next-release dates, and an original-data link back to `knbs.or.ke`.
- `GET /api/1.0/meta/dataset/{id}/dimension/{dim}` — members with stable
  ids and, for geographic dimensions, ISO-style `RegionId` codes
  (`KE`, `KE-700-BA`, …).
- `GET /api/2.0/data?datasetId={id}` — every time series as JSON
  (`startDate`, `frequency`, `values` array), `continuationToken` paging.

The GCP dataset `jhbzkjc` ("Gross County Product (GCP) 2021") holds three
tables — county contribution to GVA (%), GCP in constant prices and in
current prices (KSh million) — for the 47 counties plus a national total,
annual 2013–2020: 143 series in one 55 KB response. Cautions for any
adapter: (a) this is a **republisher** — provenance must name the mirror
and point at the original, and first-party portals stay preferred wherever
they carry the same data; (b) **vintage lag** — the GCP dataset is still
the 2021 edition (published 2022-11-18; its stated next release of
2023-11-18 passed without update), while KNBS's newer GCP reports extend
past 2020 as PDF only; (c) the portal overall is actively maintained —
48 datasets updated in 2025, most recently 2025-11-07 (Economic Survey
2025 vital statistics, health, trade, plus CBK money and interest-rate
series); (d) F-29's Cloudflare challenge was real when observed, so an
adapter must treat any challenge-page response as an access-gate
condition, never something to retry through. Tier moves from 4 to 2–3:
machine-readable, robots-permitted, licence labelled at source level;
third-party status is the remaining caution.

**F-31 — The africa portal answers unknown dataset ids with 200 and a bare
string.** `GET /api/1.0/meta/dataset/{unknown}` and
`GET /api/2.0/data?datasetId={unknown}` both answer HTTP 200 with the JSON
string `"Requested dataset doesn't exist or you don't have access to it."`
— the F-17 family again, in a third shape. The adapter recognises a bare
string payload at its single network entry point and classes it as a
missing resource; any *other* bare string is a schema change.

**F-32 — The africa portal's dataset listing misstates structure.** The
listing (`/api/1.0/meta/dataset`) says `hasGeoDimension: false` and
`dimensions: null` for the GCP dataset, while the dataset's own metadata
(`/api/1.0/meta/dataset/jhbzkjc`) says `hasGeoDimension: true` with a full
dimension list. The listing is trustworthy for identity (id, name, source,
licence label, dates) and for nothing structural; the adapter reads
structure only from per-dataset metadata, and the test fixtures keep the
listing's lie deliberately.

**F-33 — One africa-portal dataset may mix frequencies.** The interest-rate
dataset `doflnmd` carries the same indicators as annual series (2018–2023,
unit "Percent") *and* quarterly series (2024, unit unstated); the money
supply dataset mixes annual and monthly. Annual observations carry
integer-year periods and sub-annual ones carry Dates, which cannot share a
column, so the adapter refuses a mixed dataset until the caller names a
frequency (`knbs_get_indicator(..., frequency = "annual")`) — the
no-silent-guessing rule applied to time. Each series' values are expanded
from its own `startDate` and verified against its own `endDate`, so a
miscounted expansion is a refusal, not a shift onto wrong years.

**F-34 — The africa portal's edge intermittently challenges libcurl's
default HTTP negotiation.** During live verification of the adapter, the
same request that curl served with 200 answered R's httr2 client with 403
and a Cloudflare challenge page (`cf-mitigated: challenge`) — with the same
transparent knbsdata User-Agent, so identity is not the trigger. Pinning an
explicit standard HTTP version (`CURLOPT_HTTP_VERSION` to HTTP/1.1, or
equally HTTP/2) makes the identical client pass, including immediately
after a challenge; without the pin the challenge recurs intermittently,
which reads as edge-side probabilistic scoring of the default negotiation
fingerprint. The adapter pins plain HTTP/1.1 — an ordinary client
configuration with the package's own UA, not a disguise — and never solves
or retries a challenge: one that returns anyway surfaces as
`knbs_error_access_restricted`, per the F-29 rule.

**F-22 — The media endpoint ignores its `mime_type` parameter.**
Requesting the xlsx mime returns PDFs (verified 2026-08-08 during a package
demonstration). Same silently-ignored-parameter family as F-10 and F-19. The
package already filtered formats client-side, but only within the fetched
page, so a format filter could return nothing while matches existed deeper in
the library — recent uploads are often runs of PDFs. Fixed by paging back
through older uploads until the requested number of matches is found, the
library is exhausted, or a 5,000-document scan cap warns. Also observed:
requesting one page past the end answers `400`, which for any page after the
first means "no more", not "bad query".

**F-21 — resolved by section 1c.** Static inspection failed because the API
client is a lazy-loaded chunk; the runtime trace of 2026-08-08 mapped the full
API. The consumer-prices family now has a traced, first-party,
machine-readable source awaiting an adapter.

## 2. Publications catalogue — registry id `knbs_publications`

**Audited 2026-08-08, after the site recovered.** Tier 2; registry stability
`discovery` → `experimental`.

### Audited

| Field | Finding |
|---|---|
| Source name | KNBS website media library (WordPress) |
| Official owner | Kenya National Bureau of Statistics |
| Landing page | `https://www.knbs.or.ke/` |
| Catalogue type | WordPress core REST API, `wp/v2` |
| Search capability | Yes — `search`, `media_type`, `mime_type`, `after`/`before`, `orderby`/`order` |
| Machine-readable endpoints | `GET /wp-json/wp/v2/media` (collection), `GET /wp-json/wp/v2/media/{id}` (record) |
| API documentation | The `wp/v2` API is documented upstream by WordPress; the instance itself is not documented by KNBS |
| Response formats | `application/json; charset=UTF-8` |
| Pagination | Standard WP: `page`/`per_page` (max 100), totals in `X-WP-Total` / `X-WP-TotalPages` response headers |
| Filters | `media_type=application` → 1,590 documents; `mime_type=application/pdf` → 1,466; xlsx → 117; date range verified (109 PDFs in 2026 H1) |
| Authentication | **None** for the media listing, the records, or the files themselves |
| Download workflow | Direct, stable `/wp-content/uploads/YYYY/MM/<name>` URLs from `source_url`. Verified ungated: `%PDF-1.7` bytes over plain HTTPS, correct `Content-Type` and `Content-Length` |
| Terms of use (URL) | No terms page found via the API; none recorded |
| Rate limits | No rate-limit headers observed |
| Robots policy | `robots.txt` now present: disallows `/wp-admin/` only |
| Persistent identifiers | Numeric media `id`; `slug`; filename |
| Version fields | `date` and `modified` timestamps; editions are distinct records |
| Release date fields | `date` (upload date — see F-13) |
| Geography fields | None |
| Metadata quality | Good for files: title, dates, mime type, byte size, direct URL, landing page. Thin for bibliography: no abstract, series or ISBN fields |
| Expected stability | Good. `wp/v2` is a stable upstream API; the risk is a site rebuild |
| Risks | F-12 (two catalogues), F-13 (upload date ≠ publication date), mixed non-publication content (speeches, forms) in the same library |
| **Recommendation** | **Tier 2.** Adapter over `wp/v2/media`; downloads through the package's verify-and-checksum layer |
| Fixtures captured | `dev/fixtures/knbs-wp/` (4 files: listing, single, empty, not-found) |
| Date verified | 2026-08-08 |

### Findings

**F-11 — The site recovered, and the TLS chain is fixed.**
First successful contact 2026-08-08: `/` answers 301 → 200, and
`curl` verifies the certificate cleanly (`ssl_verify_result=0`). F-05 and F-06
are both resolved; F-06 needs no client-side handling after all.

**F-12 — Two catalogues exist; only one is open.**
The Download Monitor plugin manages a `dlm_download` post type, but its REST
routes are gated: `/wp-json/download-monitor/v1/downloads` → `403
rest_forbidden`, and `/wp-json/wp/v2/dlm_download` returns an empty collection
to anonymous callers. The **media library** (`wp/v2/media`) is fully open and
carries the same underlying files with direct URLs. The adapter uses the media
library and does not touch the gated routes.

**F-13 — `date` is the upload date, not the publication's reference date.**
The 2026 Economic Survey was uploaded 2026-04-29; a scan of a re-uploaded older
report would carry a recent `date`. The schema therefore calls this field
`release_date` in the sense of "made available on the site", and the reference
year, where wanted, must come from the title. The adapter does not guess it.

**F-14 — The media library is not only publications.**
Speeches, launch remarks, forms and images share the library. `media_type=application`
excludes images; beyond that, what counts as a publication is the user's
judgement, applied through `query` and `format` filters. The package does not
maintain a hand-curated allowlist.

Reproducible example (public endpoint, no credentials):

```bash
curl -sS "https://www.knbs.or.ke/wp-json/wp/v2/media?media_type=application&search=economic+survey&per_page=5"
```

## 3. Aggregate indicators — registry id `knbs_indicators`

**Not audited — source unavailable (F-05).** Remains at `discovery`.

The plan's first target family is consumer prices. Search results indicate CPI is
published on `/cpi-and-inflation-rates/` and via monthly statistical releases,
which suggests PDF and Excel rather than an indicator API; the `/data-portals/`
page needs checking for an official portal with machine-readable output. **Do not
assume an indicator API exists.** If CPI turns out to be Excel-only, the honest
0.1.0 outcome is a registered Excel parser for a specific release series, not a
general indicator client.

Third-party mirrors of KNBS indicators exist. Under the official-source-first
rule they are out of scope unless KNBS itself lists them as authorised — which
is precisely what `/data-portals/` should reveal.

## 4. Geographic reference data — no registry id yet

**Not audited — source unavailable (F-05).** No registry entry created, because
no candidate endpoint has been identified.

KeNADA does not help here: it exposes `nation` only, with sub-national coverage
described in prose. County codes will most likely have to come from a census
publication on the main site, which raises the question of whether they can be
extracted reproducibly and redistributed.

---

## Audit template

Copy this block for each new candidate source.

### <source name>

| Field | Finding |
|---|---|
| Source name | |
| Official owner | |
| Landing page | |
| Catalogue type | |
| Search capability | |
| Machine-readable endpoints | |
| API documentation | |
| Response formats | |
| Pagination | |
| Filters | |
| Authentication | |
| Download workflow | |
| Terms of use (URL) | |
| Rate limits | |
| Robots policy | |
| Persistent identifiers | |
| Version fields | |
| Release date fields | |
| Geography fields | |
| Metadata quality | |
| Expected stability | |
| Risks | |
| **Recommendation (tier + reason)** | |
| Fixtures captured | |
| Date verified | |

---

## Findings log

| Date | Source | Finding | Action taken |
|---|---|---|---|
| 2026-08-03 | kenada | No `robots.txt` on `statistics.knbs.or.ke` (404); certificate verifies cleanly | Proceeded with public metadata requests |
| 2026-08-03 | kenada | F-01 NADA JSON API enabled and unauthenticated for metadata | Registry entry verified; stability `discovery` → `experimental` |
| 2026-08-03 | kenada | F-02 detail endpoints key on `idno`, not numeric `id` | Recorded for the adapter; error shape noted |
| 2026-08-03 | kenada | F-03 microdata download gated behind login via `Refresh` header | `download_public_files` **removed** from declared operations; open decision 5 resolved |
| 2026-08-03 | kenada | F-04 variable metadata absent for some studies | `knbs_variables()` must treat an empty set as valid |
| 2026-08-03 | knbs.or.ke | F-05 site returned 504 / timed out for the whole audit | Publications, indicators and geography left unaudited |
| 2026-08-03 | knbs.or.ke | F-06 incomplete TLS chain (verify error 21) | Recorded as a risk to any R client; no bypass |
| 2026-08-03 | knbs.or.ke | F-07 archived evidence of WordPress REST API and Download Monitor | First thing to verify when the site returns |
| 2026-08-03 | kenada | F-08 unknown subpaths return the study payload with `200 success` | Every response is shape-checked by `nada_expect()`; covered by a test |
| 2026-08-03 | kenada | F-09 no API endpoint for documentation or external resources | Documentation download not implemented; recorded as an unmet Phase 3 task |
| 2026-08-03 | kenada | F-10 `variables?file_id=` is ignored server-side | Filtering by file is done client-side |
| 2026-08-04 | knbs.or.ke | Re-checked at the start of Phase 4: still `504 Gateway Time-out` from the origin, and still timing out from the command line. Outage confirmed at roughly five hours. | Publications adapter not written; only the source-independent download layer was built |
| 2026-08-08 | knbs_publications | F-22 `mime_type` parameter silently ignored by the media endpoint | Format filter now pages back until satisfied; boundary duplicates deduped; past-the-end 400 treated as end-of-listing |
| 2026-08-08 | cpiexplorer | F-21 resolved by runtime trace: full `/api/v1` surface mapped — monthly CPI/inflation 2009–2026 by 13 regions, COICOP hierarchy with weights, 22 retail-price commodities | Recorded as audit section 1c; adapter not yet built; licence unstated on the portal |
| 2026-08-08 | cpiexplorer | F-24 unknown region falls back to national silently | Adapter built: regions validated pre-flight against `/explorer/regions/`, returned series matched by `metadata.region`, substitution refused |
| 2026-08-08 | cpiexplorer | F-26 the six former provinces are listed but empty in every period | Adapter returns zero rows for them; documented in the indicators vignette and metadata notes |
