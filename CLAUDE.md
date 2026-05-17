# WWW::Forgejo

Perl client for the Forgejo API v1.

## Inspiration

Based on the pattern of [WWW::Hetzner](../p5-www-hetzner/).

## Important

- **No CLI** — Forgejo ships its own `forgejo` CLI.
- 304 endpoints, primarily /repos, /user, /orgs, /admin, /users
- Auth: Bearer Token (`Authorization: token <PAT>`)
- Base URL: `https://<host>/api/v1`