# WWW::Forgejo — Implementation Plan

Perl client für die Forgejo API v1, aufgebaut nach dem Muster von [`WWW::Hetzner`](../p5-www-hetzner/).

- **Swagger:** https://src.ci/api/swagger (`https://src.ci/swagger.v1.json`)
- **API Version:** Forgejo 14.0.5 (Gitea-1.22 kompatibel), Swagger 2.0
- **Base URL:** `https://<host>/api/v1`
- **304 Endpoints**, primär `/repos` (147), `/user` (38), `/orgs` (30), `/admin` (28), `/users` (16)
- **Auth:** Bearer Token (`Authorization: token <PAT>`) primär; auch `access_token` Query + BasicAuth + `Sudo` Header möglich
- **Kein CLI in v1** — Forgejo liefert `forgejo` CLI selbst mit. Bibliothek nur.

---

## Phase 0 — Foundation

- [ ] `dist.ini` (`[@Author::GETTY]`, `name = WWW-Forgejo`, `copyright_year = 2026`, `irc = #kubernetes` oder anderer Channel)
- [ ] `cpanfile` — runtime/test deps (siehe Phase 1)
- [ ] `Changes` mit `{{$NEXT}}` Block
- [ ] `README.md` — Synopsis aus `WWW::Forgejo.pm`
- [ ] `.gitignore` — Standard Dist::Zilla + `cover_db/`, `*.tar.gz`, `.build/`
- [ ] `CLAUDE.md` — Hinweis auf Hetzner als Vorbild, "kein CLI"
- [ ] `t/00-load.t` — alle Module laden
- [ ] `git init`, erster Commit

## Phase 1 — HTTP/IO Stack (1:1 von Hetzner kopieren)

Generisch genug, dass es direkt übernommen werden kann:

- [ ] `lib/WWW/Forgejo/HTTPRequest.pm` — kopieren von `WWW::Hetzner::HTTPRequest`
- [ ] `lib/WWW/Forgejo/HTTPResponse.pm` — kopieren
- [ ] `lib/WWW/Forgejo/Role/IO.pm` — kopieren
- [ ] `lib/WWW/Forgejo/LWPIO.pm` — kopieren (default backend)
- [ ] `lib/WWW/Forgejo/Role/HTTP.pm` — kopieren, anpassen:
  - `_set_auth` → `Authorization: token <PAT>` (statt `Bearer`)
  - Optional `sudo` Header support
  - Error parsing an Forgejo Format anpassen (`{message, url, errors}`)

**cpanfile:**
```perl
requires 'Moo';
requires 'LWP::UserAgent';
requires 'JSON::MaybeXS';
requires 'HTTP::Request';
requires 'URI';
requires 'URI::Escape';
requires 'namespace::clean';
requires 'Log::Any';
requires 'Carp';
on test => sub {
    requires 'Test::More';
    requires 'Path::Tiny';
};
```

## Phase 2 — Main Client

- [ ] `lib/WWW/Forgejo.pm` — Hauptklasse
  - Attribute: `url` (z.B. `https://src.ci`), `token`, `base_url` (lazy → `${url}/api/v1`)
  - `with 'WWW::Forgejo::Role::HTTP'`
  - Lazy Accessoren für alle API-Gruppen (siehe unten)
  - ENV-Defaults: `FORGEJO_URL`, `FORGEJO_TOKEN`
  - `_check_auth` mit hilfreicher Fehlermeldung + Link auf Settings → Applications → Tokens

## Phase 3 — Admin API (User-Management) **[Prio 1]**

User-Wunsch: "user hinzufügen". Admin braucht `admin`-Scope Token.

