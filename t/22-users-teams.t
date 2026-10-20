#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);
use WWW::Forgejo::API::Users;
use WWW::Forgejo::API::Teams;

# The endpoints of the users and of the teams the client did not cover yet: the
# check of a follow relation, the permissions of a user in an organization, the
# membership of one user in a team, the activity feed of a team and one
# repository of a team.
#
# Every call is made in an eval, so a method that does not exist shows up as a
# failed test instead of a dead file.

my ($client, $io) = mock_client();
my $base = 'https://forgejo.test/api/v1';

my $users = WWW::Forgejo::API::Users->new(client => $client);
my $teams = WWW::Forgejo::API::Teams->new(client => $client);

sub request {
    my $last = $io->last or return '(no request)';
    return $last->method . ' ' . path();
}

sub path {
    my $last = $io->last or return '(no request)';
    my $url = substr($last->url, length $base);
    $url =~ s/\?.*//;
    return $url;
}

sub body {
    my $last = $io->last or return {};
    return $last->has_content ? decode_json($last->content) : {};
}

# The value of an expression, or undef when it dies.
sub value { return eval { $_[0]->() } }

# The message of the exception of an expression, or the empty string.
sub error {
    my $err = '';
    eval { $_[0]->() };
    $err = $@ if $@;
    return $err;
}

# ---------------------------------------------------------------------------
# The users
# ---------------------------------------------------------------------------

subtest 'the check of a follow relation' => sub {
    $io->reset->add(200, '{"following":true,"user":{"login":"other"}}');
    my $relation = value(sub { $users->following_check('user', 'other') });
    is(request(), 'GET /users/user/following/other', 'GET /users/{username}/following/{target}');
    ok($relation->{following}, 'the relation is decoded');
};

subtest 'the names of a follow relation are required' => sub {
    $io->reset;
    ok(error(sub { $users->following_check('user') }), 'a missing target dies');
    ok(error(sub { $users->following_check(undef, 'other') }), 'a missing user dies');
    is($io->count, 0, 'no request was sent');
};

subtest 'the permissions of a user in an organization' => sub {
    $io->reset->add(200, '{"organization":{"name":"my-org"},"permission":"write"}');
    my $permissions = value(sub { $users->org_permissions('user', 'my-org') });
    is(request(), 'GET /users/user/orgs/my-org/permissions', 'GET /users/{username}/orgs/{org}/permissions');
    is($permissions->{permission}, 'write', 'the permissions are decoded');
};

subtest 'the names of the permissions are required' => sub {
    $io->reset;
    ok(error(sub { $users->org_permissions('user') }), 'a missing organization dies');
    ok(error(sub { $users->org_permissions(undef, 'my-org') }), 'a missing user dies');
    is($io->count, 0, 'no request was sent');
};

# ---------------------------------------------------------------------------
# The teams
# ---------------------------------------------------------------------------

subtest 'the membership of one user in a team' => sub {
    $io->reset->add(200, '{"state":"active"}');
    my $member = value(sub { $teams->get_member(7, 'user') });
    is(request(), 'GET /teams/7/members/user', 'GET /teams/{id}/members/{username}');
    is($member->{state}, 'active', 'the membership is decoded');
};

subtest 'the name of the member is required' => sub {
    $io->reset;
    ok(error(sub { $teams->get_member(7) }), 'a missing user name dies');
    is($io->count, 0, 'no request was sent');
};

subtest 'the activity feed of a team' => sub {
    $io->reset->add(200, '[]');
    my $feed = value(sub { $teams->activities(7) });
    is(request(), 'GET /teams/7/activities/feeds', 'GET /teams/{id}/activities/feeds');
    is(ref $feed, 'ARRAY', 'the feed is an arrayref');
};

subtest 'one repository of a team' => sub {
    $io->reset->add(200, '{"name":"repo"}');
    my $repo = value(sub { $teams->get_repo(7, 'my-org', 'repo') });
    is(request(), 'GET /teams/7/repos/my-org/repo', 'GET /teams/{id}/repos/{org}/{repo}');
    is($repo->{name}, 'repo', 'the repository is decoded');
};

subtest 'the names of a repository of a team are required' => sub {
    $io->reset;
    ok(error(sub { $teams->get_repo(7, 'my-org') }), 'a missing repository dies');
    ok(error(sub { $teams->get_repo(7, undef, 'repo') }), 'a missing organization dies');
    is($io->count, 0, 'no request was sent');
};

done_testing;
