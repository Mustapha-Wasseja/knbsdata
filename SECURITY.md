# Security policy

## Reporting a vulnerability

Please report security issues privately to <muswaseja@gmail.com> rather than in
a public issue. Include the affected version, what an attacker could do, and a
reproducible example if you have one. You can expect an acknowledgement within
seven days.

## What counts as a security issue here

`knbsdata` is a data-access client, so the sensitive surfaces are files, URLs
and credentials rather than a running service:

- Path traversal when extracting archives (ZIP entries escaping the destination
  directory).
- Writing downloaded files outside the requested destination.
- Credentials, tokens or cookies appearing in logs, error messages, cache
  metadata, download manifests or test fixtures.
- Following a redirect to an unexpected host and treating the result as
  official.
- Code execution triggered by parsing a downloaded file.
- Silently bypassing an access control, licence acceptance or authentication
  step.

The last item matters as much as the others: the package must never obtain data
a user is not authorised to obtain.

## Handling secrets in this repository

- Never commit credentials, tokens, cookies or `.Renviron` files.
- Never store secrets in the source registry, package options persisted to disk,
  error logs, download manifests or test fixtures.
- Redact personal and authentication information from any stored response
  fixture before committing it.
- If a secret is committed, treat it as compromised: rotate it first, then
  remove it from history.