- [ ] `lib/WWW/Forgejo/API/Admin.pm` — Dispatcher (`users`, `orgs`, `emails`, `hooks`, `cron`, `quota`, `runners`)
- [ ] `lib/WWW/Forgejo/API/Admin/Users.pm`
  - `list`, `get($username)`, `create(%params)`, `edit($username, %params)`, `delete($username)`
  - `rename($username, $new_name)`
  - `add_email($username, $email)`, `delete_email($username, $email)`, `search_emails`
  - `list_keys($username)`, `add_key($username, ...)`, `delete_key($username, $id)`
  - `list_orgs($username)`, `create_org_for($username, %params)`
  - `list_repos($username)`, `create_repo_for($username, %params)`
  - `quota($username)`, `add_to_quota_group($username, $group)`
- [ ] `lib/WWW/Forgejo/API/Admin/Hooks.pm` — system-wide hooks
- [ ] `lib/WWW/Forgejo/API/Admin/Cron.pm` — `list`, `run($task)`
- [ ] `lib/WWW/Forgejo/API/Admin/Quota.pm` — groups + rules CRUD
- [ ] `lib/WWW/Forgejo/API/Admin/Runners.pm` — registration-token, jobs, unadopted repos
- [ ] Entities: `lib/WWW/Forgejo/Entity/User.pm`, `Entity/Email.pm`, `Entity/QuotaGroup.pm`, `Entity/QuotaRule.pm`, `Entity/CronTask.pm`

## Phase 4 — Repos API **[Prio 1]**

147 Endpoints. Sinnvolle Aufteilung:

- [ ] `lib/WWW/Forgejo/API/Repos.pm` — Top-Level Dispatcher + `search`
  - `search(%params)`, `get($owner, $repo)`, `create_for_user(%params)` (POST `/user/repos`),
    `create_from_template($template_owner, $template_repo, %params)`,
    `migrate(%params)`, `delete($owner, $repo)`, `transfer($owner, $repo, %params)`,
    `fork($owner, $repo, %params)`, `generate(...)`, `mirror_sync`, `push_mirrors`
  - Liefert `WWW::Forgejo::Entity::Repo` zurück — auf dem hängen alle sub-resources
- [ ] `lib/WWW/Forgejo/Entity/Repo.pm` — zentrales Objekt, lazy Accessoren:
  - `branches`, `branch_protections`, `tags`, `tag_protections`, `releases`,
    `issues`, `pulls`, `hooks`, `collaborators`, `contents`, `git`, `wiki`,
    `actions`, `labels`, `milestones`, `topics`, `keys`, `forks`, `stargazers`,
    `subscribers`, `subscription`, `assignees`, `reviewers`, `flags`
- [ ] Sub-API-Controller (jeweils mit Entity-Klassen):

| Sub-API | Endpoints | Entity |
|---|---|---|
| `API/Repo/Branches.pm` | list, get, create, delete | `Entity/Branch.pm` |
| `API/Repo/BranchProtections.pm` | CRUD | `Entity/BranchProtection.pm` |
| `API/Repo/Tags.pm` + `TagProtections.pm` | CRUD | `Entity/Tag.pm` |
| `API/Repo/Releases.pm` | CRUD + assets | `Entity/Release.pm`, `Entity/ReleaseAsset.pm` |
| `API/Repo/Issues.pm` | CRUD + comments + labels + reactions + timeline + deps | `Entity/Issue.pm`, `Entity/IssueComment.pm` |
| `API/Repo/PullRequests.pm` | CRUD + reviews + reviewers + merge | `Entity/PullRequest.pm`, `Entity/Review.pm` |
| `API/Repo/Hooks.pm` | CRUD + test | `Entity/Hook.pm` |
| `API/Repo/Collaborators.pm` | list, add, remove, permission | `Entity/Collaborator.pm` |
| `API/Repo/Contents.pm` | file get/create/update/delete, raw, media, diff/patch | `Entity/Content.pm` |
| `API/Repo/Git.pm` | refs, commits, blobs, trees, tags (low-level) | — |
| `API/Repo/Wiki.pm` | pages CRUD, revisions | `Entity/WikiPage.pm` |
| `API/Repo/Actions.pm` | secrets, variables, runners, workflows, artifacts | `Entity/ActionSecret.pm` |
| `API/Repo/Labels.pm` | CRUD | `Entity/Label.pm` |
| `API/Repo/Milestones.pm` | CRUD | `Entity/Milestone.pm` |
| `API/Repo/Topics.pm` | list, add, remove | — |
| `API/Repo/Keys.pm` | deploy keys CRUD | `Entity/DeployKey.pm` |
| `API/Repo/Statuses.pm` | commit statuses | `Entity/CommitStatus.pm` |

