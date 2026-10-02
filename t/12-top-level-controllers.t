#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);
use WWW::Forgejo::API::Org::Actions;
use WWW::Forgejo::API::Org::Hooks;
use WWW::Forgejo::API::Org::Labels;

# Regression tests for operations that used the wrong verb, path or body
# before they were checked against the Swagger document.

my ($client, $io) = mock_client();
my $base = 'https://forgejo.test/api/v1';

sub request { $io->last->method . ' ' . substr($io->last->url, length $base) }
sub body    { $io->last->has_content ? decode_json($io->last->content) : undef }

# ---------------------------------------------------------------------------
# ActivityPub: every method
# ---------------------------------------------------------------------------

subtest 'activitypub actor' => sub {
    $io->reset->add(200, '{"id":"https://forgejo.test/api/v1/activitypub/user-id/7","type":"Person"}');
    my $actor = $client->activitypub->actor(7);
    is(request(), 'GET /activitypub/user-id/7', 'GET /activitypub/user-id/{user-id}');
    is($actor->{type}, 'Person', 'actor document returned');
};

subtest 'activitypub inbox' => sub {
    $io->reset->add(202, '');
    my $activity = { type => 'Follow', actor => 'https://other.test/users/a' };
    $client->activitypub->inbox(7, $activity);
    is(request(), 'POST /activitypub/user-id/7/inbox', 'POST /activitypub/user-id/{user-id}/inbox');
    is_deeply(body(), $activity, 'the activity is the JSON body');
};

subtest 'activitypub outbox' => sub {
    $io->reset->add(200, '{"type":"OrderedCollection","totalItems":0}');
    my $outbox = $client->activitypub->outbox(7);
    is(request(), 'GET /activitypub/user-id/7/outbox', 'GET /activitypub/user-id/{user-id}/outbox');
    is($outbox->{type}, 'OrderedCollection', 'outbox returned');
    ok(!$io->last->has_content, 'no body');
};

subtest 'activitypub escapes the user id' => sub {
    $io->reset->add(200, '{}');
    $client->activitypub->actor('a/b');
    is(request(), 'GET /activitypub/user-id/a%2Fb', 'id escaped');
};

# ---------------------------------------------------------------------------
# Organization actions: the runner registration token is read with GET
# ---------------------------------------------------------------------------

subtest 'org actions runner_registration_token' => sub {
    my $actions = WWW::Forgejo::API::Org::Actions->new(client => $client, owner => 'myorg');
    ok(!$actions->can('regenerate_runner_token'), 'no regenerate_runner_token: the API cannot regenerate');

    $io->reset->add(200, '{"token":"abc"}');
    my $token = $actions->runner_registration_token;
    is(request(), 'GET /orgs/myorg/actions/runners/registration-token',
        'GET /orgs/{org}/actions/runners/registration-token');
    is($token->{token}, 'abc', 'token returned');

    $io->reset->add(200, '{"token":"def"}');
    $actions->runner_registration_token('other');
    is(request(), 'GET /orgs/other/actions/runners/registration-token', 'explicit organization wins');
};

subtest 'org actions secrets and variables' => sub {
    my $actions = WWW::Forgejo::API::Org::Actions->new(client => $client, owner => 'myorg');

    $io->reset->add(204, '');
    $actions->set_secret(undef, 'KEY', { data => 'v' });
    is(request(), 'PUT /orgs/myorg/actions/secrets/KEY', 'set_secret');
    is_deeply(body(), { data => 'v' }, 'set_secret body');

    $io->reset->add(204, '');
    $actions->create_variable(undef, 'STAGE', { value => 'prod' });
    is(request(), 'POST /orgs/myorg/actions/variables/STAGE', 'create_variable');
    is_deeply(body(), { value => 'prod' }, 'create_variable body');

    $io->reset->add(204, '');
    $actions->set_variable(undef, 'STAGE', { value => 'test' });
    is(request(), 'PUT /orgs/myorg/actions/variables/STAGE', 'set_variable');
};

# ---------------------------------------------------------------------------
# edit is PATCH
# ---------------------------------------------------------------------------

subtest 'orgs edit' => sub {
    $io->reset->add(200, '{"id":1,"name":"myorg","username":"myorg","description":"new"}');
    my $org = $client->orgs->edit('myorg', description => 'new');
    is(request(), 'PATCH /orgs/myorg', 'PATCH /orgs/{org}');
    is_deeply(body(), { description => 'new' }, 'body');
    isa_ok($org, 'WWW::Forgejo::Entity::Org');
    is($org->data->{description}, 'new', 'edited organization returned');
};

