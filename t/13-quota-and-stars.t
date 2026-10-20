#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);

# The quota administration endpoints and the stars and follows of the current
# user have their own controller methods: the quota groups and rules come back
# as entities, the stars and follows are asked for with their status code.
#
# Every call is made in an eval, so a method that does not exist shows up as a
# failed test instead of a dead file.

my ($client, $io) = mock_client();
my $base = 'https://forgejo.test/api/v1';

sub request {
    my $last = $io->last or return '(no request)';
    return $last->method . ' ' . substr($last->url, length $base);
}

sub body {
    my $last = $io->last or return undef;
    return $last->has_content ? decode_json($last->content) : undef;
}

# The value of an expression, or undef when it dies.
sub value { return eval { $_[0]->() } }

# ---------------------------------------------------------------------------
# Admin quota: the groups
# ---------------------------------------------------------------------------

subtest 'admin quota: the groups are entities' => sub {
    $io->reset->add(200, '[{"name":"g1","rules":[{"name":"r1","limit":10,"subjects":["size:repos:all"]}]}]');
    my $groups = value(sub { $client->admin->quota->list_groups });
    is(request(), 'GET /admin/quota/groups', 'GET /admin/quota/groups');
    is(ref $groups, 'ARRAY', 'list_groups returns an arrayref') or return;
    isa_ok($groups->[0], 'WWW::Forgejo::Entity::QuotaGroup');
    is(value(sub { $groups->[0]->name }), 'g1', 'the name of the group');
    is(ref value(sub { $groups->[0]->rules->[0] }), 'WWW::Forgejo::Entity::QuotaRule',
        'the rules of the group are entities');
    is(value(sub { $groups->[0]->rules->[0]->limit }), 10, 'the limit of the rule of the group');
    is_deeply(value(sub { $groups->[0]->rules->[0]->subjects }), ['size:repos:all'],
        'the subjects of the rule');
};

subtest 'admin quota: get, create and delete a group' => sub {
    $io->reset->add(200, '{"name":"g1","rules":[]}');
    my $group = value(sub { $client->admin->quota->get_group('g1') });
    is(request(), 'GET /admin/quota/groups/g1', 'GET /admin/quota/groups/{group}');
    isa_ok($group, 'WWW::Forgejo::Entity::QuotaGroup');
    is(value(sub { $group->name }), 'g1', 'the group');

    $io->reset->add(201, '{"name":"g2","rules":[]}');
    my $created = value(sub { $client->admin->quota->create_group(name => 'g2') });
    is(request(), 'POST /admin/quota/groups', 'POST /admin/quota/groups');
    is_deeply(body(), { name => 'g2' }, 'the name is the body');
    isa_ok($created, 'WWW::Forgejo::Entity::QuotaGroup');

    $io->reset->add(204, '');
    value(sub { $client->admin->quota->delete_group('g2') });
    is(request(), 'DELETE /admin/quota/groups/g2', 'DELETE /admin/quota/groups/{group}');
};

# ---------------------------------------------------------------------------
# Admin quota: the rules
# ---------------------------------------------------------------------------

subtest 'admin quota: the rules are entities' => sub {
    $io->reset->add(200, '[{"name":"r1","limit":10,"subjects":[]}]');
    my $rules = value(sub { $client->admin->quota->list_rules });
    is(request(), 'GET /admin/quota/rules', 'GET /admin/quota/rules');
    is(ref $rules, 'ARRAY', 'list_rules returns an arrayref') or return;
    isa_ok($rules->[0], 'WWW::Forgejo::Entity::QuotaRule');
    is(value(sub { $rules->[0]->name }), 'r1', 'the name of the rule');
    is(value(sub { $rules->[0]->limit }), 10, 'the limit of the rule');
};

subtest 'admin quota: get, create, edit and delete a rule' => sub {
    $io->reset->add(200, '{"name":"r1","limit":10}');
    my $rule = value(sub { $client->admin->quota->get_rule('r1') });
    is(request(), 'GET /admin/quota/rules/r1', 'GET /admin/quota/rules/{rule}');
    isa_ok($rule, 'WWW::Forgejo::Entity::QuotaRule');

    $io->reset->add(201, '{"name":"r2","limit":10,"subjects":["size:repos:all"]}');
    my $created = value(sub {
        $client->admin->quota->create_rule(
            name     => 'r2',
            limit    => 10,
            subjects => ['size:repos:all'],
        );
    });
    is(request(), 'POST /admin/quota/rules', 'POST /admin/quota/rules');
    is_deeply(body(), { name => 'r2', limit => 10, subjects => ['size:repos:all'] },
        'the rule is the body');
    isa_ok($created, 'WWW::Forgejo::Entity::QuotaRule');

    $io->reset->add(200, '{"name":"r2","limit":20}');
    my $edited = value(sub { $client->admin->quota->edit_rule('r2', limit => 20) });
    is(request(), 'PATCH /admin/quota/rules/r2', 'PATCH /admin/quota/rules/{rule}');
    is_deeply(body(), { limit => 20 }, 'the new limit is the body');
    is(value(sub { $edited->limit }), 20, 'the edited rule');

    $io->reset->add(204, '');
    value(sub { $client->admin->quota->delete_rule('r2') });
    is(request(), 'DELETE /admin/quota/rules/r2', 'DELETE /admin/quota/rules/{rule}');
};

