# KNBS source audit

Status: **not started.** This file is the Phase 1 deliverable. Until a source is
audited here, it stays at stability `discovery` in
`inst/extdata/source-registry.yml` and no adapter may be written for it.

- **Last updated:** 2026-08-03
- **Auditor:** —

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

## Audit template

Copy this block for each candidate source.

### <source name>

| Field | Finding |
|---|---|
| Source name | |
| Official owner | |
| Landing page | |
| Catalogue type (NADA, CKAN, DKAN, bespoke, static files) | |
| Search capability | |
| Machine-readable endpoints | |
| API documentation | |
| Network requests triggered by the site | |
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

## Candidate sources

### 1. Survey catalogue — registry id `kenada`

Expected to be the Kenya National Data Archive. **Not yet audited.**

Key questions for this source:

- Is it NADA-based? If so, which version, and is its documented API enabled?
- Does study, variable and file metadata come from one endpoint or several?
- Is variable-level metadata exposed without downloading microdata?
- What are the access types per study, and how are they signalled in metadata?
- Is any public-use microdata downloadable without an interactive licence
  acceptance step? If acceptance is interactive, this is tier 3 at best.

### 2. Publications catalogue — registry id `knbs_publications`

**Not yet audited.**

Key questions:

- Is there a listing endpoint, a feed, or only paginated HTML?
- Are publication files served from stable URLs, or from a redirecting
  download handler?
- Is release date exposed as metadata or only in the document?
- Are there stable identifiers, or only filenames?

### 3. Aggregate indicators — registry id `knbs_indicators`

**Not yet audited.** The plan's first indicator family is consumer prices.

Key questions:

- Is there an indicator portal with JSON/CSV/SDMX output, or are indicators only
  published inside Excel workbooks and PDF releases?
- Are base year, unit and frequency exposed as metadata?
- Are revisions and vintages identifiable, or is only the latest release
  available?
- Is there a county-level breakdown, and on which geographic vintage?

### 4. Geographic reference data — no registry id yet

**Not yet audited.**

Key questions:

- What is the authoritative published list of county codes and names?
- Which vintage does it correspond to, and are historical codes documented?
- Are boundary files officially published, and under what licence? Boundaries
  are only implemented once reuse rights are confirmed.

---

## Findings log

| Date | Source | Finding | Action taken |
|---|---|---|---|
| | | | |