**Empfohlene Reihenfolge:** Repo CRUD → Branches → Contents → Hooks → Collaborators → Issues → PRs → Releases → Rest.

## Phase 5 — Orgs / Teams

- [ ] `lib/WWW/Forgejo/API/Orgs.pm`
  - `list` (admin), `get($org)`, `create(%params)`, `edit($org, %params)`, `delete($org)`, `rename`
  - Auf `Entity::Org` hängen: `members`, `public_members`, `teams`, `repos`, `hooks`,
    `labels`, `quota`, `actions` (secrets/variables/runners), `blocked_users`
- [ ] `lib/WWW/Forgejo/API/Org/Members.pm` — list, check, remove, is_public, publicize
- [ ] `lib/WWW/Forgejo/API/Org/Teams.pm` — search + (delegiert an Teams API)
- [ ] `lib/WWW/Forgejo/API/Teams.pm` — `/teams/{id}` CRUD, members, repos
- [ ] `lib/WWW/Forgejo/API/Org/Hooks.pm`, `Labels.pm`, `Actions.pm`, `Quota.pm`
- [ ] Entities: `Entity/Org.pm`, `Entity/Team.pm`

## Phase 6 — Current User & Users

- [ ] `lib/WWW/Forgejo/API/CurrentUser.pm` — `/user/*` (eigenes Profil)
  - `get`, `settings`, `update_settings`
  - `emails` (list/add/delete), `keys` (CRUD), `gpg_keys` (CRUD + token/verify)
  - `hooks` (CRUD), `applications` (oauth2 CRUD)
  - `orgs`, `teams`, `repos`, `starred`, `subscriptions`, `followers`, `following`
  - `block($user)`, `unblock($user)`, `list_blocked`
  - `quota`, `stopwatches`, `times`
  - `actions` (secrets, variables, runners)
- [ ] `lib/WWW/Forgejo/API/Users.pm` — andere User lesen (`/users/*`)
  - `search`, `get($username)`, `keys`, `gpg_keys`, `followers`, `following`,
    `starred`, `subscriptions`, `repos`, `tokens` (eigene token CRUD via basic auth),
    `heatmap`, `activities/feeds`

## Phase 7 — Notifications, Packages, Misc

- [ ] `lib/WWW/Forgejo/API/Notifications.pm` — list, mark-read (global + per-repo)
- [ ] `lib/WWW/Forgejo/API/Packages.pm` — list, get, delete, files
- [ ] `lib/WWW/Forgejo/API/Misc.pm` — Sammler für read-only/utility Endpoints:
  - `version`, `nodeinfo`, `signing_key` (gpg/ssh)
  - `markdown`, `markup` (render)
  - `gitignore_templates`, `license_templates`, `label_templates`
  - `settings` (api, attachment, repository, ui)
  - `topics_search`
- [ ] `lib/WWW/Forgejo/API/ActivityPub.pm` — actor + inbox/outbox (vermutlich rarely-used, low prio)

## Phase 8 — Tests

- [ ] `t/00-load.t` — alle Module laden
- [ ] `t/01-client.t` — Client-Konstruktion, ENV-Vars, Auth-Header
- [ ] `t/02-http-mock.t` — Mock-IO-Backend, alle HTTP-Methoden
- [ ] `t/10-admin-users.t` — gegen Mock
- [ ] `t/20-repos.t` — gegen Mock
- [ ] `t/30-issues-prs.t` — gegen Mock
- [ ] **Live-Tests** (nur mit `TEST_FORGEJO_URL` + `TEST_FORGEJO_TOKEN`):
  - `t/90-live-admin.t` — User anlegen/löschen
  - `t/91-live-repos.t` — Repo Create/Delete/Fork
  - `t/92-live-issues.t` — Issue + Comment + Close
  - Konvention `TEST_` Prefix einhalten (aus MEMORY.md)
