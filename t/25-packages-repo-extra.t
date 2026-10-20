#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);
use WWW::Forgejo::API::Packages;
use WWW::Forgejo::API::Repos;

# The endpoints the client did not cover yet: the link of a package to a
# repository, the lookup of a repository by its ID and the times of the
# contributors of a repository.
#
# Every call is made in an eval, so a method that does not exist shows up as a
# failed test instead of a dead file.

my ($client, $io) = mock_client();
my $base = 'https://forgejo.test/api/v1';

my $packages = WWW::Forgejo::API::Packages->new(client => $client);
my $repos    = WWW::Forgejo::API::Repos->new(client => $client);

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
# The packages
# ---------------------------------------------------------------------------

subtest 'a package is linked to a repository' => sub {
    $io->reset->add(200, '{}');
    value(sub { $packages->link('owner', 'generic', 'my-package', 'my-repo') });
    is(request(), 'POST /packages/owner/generic/my-package/-/link/my-repo',
        'POST /packages/{owner}/{type}/{name}/-/link/{repo_name}');
};

subtest 'the link of a package is removed' => sub {
    $io->reset->add(200, '{}');
    value(sub { $packages->unlink('owner', 'generic', 'my-package') });
    is(request(), 'POST /packages/owner/generic/my-package/-/unlink',
        'POST /packages/{owner}/{type}/{name}/-/unlink');
};

subtest 'the names of a package are required' => sub {
    $io->reset;
    ok(error(sub { $packages->link('owner', 'generic', 'my-package') }), 'a missing repository dies');
    ok(error(sub { $packages->unlink('owner', 'generic') }), 'a missing package name dies');
    is($io->count, 0, 'no request was sent');
};

# ---------------------------------------------------------------------------
# The repository by its ID and the times of its contributors
# ---------------------------------------------------------------------------

subtest 'a repository by its ID' => sub {
    $io->reset->add(200, '{"id":42,"name":"repo","owner":{"login":"owner"}}');
    my $repo = value(sub { $repos->get_by_id(42) });
    is(request(), 'GET /repositories/42', 'GET /repositories/{id}');
    isa_ok($repo, 'WWW::Forgejo::Entity::Repo', 'get_by_id');
    is($repo ? $repo->data->{id} : undef, 42, 'the repository is decoded');
};

subtest 'the ID of a repository is required' => sub {
    $io->reset;
    ok(error(sub { $repos->get_by_id() }), 'a missing ID dies');
    ok(error(sub { $repos->get_by_id('') }), 'an empty ID dies');
    is($io->count, 0, 'no request was sent');
};

subtest 'the times of the contributors' => sub {
    $io->reset->add(200, '[{"user":"owner","total_seconds":10}]');
    my $times = value(sub { $repos->times('owner', 'repo') });
    is(request(), 'GET /repos/owner/repo/times', 'GET /repos/{owner}/{repo}/times');
    is(ref $times, 'ARRAY', 'the times are an arrayref');
    is($times->[0]{total_seconds}, 10, 'the times are decoded');
};

subtest 'the times of one contributor' => sub {
    $io->reset->add(200, '[{"timestamp":"2024-01-01T00:00:00Z"}]');
    my $times = value(sub { $repos->times_by_user('owner', 'repo', 'user') });
    is(request(), 'GET /repos/owner/repo/times/user', 'GET /repos/{owner}/{repo}/times/{user}');
    is(ref $times, 'ARRAY', 'the times are an arrayref');
};

subtest 'the name of the contributor is required' => sub {
    $io->reset;
    ok(error(sub { $repos->times_by_user('owner', 'repo') }), 'a missing user name dies');
    is($io->count, 0, 'no request was sent');
};

done_testing;
