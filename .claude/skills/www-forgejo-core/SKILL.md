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

Every class is `use Moo;` (roles `use Moo::Role;`), `namespace::clean`, `# ABSTRACT:` +
`PODNAME`, PodWeaver `@Author::GETTY` (inline `=method` / `=attr`, no NAME/AUTHOR
sections). `our $VERSION = '0.001'` in every module — never released. `Log::Any
qw($log)` is imported only where the module really logs — that is `Role::HTTP`; the
entities and the controllers do not log and do not import it.

## The transport seam — the reusable part

Three layers, and the boundary between them is the whole reason the async sibling can
exist:

- **`WWW::Forgejo::Role::HTTP`** — the Forgejo brain. Consumed by the main client;
  `requires 'token'` and `requires 'base_url'`. It owns:
  - the verb methods `get/post/put/patch/delete`, which all funnel through `_request`;
  - **`check($path)`** — a yes/no question asked with the status code: true for a 2xx
    response, false for a 404, croak for anything else. The rule itself lives in
    **`_check_response($response, $method, $path)`**, so a transport that is not `io` —
    the async sibling — can ask the same question of a response it fetched itself;
  - **`_build_request($method, $path, %opts)`** → a `WWW::Forgejo::HTTPRequest` (URL =
    `base_url . $path`, GET query params appended, `Authorization: token <token>` +
    `Content-Type: application/json` headers, JSON-encoded body). Builds but does **not**
    execute — this split is intentional. The options it understands: `params` (query
    string), `body` (JSON body), `content`/`content_type` (a raw body), `upload`
    (multipart), `auth` (basic authentication instead of the token) and `base_url` (a
    base URL of its own, for the paths of Forgejo that live outside `/api/v1`).
  - **`_parse_response($response, $method, $path)`** → decodes JSON when the body looks
    like JSON, `croak`s `"Forgejo API error: ..."` on non-2xx (message pulled from the
    decoded `{message}`), returns the decoded data.
  - `_request` glues them: `croak` if there is no token (and no basic authentication was
    asked for), build, `$self->io->call($req)`, parse.
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
predicate) and `WWW::Forgejo::HTTPResponse` (`status`, `content`, `headers`) are
transport-neutral Moo objects. They are the exact types that cross the `Role::IO` seam,
and the async sibling produces/consumes the **same** types so both share one
`_build_request` / `_parse_response` path. When you touch transport you produce a
`HTTPResponse`, never a raw `HTTP::Response`. `HTTPResponse` lower-cases the header
keys at construction, so a header that came in as `X-Total-Count` is read as
`x-total-count` — `_check_response` relies on that for the `content-type`.

## The API object tree

`WWW::Forgejo` (the main client) `with 'WWW::Forgejo::Role::HTTP'`, holds `token`, `url` and
`base_url` (the last two derived in `BUILDARGS`), and exposes a lazy accessor per
top-level API group: `misc`, `users`, `orgs`, `teams`, `notifications`, `packages`,
`repos`, `current_user`, `admin`, `activitypub`. Each builds a
`WWW::Forgejo::API::<Group>->new(client => $self)`.

- **`WWW::Forgejo::API::<Group>`** — a controller holding a (non-weak) `client`. Its
  methods call `$self->{client}->get/post/...` and wrap the raw data into Entities.
  Repo-scoped controllers live under `API/Repo/<Sub>` and `API/Org/<Sub>` and additionally
  carry `owner`/`repo` (or `org`), with a `_path_for(@parts)` helper.
- **`WWW::Forgejo::Entity::<Thing>`** — a model wrapping `client` + `data` (the raw
  hashref), plus `owner`/`repo` on repo-scoped entities. Field accessors read
  `data->{...}`; `data_json` serialises. `Entity::Repo` is the hub: it builds its
  sub-resource controllers (`$repo->branches`, `->releases`, `->issues`, `->pulls`, …)
  lazily, each with `client/owner/repo`.

The flow is always: `$client->repos->get($owner,$repo)` → `Entity::Repo` →
`$repo->releases` → `API::Repo::Releases` → `->list` → `Entity::Release` objects.

Every concrete entity `extends 'WWW::Forgejo::Entity'` and inherits its `client` and
`data` attributes (a plain `required` one — not a weak reference) and the
`update`/`delete` croak stubs; the classes that can do more override them.

### The style of a controller method

Query parameters and the body of a request are **named arguments** — never a hashref as
a positional argument: `$repo->issues->list(state => 'open')`,
`$repo->issues->create(title => 'Broken', body => '...')`. The parameters that are part
of the path (owner, repo, index, org, name) stay positional. A method that returns a
collection returns an **arrayref**, not a list. Every part of a path is escaped with
`escape_component`, so a name with a slash or an umlaut survives the round trip.

## Auth and config

Auth is `Authorization: token <token>` (a Forgejo PAT) — not `Bearer`. A request may ask
for basic authentication instead, with the `auth` option (`{ user => ..., password =>
... }`); a few endpoints of Forgejo want that. `base_url` is derived from the `url`
option — else from `FORGEJO_URL` — and normalised to end in `/api/v1` (idempotent: an
already-suffixed URL is left unchanged); a missing URL croaks at construction. The
token comes from the `token` option, else from `FORGEJO_TOKEN`, else it is the empty
string — a missing token does not croak at construction, but `_request` croaks
`"No API token configured"` when a request goes out without one (and without basic
authentication).

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

A new endpoint is not done before it passes the guard rails:

- `t/40-spec-conformance.t` calls every public method of every controller against the
  mock and wants the request it sends to be an operation of the API — the paths are
  listed in `t/fixtures/forgejo-api-paths.txt`, extracted from the official Swagger
  document. A new path belongs in that file as well.
- `t/41-pod-coverage.t` wants every public method and attribute documented and a
  SYNOPSIS that compiles and calls only existing methods.
- `t/42-live-tests-static.t` wants every method call in the live tests to exist.
- `t/13-quota-and-stars.t` shows the shape of a focused offline test for a group of
  new endpoints: the mock answers with a canned body, the test asserts the request
  that went out and the entity that came back.
