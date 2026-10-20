#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);
use WWW::Forgejo::API::Admin;
use WWW::Forgejo::API::Admin::Users;
use WWW::Forgejo::API::Admin::Runners;

# The site administration endpoints the client did not cover yet: the
# organizations, the email addresses and the unadopted repositories of the
# instance, the access tokens of a user and the registration and the jobs of
# the runners.
#
# Every call is made in an eval, so a method that does not exist shows up as a
# failed test instead of a dead file.

my ($client, $io) = mock_client();
my $base = 'https://forgejo.test/api/v1';

my $admin  = WWW::Forgejo::API::Admin->new(client => $client);
my $users  = WWW::Forgejo::API::Admin::Users->new(client => $client);
my $runners = WWW::Forgejo::API::Admin::Runners->new(client => $client);

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
# The instance itself
# ---------------------------------------------------------------------------

subtest 'the organizations of the instance' => sub {
    $io->reset->add(200, '[]');
    my $orgs = value(sub { $admin->orgs });
    is(request(), 'GET /admin/orgs', 'GET /admin/orgs');
    is(ref $orgs, 'ARRAY', 'the organizations are an arrayref');
};

subtest 'the email addresses of the instance' => sub {
    $io->reset->add(200, '[]');
    my $emails = value(sub { $admin->emails });
    is(request(), 'GET /admin/emails', 'GET /admin/emails');
    is(ref $emails, 'ARRAY', 'the email addresses are an arrayref');
};

subtest 'the unadopted repositories' => sub {
    $io->reset->add(200, '[]');
    my $repos = value(sub { $admin->unadopted });
    is(request(), 'GET /admin/unadopted', 'GET /admin/unadopted');
    is(ref $repos, 'ARRAY', 'the repositories are an arrayref');
};

subtest 'an unadopted repository is adopted' => sub {
    $io->reset->add(200, '{}');
    my $adopted = value(sub { $admin->adopt('owner', 'repo') });
    is(request(), 'POST /admin/unadopted/owner/repo', 'POST /admin/unadopted/{owner}/{repo}');
    is($adopted, 1, 'the method returns true');
};

subtest 'an unadopted repository is deleted' => sub {
    $io->reset->add(200, '{}');
    my $deleted = value(sub { $admin->delete_unadopted('owner', 'repo') });
    is(request(), 'DELETE /admin/unadopted/owner/repo', 'DELETE /admin/unadopted/{owner}/{repo}');
    is($deleted, 1, 'the method returns true');
};

subtest 'the names of an unadopted repository are required' => sub {
    $io->reset;
    ok(error(sub { $admin->adopt('owner') }), 'a missing repository dies');
    ok(error(sub { $admin->delete_unadopted(undef, 'repo') }), 'a missing owner dies');
    is($io->count, 0, 'no request was sent');
};

# ---------------------------------------------------------------------------
# The access tokens of a user
# ---------------------------------------------------------------------------

subtest 'the access tokens of a user' => sub {
    $io->reset->add(200, '[]');
    my $tokens = value(sub { $users->list_tokens('user') });
    is(request(), 'GET /admin/users/user/tokens', 'GET /admin/users/{username}/tokens');
    is(ref $tokens, 'ARRAY', 'the tokens are an arrayref');
};

subtest 'an access token of a user is created' => sub {
    $io->reset->add(200, '{"sha1":"SECRET","name":"My token"}');
    my $token = value(sub { $users->create_token('user', name => 'My token') });
    is(request(), 'POST /admin/users/user/tokens', 'POST /admin/users/{username}/tokens');
    is(body()->{name}, 'My token', 'the name is sent in the body');
    is($token->{sha1}, 'SECRET', 'the token is decoded');
};

subtest 'an access token of a user is deleted' => sub {
    $io->reset->add(200, '{}');
    my $deleted = value(sub { $users->delete_token('user', 'My token') });
    is(request(), 'DELETE /admin/users/user/tokens/My%20token', 'DELETE /admin/users/{username}/tokens/{token}');
    is($deleted, 1, 'the method returns true');
};

subtest 'the names of the access token are required' => sub {
    $io->reset;
    ok(error(sub { $users->list_tokens() }), 'a missing user name dies');
    ok(error(sub { $users->delete_token('user') }), 'a missing token dies');
    is($io->count, 0, 'no request was sent');
};

# ---------------------------------------------------------------------------
# The runners
# ---------------------------------------------------------------------------

subtest 'a runner is registered' => sub {
    $io->reset->add(200, '{"id":1,"name":"my-runner"}');
    my $runner = value(sub { $runners->create(name => 'my-runner') });
    is(request(), 'POST /admin/actions/runners', 'POST /admin/actions/runners');
    is(body()->{name}, 'my-runner', 'the name is sent in the body');
    is($runner->{name}, 'my-runner', 'the runner is decoded');
};

subtest 'the name of a runner is required' => sub {
    $io->reset;
    ok(error(sub { $runners->create(description => 'no name') }), 'a missing name dies');
    is($io->count, 0, 'no request was sent');
};

subtest 'the jobs of the runners' => sub {
    $io->reset->add(200, '{"workflow_jobs":[]}');
    my $jobs = value(sub { $runners->jobs });
    is(request(), 'GET /admin/actions/runners/jobs', 'GET /admin/actions/runners/jobs');
    is(ref $jobs, 'HASH', 'the jobs are decoded');
};

subtest 'the jobs of the global runners' => sub {
    $io->reset->add(200, '{"workflow_jobs":[]}');
    my $jobs = value(sub { $runners->global_jobs });
    is(request(), 'GET /admin/runners/jobs', 'GET /admin/runners/jobs');
    is(ref $jobs, 'HASH', 'the jobs are decoded');
};

subtest 'the registration token of the global runners' => sub {
    $io->reset->add(200, '{"token":"SECRET"}');
    my $token = value(sub { $runners->global_registration_token });
    is(request(), 'GET /admin/runners/registration-token', 'GET /admin/runners/registration-token');
    is($token->{token}, 'SECRET', 'the token is decoded');
};

done_testing;