- [ ] Test-Fixtures unter `t/fixtures/` (JSON-Responses aus dem Swagger ableiten)

## Phase 9 — Documentation

- [ ] POD in `WWW::Forgejo.pm` mit kompletter Synopsis (analog Hetzner) — alle API-Gruppen + Beispiele
- [ ] POD in jedem API-Modul: `=method` für jede Methode, `=attr` für Attribute
- [ ] POD in jeder Entity-Klasse: Attribute + `update`/`delete`-Methoden
- [ ] `=seealso` Cross-Links zwischen API/Entity/Main
- [ ] PodWeaver @Author::GETTY Konventionen beachten (inline `=attr`/`=method`/`=opt`, keine NAME/AUTHOR sections)
- [ ] `# ABSTRACT:` auf jeder `.pm`

## Phase 10 — Release

- [ ] `dzil build` clean
- [ ] `dzil test` grün (ohne live)
- [ ] Live-Suite manuell gegen src.ci durchlaufen lassen
- [ ] `Changes` finalisieren
- [ ] `dzil release` → CPAN
- [ ] GitHub/Forgejo Repo pushen

---

## Design Notes

### Naming-Konventionen
- `WWW::Forgejo::API::<Group>` für Controller (analog Hetzner Cloud::API)
- `WWW::Forgejo::Entity::<Thing>` für Models — abweichend vom Hetzner-Schema, das die Entities direkt unter `Cloud::` hatte. Da Forgejo *ein* Service ist (keine `Cloud`/`Robot`-Trennung), brauchen wir kein Namespace-Level dazwischen — `Entity::` macht den Unterschied API↔Model deutlich.
- Repo-Sub-Resources: `API::Repo::<Sub>` (z.B. `API::Repo::Branches`)

### Entity-Pattern
- Wie Hetzner: Entity hält `_client` weak_ref, hat `update`/`delete`-Methoden, plus `data()` für JSON-Serialisierung.
- Sub-Resources werden vom Entity lazy gebaut, mit `weak_ref` auf parent (z.B. `$repo->branches` → `API::Repo::Branches->new(client => ..., owner => ..., repo => ...)`).

### URL-Encoding
- Owner/Repo/Username können Sonderzeichen enthalten → `URI::Escape::uri_escape` in `_path_for($owner, $repo, ...)` Helper im Role::HTTP.

### Pagination
- Forgejo nutzt `page` + `limit` Query-Params, gibt `X-Total-Count` Header zurück.
- `list` Methoden sollten auto-paginieren bis erschöpft (Standard) und einen `page_size` / `max_pages` Override anbieten.
- Eventuell `list_iter` für Generator-Pattern, um Memory zu sparen bei großen Repos/Issue-Listen.

### Async-Vorbereitung
- HTTP-Stack ist via `Role::IO` schon austauschbar — eine spätere `p5-net-async-forgejo` kann `IO`-Backend ersetzen, analog `p5-net-async-hetzner`.

### Was bewusst weggelassen wird
- **Kein CLI** (User-Vorgabe) — Forgejo bringt `forgejo` Binary selbst mit.
- **ActivityPub** kann auf später verschoben werden (Federation, selten gebraucht).
- **Quota** API ist Forgejo-spezifisch (Gitea hat das nicht) — niedrigere Prio als die Core-CRUD-Operationen.

### Offene Fragen
- Soll Repo-Migration/Mirror eigenes Sub-API werden oder unter `API::Repos`?
- Wie wollen wir Webhooks/Events typisieren — eigene Entity-Hierarchie für Payloads (`Event/Push.pm`, `Event/Issue.pm`, ...) oder reines Hashref?
- Sollen Live-Tests gegen eine eigene lokale Forgejo-Instanz laufen (docker-compose im Repo) oder gegen src.ci mit Wegwerf-User?
