# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Perl Rules

**MANDATORY: load the `perl-core` skill via the Skill tool before editing any Perl code in this workspace.** It encodes Getty's house rules (module loading, Moose patterns, cpanfile versioning for Getty-authored CPAN distributions, style). The rules below are the TL;DR — the skill has the full list and rationale.

- **`use Module;`** to load modules. `require` only when you absolutely know why (runtime plugin loading, not just "I want lazy").
- **Never copy a `$VERSION` from a Getty-authored repo into a cpanfile** — repo is the next unreleased version. Check `cpanm --info` for the actual released version. Every Getty-authored dependency must be pinned to its latest released CPAN version.

## Workspace Overview

This is a Perl CPAN distribution for the Forgejo API v1.

## Build System

Uses **Dist::Zilla** for building and releasing to CPAN.

### Standard Commands

```bash
dzil build          # Build the distribution
dzil test           # Run tests
dzil release        # Release to CPAN
```

## Skills

This project includes shared skills via `.claude/skills/`:

- `create-perl-distribution` - Scaffold new Perl CPAN distributions
- `perl-ai-proxy-skeid` - Langertha::Skeid LLM proxy integration