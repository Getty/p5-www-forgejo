# WWW-Forgejo

Synchronous Perl client for the REST API (`/api/v1`) of a
[Forgejo](https://forgejo.org) instance. A [Moo](https://metacpan.org/pod/Moo)
based client: the API is split into small controllers hanging off the main
object, and everything inside a repository or an organization hangs off the
entity object returned for it.

`WWW::Forgejo` owns the Forgejo semantics (paths, token auth, JSON, errors). The
HTTP transport is pluggable; the default is `LWP::UserAgent`. The asynchronous
sibling `Net::Async::Forgejo` reuses the same request building and response
parsing.

## Installation

```bash
cpanm WWW::Forgejo
```

`https://` instances need
[LWP::Protocol::https](https://metacpan.org/pod/LWP::Protocol::https). It is
only a recommended prerequisite, because Forgejo often runs without TLS inside
a private network; `cpanm` installs recommended modules with
`--with-recommends`, or install it on its own:

```bash
cpanm LWP::Protocol::https
```

From a checkout:

```bash
cpanm --installdeps .
prove -l t/
```

## Synopsis

```perl
use WWW::Forgejo;

my $forgejo = WWW::Forgejo->new(
    url   => 'https://forgejo.example.com',   # instance root, /api/v1 is appended
    token => $ENV{FORGEJO_TOKEN},             # personal access token
);

# Instance and current user: plain decoded JSON
my $version = $forgejo->misc->version;
my $me      = $forgejo->current_user->get;
print "logged in as $me->{login}\n";

# A repository is an entity object and the door to everything inside it
my $repo = $forgejo->repos->get('owner', 'repo-name');
print $repo->data->{full_name}, "\n";

# Issues
for my $issue ($repo->issues->list(state => 'open')) {
    printf "#%d %s\n", $issue->number, $issue->title;
}
my $issue = $repo->issues->create({ title => 'Something is broken', body => '...' });
$repo->issues->add_comment($issue->number, { body => 'On it.' });
$repo->issues->edit($issue->number, { title => 'Something was broken' });

# Pull requests
my $pr = $repo->pulls->create({
    title => 'Add the thing', head => 'feature-branch', base => 'main',
});
$repo->pulls->merge($pr->number, \%merge_options);

# Organizations
my $org   = $forgejo->orgs->get('my-org');
my $repos = $forgejo->repos->list_for_org('my-org');

# Anything without a dedicated method: the raw verbs
my $data = $forgejo->get('/user/repos', params => { limit => 10 });
```

Controllers and entities keep a reference to the client they came from, so a
chain like `WWW::Forgejo->new(...)->repos->get($owner, $name)->issues->list`
works without storing the client in a variable. The client keeps no reference
back, so nothing leaks.

## Configuration

| Constructor option | Environment     | Notes                                                        |
|--------------------|-----------------|--------------------------------------------------------------|
| `url`              | `FORGEJO_URL`   | Instance root. Required; the constructor croaks without it.  |
| `token`            | `FORGEJO_TOKEN` | Access token, sent as `Authorization: token <TOKEN>`.        |
| `io`               |                 | Transport object, defaults to `WWW::Forgejo::LWPIO`.         |

`url` may be given with or without a trailing slash and with or without
`/api/v1`; `$forgejo->url` returns it without the trailing slash,
`$forgejo->base_url` the API base ending in `/api/v1`. A missing token is not an error at construction time, but
every request croaks with `No API token configured`.

## API overview

Controllers on the client:

| Accessor                  | Class                              | Covers                                                    |
|---------------------------|------------------------------------|-----------------------------------------------------------|
| `$forgejo->misc`          | `WWW::Forgejo::API::Misc`          | version, nodeinfo, settings, templates, markdown/markup   |
| `$forgejo->users`         | `WWW::Forgejo::API::Users`         | look up and search users, their keys, repos, followers    |
| `$forgejo->current_user`  | `WWW::Forgejo::API::CurrentUser`   | `/user/...`: settings, emails, keys, hooks, apps, secrets |
| `$forgejo->repos`         | `WWW::Forgejo::API::Repos`         | search, get, create, migrate, fork, transfer, mirrors     |
| `$forgejo->orgs`          | `WWW::Forgejo::API::Orgs`          | list, get, create, edit, rename, delete                   |
| `$forgejo->teams`         | `WWW::Forgejo::API::Teams`         | teams by ID, their members and repositories               |
| `$forgejo->notifications` | `WWW::Forgejo::API::Notifications` | list, count, mark read, per repository                    |
| `$forgejo->packages`      | `WWW::Forgejo::API::Packages`      | list, get, delete, files                                  |
| `$forgejo->admin`         | `WWW::Forgejo::API::Admin`         | `users`, `hooks`, `cron`, `quota`, `runners`              |
| `$forgejo->activitypub`   | `WWW::Forgejo::API::ActivityPub`   | actor, inbox and outbox of a user                         |

Controllers on a repository (`my $repo = $forgejo->repos->get($owner, $name)`),
each a `WWW::Forgejo::API::Repo::*` object bound to that repository:

`actions`, `assignees`, `branches`, `branch_protections`, `collaborators`,
`contents`, `flags`, `forks`, `git`, `hooks`, `issues`, `keys`, `labels`,
`milestones`, `pulls`, `releases`, `reviewers`, `stargazers`, `subscribers`,
`statuses`, `subscription`, `tags`, `tag_protections`, `topics`, `wiki`

Controllers on an organization (`my $org = $forgejo->orgs->get($name)`), each a
`WWW::Forgejo::API::Org::*` object:

`actions`, `blocked_users`, `hooks`, `labels`, `members`, `quota`, `teams`

Every controller and entity class has its own POD with one example per method
(`perldoc WWW::Forgejo::API::Repo::Issues`).

### Return values

Depending on the method, a call returns either `WWW::Forgejo::Entity::*` objects
or the decoded JSON response as plain Perl data; the POD of each controller says
which. Entities offer accessors for commonly used fields and always keep the
complete decoded structure in `->data`:

```perl
my $pr = $repo->pulls->get(1);
print $pr->title;                    # accessor
print $repo->data->{description};    # any field of the decoded response
```

### Query parameters and paging

The `list` and `search` methods take the query parameters of the endpoint as
named arguments; undefined values are left out:

```perl
my @open     = $repo->issues->list(state => 'open', labels => 'bug');
my @branches = $repo->branches->list(page => 2, limit => 50);
my $found    = $forgejo->repos->search(q => 'forgejo', limit => 10);
```

A collection is followed to its end automatically: when the response carries
an `X-Total-Count` header announcing more items than were returned, the
remaining pages are fetched and the merged result is returned. This works with
the default `WWW::Forgejo::LWPIO` backend and with any other transport that
passes the response headers on.

- `page => N` asks for exactly that page; nothing further is fetched.
- `limit => N` sets the page size used for every request of the collection.
- At most 100 pages are fetched per call. The raw `get` takes `max_pages` and
  `page_size` to change that, see `WWW::Forgejo::Role::HTTP`:

```perl
my $repos = $forgejo->get('/user/repos', page_size => 50, max_pages => 5);
```

### Errors

Every failure is reported with `croak`, so the message points at the calling
code:

- a response outside the 2xx range: `Forgejo API error: <message>`, with the
  `message` of the JSON error body, or the HTTP status code when there is none;
- a request without a token: `No API token configured`;
- a missing instance URL, at construction: `No Forgejo URL configured.`;
- a missing mandatory argument (for example `sha required to delete a file`).

Methods that ask a yes/no question (`$repo->collaborators->check($user)`,
`$repo->pulls->is_merged($index)`, `$org->members->check(undef, $user)`) return
true or false instead of croaking on the `404` that means "no".

```perl
my $repo = eval { $forgejo->repos->get('owner', 'missing') };
warn "no such repository: $@" unless $repo;
```

### Custom transport

Any object consuming `WWW::Forgejo::Role::IO`, i.e. providing
`call($request)` that returns a `WWW::Forgejo::HTTPResponse`, can replace the
default LWP backend:

```perl
my $forgejo = WWW::Forgejo->new(url => $url, token => $token, io => My::IO->new);
```

Requests and responses are logged through `Log::Any`; for a full HTTP trace of
the default backend run your script with `-MLWP::ConsoleLogger::Everywhere`.

## Tests

```bash
prove -l t/
```

The suite runs offline against a mock transport. The live tests
(`t/90-live-admin.t`, `t/91-live-comprehensive.t`, `t/92-live-comprehensive.t`)
skip themselves unless a test instance is configured:

```bash
export TEST_FORGEJO_URL=http://localhost:30080
export TEST_FORGEJO_TOKEN=...          # token of an admin user
export TEST_FORGEJO_ORG=testorg        # optional; also TEST_FORGEJO_REPO, TEST_FORGEJO_USER
prove -lv t/9*.t
```

The live tests create and delete data on the instance (users, organizations,
repositories, issues). Run them against a throwaway instance only;
`docker-compose.yaml`, `Makefile.docker`, `scripts/setup-forgejo-test.sh` and
`k8s/forgejo-test/` describe one, and `make -f Makefile.docker test` runs the
live tests against it. `t/42-live-tests-static.t` checks offline that the live
tests only call methods that exist.

## See also

- `Net::Async::Forgejo`, the asynchronous client built on this distribution
- [Forgejo](https://forgejo.org)

## Author

Torsten Raudssus <getty@cpan.org>

## License

This software is Copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself. See the `LICENSE` file.
