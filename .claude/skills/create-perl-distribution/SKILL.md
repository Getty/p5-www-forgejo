---
name: create-perl-distribution
description: Scaffold a new Perl CPAN distribution following the [@Author::GETTY] conventions — dist.ini, cpanfile, Changes, README.md, lib/, t/, .gitignore. Loaded automatically by create-software when a Perl project is detected; also callable directly for polishing existing dists.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# create-perl-distribution

Create or polish a Perl distribution matching Getty's workspace conventions.

## Inputs the skill expects to resolve before writing

| What | Resolution order |
|---|---|
| `dist`      | dash-form (`WWW-Foo`) — from user arg or from dir name under `~/dev/perl/p5-*` |
| `module`    | colon-form (`WWW::Foo`) — derived from `dist` by `s/-/::/g` |
| `abstract`  | one-line `# ABSTRACT:` from the first non-empty existing `lib/**/*.pm`, else ask |
| `author`    | `Torsten Raudssus <getty@cpan.org>` |
| `copyright_holder` | `Torsten Raudssus <torsten@raudssus.de> L<https://raudssus.de/>` |
| `copyright_year`   | current year |
| `license`   | `Perl_5` |
| `irc`       | search sibling `~/dev/perl/p5-*/dist.ini` for an existing `irc =` line in the same topic cluster; if none found, ask the user (never make one up) |

## Sibling reference

Before writing, read **one** existing sibling dist that is closest in topic
(e.g. for `p5-www-openbao` look at `~/dev/perl/p5-www-firecrawl/` because both
are HTTP-client WWW-* packages). Match its layout exactly:

- `dist.ini`
- `cpanfile` (split `on test` / `on develop` if the sibling does)
- `Changes` (`{{$NEXT}}` marker + one `0.001` entry with a bullet list)
- `README.md` (Synopsis → Description → one example per public method → License)
- `.gitignore` (copy sibling's, substituting the dist name in the build-dir ignore line)
- `t/00-load.t` using `Test::LoadAllModules` OR `use_ok` — match what the sibling uses
- Any additional `t/NN-*.t` the author convention calls for (often `10-*`, `20-*` topical tests)

Do NOT diverge from the sibling's style even if it feels outdated. Workspace
consistency beats "modern best practice."

## Templates

Fallback templates (used only when no suitable sibling exists) live at
`~/.claude/skills/create-software/templates/perl-distribution/`:
`dist.ini`, `cpanfile`, `Changes`, `README.md`, `lib_Module.pm`, `t_00-load.t`,
`t_01-basic.t`. Placeholders use `{{$name}}` — substitute with `sed` or
equivalent. Rename `lib_Module.pm` → `lib/<Path>/<Name>.pm` and
`t_*.t` → `t/*.t`.

## Handcheck rules

- Author line must be `getty@cpan.org` — only the CPAN email, no name
  with valid email + website. Refuse to fabricate either.
- Copyright year in `dist.ini` and `Changes` must match.
- IRC channel is optional but, if included, must be a real channel. Ask rather
  than invent.
- Never write `our $VERSION = ...` into `lib/*.pm` — `[@Author::GETTY]` injects
  it from the Changes file.

## After writing

Run `dzil test` inside the dist directory and surface the output. Do NOT
`dzil release` unless the user explicitly asks.

## Related

- `create-software` — parent orchestrator; loads this skill for Perl projects.
- `perl-release-dist-ini` — loaded when *editing* an existing `dist.ini`.
- `perl-release-author-getty` — loaded when *releasing*.
- `perl-core` — Getty's house Perl style rules.
