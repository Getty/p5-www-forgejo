---
name: www-forgejo-core
description: "Use when working on WWW::Forgejo — the synchronous LWP-based Forgejo API v1 client. The pluggable IO transport seam (Role::HTTP over Role::IO), the request/response value objects the async sibling reuses, the API-dispatcher-plus-Entity object tree, token auth, and the boundary of what belongs here vs. in the async sibling Net::Async::Forgejo."
user-invocable: false
allowed-tools: Read, Grep, Glob
model: sonnet
---

# WWW::Forgejo — synchronous Forgejo API v1 client

A Perl client for the Forgejo API v1 (`https://<host>/api/v1`), built on `Moo` and
`LWP::UserAgent`. It owns everything domain-specific about Forgejo: request building,
token auth, JSON, error handling, `Log::Any` logging, and the whole API surface as an
object tree. The HTTP transport is deliberately pluggable so the async sibling can swap
it out (see **The twin**).

Getty Moo/CPAN house conventions (module loading, `has`/`with`, `namespace::clean`,
cpanfile pinning) live in skills `getty-perl-moo` and `getty-perl-core` and are not
repeated here.

## Moo, not Moose

Every class is `use Moo;` (roles `use Moo::Role;`), `namespace::clean`, `Log::Any
qw($log)`, `# ABSTRACT:` + `PODNAME`, PodWeaver `@Author::GETTY` (inline `=method` /
`=attr`, no NAME/AUTHOR sections). `our $VERSION = '0.001'` in every module — never
released.

## The transport seam — the reusable part

Three layers, and the boundary between them is the whole reason the async sibling can
exist:

- **`WWW::Forgejo::Role::HTTP`** — the Forgejo brain. Consumed by the main client;
  `requires 'token'` and `requires 'base_url'`. It owns:
  - the verb methods `get/post/put/patch/delete`, which all funnel through `_request`;
  - **`_build_request($method, $path, %opts)`** → a `WWW::Forgejo::HTTPRequest` (URL =
    `base_url . $path`, GET query params appended, `Authorization: token <token>` +
    `Content-Type: application/json` headers, JSON-encoded body). Builds but does **not**
    execute — this split is intentional.
  - **`_parse_response($response, $method, $path)`** → decodes JSON when the body looks
    like JSON, `croak`s `"Forgejo API error: ..."` on non-2xx (message pulled from the
    decoded `{message}`), returns the decoded data.
  - `_request` glues them: `croak` if no token, build, `$self->io->call($req)`, parse.
- **`WWW::Forgejo::Role::IO`** — a one-method interface: `requires 'call'`. `call($req)`
  takes a `HTTPRequest`, returns a `HTTPResponse`. This is the swappable transport.
- **`WWW::Forgejo::LWPIO`** — the default `Role::IO` backend (synchronous `LWP::UserAgent`,
  `timeout` attr, lazy `ua`). `call` maps the `HTTPRequest` onto an `HTTP::Request`, runs
  it, wraps the result in a `HTTPResponse`.

`Role::HTTP` reaches transport **only** through `$self->io->call` — it never touches LWP
directly. To add an async/alternative transport you implement `Role::IO`, not touch
`Role::HTTP`.

### The bridge value objects

`WWW::Forgejo::HTTPRequest` (`method`, `url`, `headers`, `content` + `has_content`
predicate) and `WWW::Forgejo::HTTPResponse` (`status`, `content`) are transport-neutral
Moo objects. They are the exact types that cross the `Role::IO` seam, and the async
sibling produces/consumes the **same** types so both share one `_build_request` /
`_parse_response` path. When you touch transport you produce a `HTTPResponse`, never a
raw `HTTP::Response`.

> Known gap (ticketed): `HTTPResponse` has no `headers` attribute yet, though the async
> bridge and `t/02-http-mock.t` already pass `headers` (silently dropped by Moo). Adding
> `headers` with lower-cased keys is the agreed shape — coordinate it as a paired change
> with the sibling, do not invent a different one.

## The API object tree

`WWW::Forgejo` (the main client) `with 'WWW::Forgejo::Role::HTTP'`, holds `token` and
`base_url` (`init_arg => 'url'`), and exposes a lazy accessor per top-level API group:
`misc`, `users`, `orgs`, `teams`, `notifications`, `packages`, `repos`, `current_user`,
`admin`. Each builds a `WWW::Forgejo::API::<Group>->new(client => $self)`.

- **`WWW::Forgejo::API::<Group>`** — a controller holding a (non-weak) `client`. Its
  methods call `$self->{client}->get/post/...` and wrap the raw data into Entities.
  Repo-scoped controllers live under `API/Repo/<Sub>` and `API/Org/<Sub>` and additionally
  carry `owner`/`repo` (or `org`), with a `_path_for(@parts)` helper.
- **`WWW::Forgejo::Entity::<Thing>`** — a model wrapping `client` + `data` (the raw
  hashref), plus `owner`/`repo` on repo-scoped entities. Field accessors read
  `data->{...}`; `data_json` serialises. `Entity::Repo` is the hub: it lazily builds its
  sub-resource controllers (`$repo->branches`, `->releases`, `->issues`, `->pulls`, …),
  each `require`d on first use and constructed with `client/owner/repo`.

The flow is always: `$client->repos->get($owner,$repo)` → `Entity::Repo` →
`$repo->releases` → `API::Repo::Releases` → `->list` → `Entity::Release` objects.

> Inconsistencies present in the tree (ticketed, do not "tidy" mid-task): the base
> `WWW::Forgejo::Entity` (weak_ref `client`, `update`/`delete` croak stubs) is **not**
> actually `extends`-ed by the concrete entities — they redefine attributes standalone
> and use a plain `required` client, not `weak_ref`. Treat the base as aspirational until
> a deliberate refactor unifies it.

## Auth and config

Auth is `Authorization: token <token>` (a Forgejo PAT) — not `Bearer`. `base_url` is the
full API base the caller passes as `url` (e.g. `https://src.ci/api/v1`); it is used
verbatim, there is currently **no** `/api/v1` auto-append and **no** `FORGEJO_URL` /
`FORGEJO_TOKEN` ENV fallback despite the plan calling for them — that is unbuilt work, not
a convention to assume. `_request` croaks `"No API token configured"` when `token` is
empty.

## The twin — Net::Async::Forgejo (`../p5-net-async-forgejo`)

This distribution is the **semantics owner**; the async sibling `Net::Async::Forgejo` is a
thin `IO::Async` transport that delegates all Forgejo meaning back here by calling this
repo's `_build_request` / `_parse_response` and exchanging `HTTPRequest` / `HTTPResponse`.
Anything about *what Forgejo expects* — paths, encoding, auth, JSON, errors, new endpoints,
new entities — belongs **here**. A change that only concerns non-blocking transport belongs
in the sibling.

**Release coupling.** The two distributions are released **together, as one coordinated
release**; the sibling's cpanfile requires `WWW::Forgejo` and its tests
`use lib '../p5-www-forgejo/lib'`. Only the local checkout state counts — a CPAN-release
lag of either side is never a blocker and never a ticket. Cross-repo work is a karr ticket
on the *other* repo's board, never a direct edit.

## Verification

`prove -l t/` runs the offline suite (`00-load`, `01-client`, `02-http-mock` — the mock
implements `Role::IO`). The `t/9x-live-*.t` files self-skip unless `TEST_FORGEJO_URL` +
`TEST_FORGEJO_TOKEN` are set (keep the `TEST_` prefix). `dzil test` / `dzil build` for the
full `[@Author::GETTY]` distribution.
