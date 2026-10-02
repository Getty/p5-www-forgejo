#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Scalar::Util qw(weaken);
use lib 't/lib';
use MockForgejo qw(mock_client);
use WWW::Forgejo;

# One IO object shared by clients that are created and thrown away.
my (undef, $io) = mock_client();

sub fresh {
    return WWW::Forgejo->new(url => 'https://forgejo.test', token => 't', io => $io);
}

subtest 'controllers keep a temporary client alive' => sub {
    $io->reset->add(200, '{"login":"octocat"}');
    my $user = eval { fresh()->users->get('octocat') };
    is($@, '', 'users->get on a temporary client does not die');
    is($user->{login}, 'octocat', 'and returns the data');

    $io->reset->add(200, '{"login":"me"}');
    my $me = eval { fresh()->current_user->get };
    is($@, '', 'current_user->get on a temporary client does not die');
    is($me->{login}, 'me', 'and returns the data');
};

subtest 'whole chains on a temporary client, down to calls on the entity' => sub {
    # users->get hands out plain data; the follow-up goes through the controller
    $io->reset->add(200, '[{"name":"r1"},{"name":"r2"}]');
    my $repos = eval { fresh()->users->repos('octocat') };
    is($@, '', 'users->repos on a temporary client does not die');
    is(scalar @$repos, 2, 'and returns the repositories');

    $io->reset->add(200, '[{"name":"mine"}]');
    my $mine = eval { fresh()->current_user->repos(limit => 5) };
    is($@, '', 'current_user->repos on a temporary client does not die');
    is($mine->[0]{name}, 'mine', 'and returns the repositories');

    # repository entity: the per-repository controller needs the client again
    $io->reset->add(200, '{"name":"r","owner":{"login":"o"}}')->add(200, '[{"number":1,"title":"a"},{"number":2,"title":"b"}]');
    my @issues = eval { fresh()->repos->get('o', 'r')->issues->list(state => 'open') };
    is($@, '', 'repos->get->issues->list as one chain does not die');
    is_deeply([ map { $_->number } @issues ], [ 1, 2 ], 'and returns the issues');
    is($io->count, 2, 'two requests were sent');
    like($io->last->url, qr{/repos/o/r/issues\?state=open\z}, 'the second one for the issues of that repository');
    is($io->last->headers->{Authorization}, 'token t', 'still authenticated');

    # the entities of the list still reach the client after the chain is gone
    $io->reset->add(200, '{"name":"r"}');
    my $updated = eval { fresh()->repos->get('o', 'r')->update({ description => 'd' }) };
    is($@, '', 'repos->get->update as one chain does not die');
    is($io->last->method, 'PATCH', 'and sends the update');

    # organization entity
    $io->reset->add(200, '{"name":"org"}')->add(200, '[{"id":7,"name":"Owners"}]');
    my $teams = eval { fresh()->orgs->get('org')->teams->list };
    is($@, '', 'orgs->get->teams->list as one chain does not die');
    is($teams->[0]{id}, 7, 'and returns the teams');

    # team entity: its methods go back through $client->teams
    $io->reset->add(200, '{"id":7,"name":"Owners"}')->add(200, '[{"login":"octocat"}]');
    my $members = eval { fresh()->teams->get(7)->list_members };
    is($@, '', 'teams->get->list_members as one chain does not die');
    is($members->[0]{login}, 'octocat', 'and returns the members');
    like($io->last->url, qr{/teams/7/members\z}, 'requested for that team');
};

subtest 'a chain leaves nothing behind' => sub {
    my $weak;
    {
        $io->reset->add(200, '{"name":"r"}')->add(200, '[{"number":1}]');
        my $client = fresh();
        $weak = $client;
        weaken($weak);
        my @issues = $client->repos->get('o', 'r')->issues->list;
        undef $client;
        ok($weak, 'the entities keep the client alive after its variable is gone');
        ok($issues[0]->client == $weak, 'it is the same client');
    }
    ok(!defined $weak, 'and it is destroyed with the last entity');

    # A client that only ever exists as the temporary at the head of a chain.
    my $temporary = sub { my $client = fresh(); weaken($weak = $client); $client };
    $io->reset->add(200, '{"login":"octocat"}');
    my $user = $temporary->()->users->get('octocat');
    is($user->{login}, 'octocat', 'chain on a temporary client');
    ok(!defined $weak, 'the temporary client is destroyed right after its chain');
};

subtest 'a controller outlives the variable holding the client' => sub {
    my $users = do { my $client = fresh(); $client->users };
    $io->reset->add(200, '{"login":"octocat"}');
    is(eval { $users->get('octocat')->{login} }, 'octocat', 'controller still works');
};

subtest 'an entity outlives the variable holding the client' => sub {
    $io->reset->add(200, '{"name":"r","full_name":"o/r"}');
    my $repo = do { my $client = fresh(); $client->repos->get('o', 'r') };
    ok($repo->client, 'entity still has its client');

    $io->add(200, '[{"number":1,"title":"a"}]');
    my @issues = eval { $repo->issues->list };
    is($@, '', 'per-repository controller works');
    is(scalar @issues, 1, 'one issue');
    ok($issues[0]->client, 'nested entity has the client too');
};

subtest 'nothing leaks: the client is freed with its last user' => sub {
    my $weak;
    {
        my $client = fresh();
        $weak = $client;
        weaken($weak);

        # touch every controller accessor and a few entities
        $client->$_ for qw(misc users orgs teams notifications packages repos current_user admin activitypub);
        $io->reset->add(200, '{"name":"r"}');
        my $repo = $client->repos->get('o', 'r');
        $repo->$_ for qw(issues pulls branches releases);
        $io->add(200, '{"name":"org","username":"org"}');
        my $org = $client->orgs->get('org');
        $org->teams;
        ok($weak, 'alive inside the scope');
    }
    ok(!defined $weak, 'client destroyed once the scope is left (no reference cycle)');
};

subtest 'controller accessors return the right classes' => sub {
    my $client = fresh();
    my %class = (
        misc => 'Misc', users => 'Users', orgs => 'Orgs', teams => 'Teams',
        notifications => 'Notifications', packages => 'Packages', repos => 'Repos',
        current_user => 'CurrentUser', admin => 'Admin', activitypub => 'ActivityPub',
    );
    for my $acc (sort keys %class) {
        my $ctl = $client->$acc;
        isa_ok($ctl, "WWW::Forgejo::API::$class{$acc}", "\$client->$acc");
        is($ctl->client, $client, "$acc is bound to the client");
    }
};

done_testing;