subtest 'orgs create and rename' => sub {
    $io->reset->add(201, '{"id":2,"name":"neworg","username":"neworg"}');
    my $org = $client->orgs->create(username => 'neworg', visibility => 'private');
    is(request(), 'POST /orgs', 'POST /orgs');
    is_deeply(body(), { username => 'neworg', visibility => 'private' }, 'create body');
    is($org->name, 'neworg', 'created organization');

    $io->reset;
    eval { $client->orgs->create(description => 'x') };
    like($@, qr/Organization username required/, 'create croaks without username');
    is($io->count, 0, 'nothing sent');

    $io->reset->add(204, '');
    $client->orgs->rename('neworg', new_name => 'renamed');
    is(request(), 'POST /orgs/neworg/rename', 'POST /orgs/{org}/rename');
    is_deeply(body(), { new_name => 'renamed' }, 'rename body');
};

subtest 'teams create and edit' => sub {
    $io->reset->add(201, '{"id":5,"name":"devs"}');
    my $team = $client->teams->create(org => 'myorg', name => 'devs', permission => 'write');
    is(request(), 'POST /orgs/myorg/teams', 'POST /orgs/{org}/teams');
    is_deeply(body(), { name => 'devs', permission => 'write' }, 'org is not part of the body');
    isa_ok($team, 'WWW::Forgejo::Entity::Team');
    is($team->id, 5, 'created team');

    $io->reset->add(200, '{"id":5,"name":"developers"}');
    $team = $client->teams->edit(5, name => 'developers');
    is(request(), 'PATCH /teams/5', 'PATCH /teams/{id}');
    is_deeply(body(), { name => 'developers' }, 'edit body');
    is($team->name, 'developers', 'edited team');

    $io->reset->add(200, '{"id":5,"name":"devs2"}');
    $team->update(name => 'devs2');
    is(request(), 'PATCH /teams/5', 'Entity::Team->update goes the same way');
    is($team->name, 'devs2', 'entity data refreshed');
};

subtest 'org hooks edit' => sub {
    my $hooks = WWW::Forgejo::API::Org::Hooks->new(client => $client, owner => 'myorg');
    $io->reset->add(200, '{"id":3,"active":false}');
    my $hook = $hooks->edit(undef, 3, active => \0);
    is(request(), 'PATCH /orgs/myorg/hooks/3', 'PATCH /orgs/{org}/hooks/{id}');
    is_deeply(body(), { active => JSON::MaybeXS::false }, 'body');
    is($hook->{id}, 3, 'hook returned');

    $io->reset;
    eval { $hooks->edit(undef, undef, active => \0) };
    like($@, qr/Hook ID required/, 'croaks without hook id');
    is($io->count, 0, 'nothing sent');
};

subtest 'org labels edit' => sub {
    my $labels = WWW::Forgejo::API::Org::Labels->new(client => $client, owner => 'myorg');
    $io->reset->add(200, '{"id":4,"name":"defect"}');
    my $label = $labels->edit(undef, 4, name => 'defect');
    is(request(), 'PATCH /orgs/myorg/labels/4', 'PATCH /orgs/{org}/labels/{id}');
    is_deeply(body(), { name => 'defect' }, 'body');
    is($label->{name}, 'defect', 'label returned');
};

subtest 'an organization controller without owner needs the name' => sub {
    my $hooks = WWW::Forgejo::API::Org::Hooks->new(client => $client);
    $io->reset;
    eval { $hooks->list };
    like($@, qr/Organization name required/, 'croaks');
    is($io->count, 0, 'nothing sent');
};

# ---------------------------------------------------------------------------
# Repos: filters reach the query string
# ---------------------------------------------------------------------------

subtest 'repos list_for_org forwards its filters' => sub {
    $io->reset->add(200, '[{"name":"r1"},{"name":"r2"}]');
    my $repos = $client->repos->list_for_org('myorg', page => 2, limit => 2);
    is(request(), 'GET /orgs/myorg/repos?limit=2&page=2', 'query string');
    is(scalar @$repos, 2, 'two repositories');
    isa_ok($repos->[0], 'WWW::Forgejo::Entity::Repo');
    is($repos->[0]->owner, 'myorg', 'owner');
    is($repos->[1]->repo, 'r2', 'name');
};

done_testing;
