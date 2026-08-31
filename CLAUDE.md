# WWW::Forgejo

Synchronous Perl client for the Forgejo API v1. `Moo`-based; `WWW::Forgejo`
`with 'WWW::Forgejo::Role::HTTP'` and exposes lazy API-group accessors that return
`WWW::Forgejo::Entity::*` objects. It owns all Forgejo semantics (paths, `token` auth,
JSON, errors, endpoints); the HTTP transport is pluggable behind `Role::IO` (default
`LWPIO`). It is the semantics owner for the async sibling `Net::Async::Forgejo`
(`../p5-net-async-forgejo`), with which it is released in lockstep.

## Build / test

```bash
prove -l t/     # offline suite; t/9x-live-*.t self-skip without TEST_FORGEJO_URL/TOKEN
dzil test       # full distribution ([@Author::GETTY] bundle)
dzil build
```

## Delegation

Delegate behavior-relevant code to the right agent instead of touching it yourself —
principle and lane are in `.claude/rules/www-forgejo-rules.md`.

| Task | Agent |
|---|---|
| Implement / refactor / debug behavior-relevant code | `www-forgejo-worker` (default) |
| Pre-release audit | `www-forgejo-release-checker` |

The agents carry their skills via `briefing.skills` (see `.claude/agents/`); the main
agent delegates rather than loading them. Skill sources live under `.claude/skills/`
(`www-forgejo-core` plus hardlinked shared skills). House rules and the delegation lock:
`.claude/rules/www-forgejo-rules.md`.
