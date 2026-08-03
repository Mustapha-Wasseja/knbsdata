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

## 2. Publications catalogue — registry id `knbs_publications`

**Not audited — source unavailable (F-05).** Remains at `discovery`.

Known page paths (from search engine results, unverified against the live site):
`/statistical-releases/`, `/economic-surveys/`, `/reports/{slug}/`,
`/cpi-and-inflation-rates/`, `/knbs-downloads/`, `/data-portals/`, `/new/`.

When the site returns, check in this order:

1. `GET /wp-json/wp/v2/types` and `/wp-json/wp/v2/posts?per_page=5` — is the
   core REST API enabled, and are publications a custom post type?
2. Whether publication files are direct `/wp-content/uploads/...` URLs or are
   brokered through Download Monitor (which may count, redirect or gate).
3. Whether release date and edition are exposed as metadata or only in prose.
4. Whether stable identifiers exist beyond the filename.
5. `robots.txt` — it could not be retrieved during this audit.

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
