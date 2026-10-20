#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);
use WWW::Forgejo::API::Orgs;
use WWW::Forgejo::API::Org::Actions;
use WWW::Forgejo::API::Org::Quota;

# The organization endpoints the client did not cover yet: the avatar, the
# activity feed, the runners with their jobs and the quota of the
# organization.
#
# Every call is made in an eval, so a method that does not exist shows up as a
# failed test instead of a dead file.

my ($client, $io) = mock_client();
my $base = 'https://forgejo.test/api/v1';

my $orgs = WWW::Forgejo::API::Orgs->new(client => $client);
my $actions = WWW::Forgejo::API::Org::Actions->new(client => $client, owner => 'my-org');
my $quota   = WWW::Forgejo::API::Org::Quota->new(client => $client, owner => 'my-org');

sub request {
    my $last = $io->last or return '(no request)';
    my $url = substr($last->url, length $base);
    $url =~ s/\?.*//;
    return $last->method . ' ' . $url;
}

sub body {
    my $last = $io->last or return undef;
    return $last->has_content ? decode_json($last->content) : undef;
}

# The value of an expression, or undef when it dies.
sub value { return eval { $_[0]->() } }

# The message of the croak of an expression, or the empty string when it did
# not die.
sub error { my $r = eval { $_[0]->() }; return $@ ? $@ : '' }

# ---------------------------------------------------------------------------
# The avatar
# ---------------------------------------------------------------------------

subtest 'the avatar of the organization' => sub {
    $io->reset->add(204, '');
    my $set = value(sub { $orgs->set_avatar('my-org', image => 'aW1hZ2U=') });
    is(request(), 'POST /orgs/my-org/avatar', 'POST /orgs/{org}/avatar');
    is_deeply(body(), { image => 'aW1hZ2U=' }, 'the image is the body of the request');
    ok($set, 'set_avatar returns true');

    $io->reset->add(204, '');
    my $deleted = value(sub { $orgs->delete_avatar('my-org') });
    is(request(), 'DELETE /orgs/my-org/avatar', 'DELETE /orgs/{org}/avatar');
    ok($deleted, 'delete_avatar returns true');
};

subtest 'the avatar needs an organization and an image' => sub {
    like(error(sub { $orgs->set_avatar(undef, image => 'x') }), qr/Organization name required/,
        'set_avatar without a name croaks');
    like(error(sub { $orgs->set_avatar('my-org') }), qr/Avatar image required/,
        'set_avatar without an image croaks');
    like(error(sub { $orgs->delete_avatar(undef) }), qr/Organization name required/,
        'delete_avatar without a name croaks');
};

# ---------------------------------------------------------------------------
# The activity feed
# ---------------------------------------------------------------------------

subtest 'the activity feed of the organization' => sub {
    $io->reset->add(200, '[]');
    my $activities = value(sub { $orgs->activities('my-org') });
    is(request(), 'GET /orgs/my-org/activities/feeds', 'GET /orgs/{org}/activities/feeds');
    is(ref $activities, 'ARRAY', 'activities returns an arrayref') or return;

    $io->reset->add(200, '[]');
    value(sub { $orgs->activities('my-org', page => 2) });
    like($io->last->url, qr/\?page=2\z/, 'the named arguments are the query string');
};

# ---------------------------------------------------------------------------
# The runners
# ---------------------------------------------------------------------------

subtest 'the runners of the organization' => sub {
    $io->reset->add(201, '{"id":1,"name":"runner-1"}');
    value(sub { $actions->create_runner(name => 'runner-1', description => 'A runner') });
    is(request(), 'POST /orgs/my-org/actions/runners', 'POST /orgs/{org}/actions/runners');
    is_deeply(body(), { name => 'runner-1', description => 'A runner' },
        'the name and the description are the body of the request');

    $io->reset->add(200, '[{"id":1,"name":"job-1"}]');
    my $jobs = value(sub { $actions->list_runner_jobs });
    is(request(), 'GET /orgs/my-org/actions/runners/jobs',
        'GET /orgs/{org}/actions/runners/jobs');
    is(ref $jobs, 'ARRAY', 'list_runner_jobs returns an arrayref') or return;
    is($jobs->[0]{name}, 'job-1', 'the name of the job');
};

# ---------------------------------------------------------------------------
# The quota
# ---------------------------------------------------------------------------

subtest 'the quota of the organization' => sub {
    $io->reset->add(200, '[]');
    my $artifacts = value(sub { $quota->artifacts });
    is(request(), 'GET /orgs/my-org/quota/artifacts', 'GET /orgs/{org}/quota/artifacts');
    is(ref $artifacts, 'ARRAY', 'artifacts returns an arrayref') or return;

    $io->reset->add(200, '[]');
    value(sub { $quota->attachments });
    is(request(), 'GET /orgs/my-org/quota/attachments', 'GET /orgs/{org}/quota/attachments');

    $io->reset->add(200, '[]');
    value(sub { $quota->packages });
    is(request(), 'GET /orgs/my-org/quota/packages', 'GET /orgs/{org}/quota/packages');

    $io->reset->add(200, 'true');
    my $ok = value(sub { $quota->check(subject => 'size:repos:all') });
    is(request(), 'GET /orgs/my-org/quota/check', 'GET /orgs/{org}/quota/check');
    like($io->last->url, qr/subject=size%3Arepos%3Aall/, 'the subject is the query string');
    ok($ok, 'check returns the verdict of the API');

    like(error(sub { $quota->check }), qr/Quota subject required/,
        'check without a subject croaks');
};

# ---------------------------------------------------------------------------
# The names of the paths are escaped
# ---------------------------------------------------------------------------

subtest 'the names of the paths are escaped' => sub {
    $io->reset->add(200, '[]');
    value(sub { $orgs->activities('my org') });
    is(request(), 'GET /orgs/my%20org/activities/feeds', 'the parts of the path are escaped');
};

done_testing;
