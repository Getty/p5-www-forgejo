# create-software

**Master orchestrator for ALL software project creation.** Auto-detects language/framework and scaffolds complete project structure with proper `.gitignore`, build config, and standards.

**Keywords:** gitignore, .gitignore, create project, new module, scaffold, init, perl distribution, node.js, python, go, create-perl-distribution, cpanfile, dist.ini, package.json, pyproject.toml, go.mod, README, Changes, setup, initialization, project bootstrap

**Scope:** Perl distributions ([@Author::GETTY]), Node.js apps, Python packages, Go projects, gitignore generation, full project scaffolding, multi-language projects

## Skill Scope

This skill handles **all new software project creation**:
- Perl distributions with [@Author::GETTY] standards (dist.ini, README, Changes, cpanfile, lib/, t/)
- Node.js/JavaScript projects (.gitignore, package.json setup)
- Python packages/projects (.gitignore, venv setup, pyproject.toml)
- Go binaries (main.go, .gitignore, module structure)
- Generic projects (.gitignore with auto-detected templates)
- Multi-language monorepos

## Auto-Invocation Triggers

Claude **automatically calls this skill** when detecting requests like:
- "create new Perl module"
- "new Node.js project"
- "scaffold Python distribution"
- "init Go app"
- "create [ProjectName]"
- "gitignore" + any language context
- "dist.ini" + project creation
- "setup new [type]"
- Any project initialization or scaffolding request

## Usage

**Automatic (Claude calls when context detected):**
```
create new Perl module Foo::Bar
new Node.js app my-server
scaffold Python package mylib
init Go project kanban-tool
```

**Manual invocation:**
```
create-software Foo::Bar          # Perl (if dist.ini pattern detected)
create-software my-app --node     # Explicit type
create-software --interactive     # Ask me questions
```

## Detection Logic

Claude analyzes the request and determines project type:

| Pattern | Type | Action |
|---------|------|--------|
| `Foo::Bar`, `Foo-Bar`, has dist.ini | Perl/Dzil | Load `create-perl-distribution`, scaffold dist.ini/README/Changes/cpanfile/lib/t |
| `my-app`, `myapp`, has package.json | Node.js | Create .gitignore (nodejs template), init git, suggest npm init |
| `mylib`, has pyproject.toml/setup.py | Python | Create .gitignore (python template), init venv guide |
| `kanban-tool`, has go.mod | Go | Create .gitignore (go template), bin/ structure |
| Generic name, unclear | Generic | Create .gitignore only (generic template) |

## What Gets Created

### Perl Distribution
- `dist.ini` with [@Author::GETTY], copyright_year=2026, proper author
- `lib/Foo/Bar.pm` with ABSTRACT and POD stubs
- `t/00-load.t` and `t/01-basic.t`
- `cpanfile` with runtime/test/develop sections
- `Changes` with {{$NEXT}} marker
- `README.md` with installation/usage sections
- `.gitignore` (perl-dzil template)
- `.claude/CLAUDE.md` project guidance
- Search existing Perl projects for matching IRC channel

### Node.js Project
- `.gitignore` (nodejs template)
- Suggest `npm init` for package.json
- Suggest relevant tooling (eslint, prettier, jest, etc.)

### Python Project
- `.gitignore` (python template)
- `.env` template
- Suggest `pyproject.toml` or `setup.py` structure
- Virtual environment guide

### Go Project
- `.gitignore` (go template)
- `cmd/[name]/main.go` skeleton
- Basic Go module structure
- Suggest Makefile for builds

### All Projects
- `.gitignore` with proper templates (auto-detected language)
- Git init + first commit (if not in repo)
- Standard ignore patterns + IDE settings

## Author & License Detection

For Perl distributions:
- Extracts author from `~/.gitconfig` or uses Getty's standard author format
- Sets copyright_year to 2026
- Validates author has email and website link (POD format)

## Handcheck Points

Claude asks for approval before proceeding if:
- Author format is non-standard or missing
- Project name seems ambiguous (could be multiple types)
- Custom .gitignore patterns would be overwritten
- IRC channel selection (Perl only)

## Examples

```
User: "create new Perl module Data::Cache"
Claude: Calls create-software
   → Detects Perl (Foo::Bar pattern + Author::GETTY context)
   → Scaffolds dist.ini, README, Changes, lib/Data/Cache.pm, t/*, cpanfile
   → Creates .gitignore (perl-dzil template)
   → Searches ~/dev/perl/Data-* projects for IRC channel
   → Asks: "IRC channel? Found #data-cache in similar project, use that?"
   → Commits if approved

User: "new Node.js server my-api"
Claude: Calls create-software
   → Detects Node.js
   → Creates .gitignore (nodejs template)
   → Commits
   → Suggests: "Run 'npm init' next"

User: "scaffold Python Data::Cache"
Claude: Calls create-software
   → Detects Perl-ish name but Python context
   → Asks: "Perl or Python?" → user says Python
   → Creates .gitignore (python template)
   → Suggests pyproject.toml structure
```

## Related Skills

- `create-gitignore` — loaded by this skill for individual language templates
- `create-perl-distribution` — loaded by this skill for full Perl scaffolding

---

**Skill source**: `~/.claude/skills/create-software/SKILL.md`
