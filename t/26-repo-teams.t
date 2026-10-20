#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);
use WWW::Forgejo::Entity::Repo;

# The teams that have access to a repository: a controller of their own, so the
# entity of the repository hands it out.
#
# The controller is new, so it is loaded at runtime: a client without it fails
# the test below instead of the whole file.

my ($client, $io) = mock_client();
my $base = 'https://forgejo.test/api/v1';

my $class  = 'WWW::Forgejo::API::Repo::Teams';
my $loaded = eval { require WWW::Forgejo::API::Repo::Teams; 1 };
diag("the controller is missing: $@") unless $loaded;

sub teams {
    return undef unless $loaded;
    return $class->new(client => $client, owner => 'owner', repo => 'repo');
}

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

# The value of an expression, or undef when it dies.
sub value { return eval { $_[0]->() } }

# The message of the exception of an expression, or the empty string.
sub error {
    my $err = '';
    eval { $_[0]->() };
    $err = $@ if $@;
    return $err;
}

subtest 'the teams of a repository' => sub {
    my $teams = teams();
    unless ($teams) {
        fail('the controller for the teams of a repository exists');
        return;
    }
    $io->reset->add(200, '[{"id":1,"name":"Developers"}]');
    my $list = value(sub { $teams->list });
    is(request(), 'GET /repos/owner/repo/teams', 'GET /repos/{owner}/{repo}/teams');
    is(ref $list, 'ARRAY', 'the teams are an arrayref');
    is($list->[0]{name}, 'Developers', 'the teams are decoded');
};

subtest 'one team of a repository' => sub {
    my $teams = teams();
    unless ($teams) {
        fail('the controller for the teams of a repository exists');
        return;
    }
    $io->reset->add(200, '{"id":1,"name":"Developers"}');
    my $team = value(sub { $teams->get(1) });
    is(request(), 'GET /repos/owner/repo/teams/1', 'GET /repos/{owner}/{repo}/teams/{team}');
    is($team->{name}, 'Developers', 'the team is decoded');
};

subtest 'a team gets access to the repository' => sub {
    my $teams = teams();
    unless ($teams) {
        fail('the controller for the teams of a repository exists');
        return;
    }
    $io->reset->add(200, '{}');
    my $added = value(sub { $teams->add(1) });
    is(request(), 'PUT /repos/owner/repo/teams/1', 'PUT /repos/{owner}/{repo}/teams/{team}');
    is($added, 1, 'the method returns true');
};

subtest 'the access of a team is taken away' => sub {
    my $teams = teams();
    unless ($teams) {
        fail('the controller for the teams of a repository exists');
        return;
    }
    $io->reset->add(200, '{}');
    my $removed = value(sub { $teams->remove(1) });
    is(request(), 'DELETE /repos/owner/repo/teams/1', 'DELETE /repos/{owner}/{repo}/teams/{team}');
    is($removed, 1, 'the method returns true');
};

subtest 'the ID of a team is required' => sub {
    my $teams = teams();
    unless ($teams) {
        fail('the controller for the teams of a repository exists');
        return;
    }
    $io->reset;
    ok(error(sub { $teams->get() }), 'a missing ID dies');
    ok(error(sub { $teams->add('') }), 'an empty ID dies');
    ok(error(sub { $teams->remove(undef) }), 'a missing ID dies');
    is($io->count, 0, 'no request was sent');
};

subtest 'the entity of the repository hands the controller out' => sub {
    my $repo = WWW::Forgejo::Entity::Repo->new(
        client => $client,
        owner  => 'owner',
        repo   => 'repo',
    );
    my $teams = eval { $repo->teams };
    unless ($teams) {
        fail('the entity of the repository knows the teams');
        return;
    }
    isa_ok($teams, 'WWW::Forgejo::API::Repo::Teams', 'the teams accessor');
    is($teams->owner, 'owner', 'the controller is bound to the owner');
    is($teams->repo, 'repo', 'the controller is bound to the repository');
};

done_testing;
