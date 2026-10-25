# WWW-Forgejo House Rules

The shared house rules come from skilletor — bundle `getty-cpan-dist@getty`: engineering
discipline, the delegation lock, the publish gate, karr coordination, CPAN release. They load
as `.claude/rules/.local.*.md`; if they are missing, run `skilletor sync` and publish nothing
until they load. This file adds what is true only here, and wins where it differs.

## What this repo is

Perl client for the Forgejo API v1, and the semantics owner for the async sibling
`Net::Async::Forgejo`. Read first: the group controller, the `Entity` it returns, and the
`Role::HTTP` verb / `_build_request` / `_parse_response` methods being used.

## Agent team

| Task | Agent |
|---|---|
| Implement / refactor / debug behavior-relevant code | `www-forgejo-worker` (default) |
| Commits, `Changes`, card → done, pre-release audit | `www-forgejo-release-manager` |
| Read-only research, audit, gap analysis | `www-forgejo-worker` ("read-only, change nothing") |

Behavior-relevant = runtime behavior, the public API surface (controllers + Entities), the
transport seam (`Role::HTTP` / `Role::IO` / `LWPIO`), `_build_request` / `_parse_response`, the
`HTTPRequest` / `HTTPResponse` value objects, auth, error handling, tests. Pure prose docs and
Changes notes are not.

## Release coupling — Net::Async::Forgejo, released together

The sibling **`Net::Async::Forgejo`** (local checkout `../p5-net-async-forgejo`) is a thin async
transport that reuses this repo's `_build_request` / `_parse_response` and value objects. They
ship as **one coordinated release** — the sibling requires `WWW::Forgejo` and its tests
`use lib '../p5-www-forgejo/lib'`. A CPAN-release lag on either side is never a blocker and
never a ticket.

## Hazards

- **The seam is shared.** Keep the two seam methods and the `HTTPRequest` / `HTTPResponse`
  shapes stable; a change to either is a paired, ticketed change. Cross-repo work is a karr
  ticket on the sibling's board — you cannot touch `p5-net-async-forgejo` from here.

## Perl / Moo specifics — reference, don't restate

Module loading, the Moo `has`/`with`/`namespace::clean` patterns, cpanfile pinning, the client
architecture and transport seam, and dist.ini/release conventions live in skills
`www-forgejo-core`, `getty-perl-moo`, `getty-perl-core`, and `perl-release-dist-ini`
(force-loaded for `www-forgejo-*` agents).