# ---------------------------------------------------------------------------
# Admin quota: the rules and the users of a group
# ---------------------------------------------------------------------------

subtest 'admin quota: the rules of a group' => sub {
    $io->reset->add(204, '');
    my $added = value(sub { $client->admin->quota->add_rule_to_group('g1', 'r1') });
    is(request(), 'PUT /admin/quota/groups/g1/rules/r1',
        'PUT /admin/quota/groups/{group}/rules/{rule}');
    ok($added, 'add_rule_to_group returns true');

    $io->reset->add(204, '');
    value(sub { $client->admin->quota->remove_rule_from_group('g1', 'r1') });
    is(request(), 'DELETE /admin/quota/groups/g1/rules/r1',
        'DELETE /admin/quota/groups/{group}/rules/{rule}');
};

subtest 'admin quota: the users of a group' => sub {
    $io->reset->add(200, '[{"login":"u1"}]');
    my $users = value(sub { $client->admin->quota->list_group_users('g1') });
    is(request(), 'GET /admin/quota/groups/g1/users',
        'GET /admin/quota/groups/{group}/users');
    is(ref $users, 'ARRAY', 'list_group_users returns an arrayref') or return;
    is($users->[0]{login}, 'u1', 'the user of the group');

    $io->reset->add(204, '');
    my $added = value(sub { $client->admin->quota->add_user_to_group('g1', 'u1') });
    is(request(), 'PUT /admin/quota/groups/g1/users/u1',
        'PUT /admin/quota/groups/{group}/users/{username}');
    ok($added, 'add_user_to_group returns true');

    $io->reset->add(204, '');
    value(sub { $client->admin->quota->remove_user_from_group('g1', 'u1') });
    is(request(), 'DELETE /admin/quota/groups/g1/users/u1',
        'DELETE /admin/quota/groups/{group}/users/{username}');
};

subtest 'admin quota: the names are required' => sub {
    $io->reset;
    eval { $client->admin->quota->create_group() };
    like($@, qr/Quota group name required/, 'create_group croaks without a name');
    is($io->count, 0, 'nothing sent');

    $io->reset;
    eval { $client->admin->quota->create_rule() };
    like($@, qr/Quota rule name required/, 'create_rule croaks without a name');
    is($io->count, 0, 'nothing sent');

    $io->reset;
    eval { $client->admin->quota->get_group('') };
    like($@, qr/Quota group name required/, 'get_group croaks without a name');
    is($io->count, 0, 'nothing sent');
};

# ---------------------------------------------------------------------------
# The stars and the follows of the current user
# ---------------------------------------------------------------------------

subtest 'current user: the stars of a repository' => sub {
    $io->reset->add(204, '');
    my $starred = value(sub { $client->current_user->star('owner', 'repo') });
    is(request(), 'PUT /user/starred/owner/repo', 'PUT /user/starred/{owner}/{repo}');
    ok($starred, 'star returns true');

    $io->reset->add(204, '');
    value(sub { $client->current_user->unstar('owner', 'repo') });
    is(request(), 'DELETE /user/starred/owner/repo', 'DELETE /user/starred/{owner}/{repo}');
};

subtest 'current user: the follows of a user' => sub {
    $io->reset->add(204, '');
    my $followed = value(sub { $client->current_user->follow('other') });
    is(request(), 'PUT /user/following/other', 'PUT /user/following/{username}');
    ok($followed, 'follow returns true');

    $io->reset->add(204, '');
    value(sub { $client->current_user->unfollow('other') });
    is(request(), 'DELETE /user/following/other', 'DELETE /user/following/{username}');
};

subtest 'current user: the stars and follows are asked for with the status code' => sub {
    $io->reset->add(404, '{"message":"not starred"}');
    my $starred = value(sub { $client->current_user->check_starred('owner', 'repo') });
    is(request(), 'GET /user/starred/owner/repo', 'GET /user/starred/{owner}/{repo}');
    ok(!$starred, 'not starred');

    $io->reset->add(204, '');
    my $following = value(sub { $client->current_user->check_following('other') });
    is(request(), 'GET /user/following/other', 'GET /user/following/{username}');
    ok($following, 'following');
};

subtest 'current user: the names are required' => sub {
    $io->reset;
    eval { $client->current_user->star('', 'repo') };
    like($@, qr/Repository owner required/, 'star croaks without an owner');
    is($io->count, 0, 'nothing sent');

    $io->reset;
    eval { $client->current_user->follow('') };
    like($@, qr/Username required/, 'follow croaks without a username');
    is($io->count, 0, 'nothing sent');
};

subtest 'the names of a path are escaped' => sub {
    $io->reset->add(204, '');
    value(sub { $client->current_user->star('a/b', 'c d') });
    is(request(), 'PUT /user/starred/a%2Fb/c%20d', 'the parts of the path are escaped');

    $io->reset->add(204, '');
    value(sub { $client->admin->quota->add_user_to_group('g/1', 'u 1') });
    is(request(), 'PUT /admin/quota/groups/g%2F1/users/u%201',
        'the parts of the path are escaped');
};

done_testing;
