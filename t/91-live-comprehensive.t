#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use WWW::Forgejo;

# Live smoke test: one read-only call per top-level controller. Changes
# nothing on the instance.

plan skip_all => 'TEST_FORGEJO_URL and TEST_FORGEJO_TOKEN required'
    unless $ENV{TEST_FORGEJO_URL} && $ENV{TEST_FORGEJO_TOKEN};

my $client = WWW::Forgejo->new(
    url   => $ENV{TEST_FORGEJO_URL},
    token => $ENV{TEST_FORGEJO_TOKEN},
);

subtest 'version' => sub {
    my $v = $client->misc->version;
    ok($v->{version}, 'has a version');
    note explain $v;
};

subtest 'current user' => sub {
    my $me = $client->current_user->get;
    ok($me->{login}, 'the token belongs to a user');
    my $user = $client->users->get($me->{login});
    is($user->{id}, $me->{id}, 'users->get finds the same user');
};

subtest 'user search' => sub {
    my $result = $client->users->search('a');
    is(ref $result->{data}, 'ARRAY', 'search returns the envelope with a data array');
    $result = $client->users->search(q => 'a', limit => 1);
    cmp_ok(scalar @{ $result->{data} }, '<=', 1, 'named parameters reach the query string');
};

subtest 'orgs list' => sub {
    my $orgs = $client->orgs->list;
    is(ref $orgs, 'ARRAY', 'list returns an arrayref');
    for my $org (@$orgs) {
        isa_ok($org, 'WWW::Forgejo::Entity::Org');
        ok($org->name, 'organization has a name');
    }
};

subtest 'repos list_for_org' => sub {
    plan skip_all => 'TEST_FORGEJO_ORG not set'
        unless $ENV{TEST_FORGEJO_ORG};
    my $repos = $client->repos->list_for_org($ENV{TEST_FORGEJO_ORG});
    is(ref $repos, 'ARRAY', 'list_for_org returns an arrayref');
    for my $repo (@$repos) {
        isa_ok($repo, 'WWW::Forgejo::Entity::Repo');
        is($repo->owner, $ENV{TEST_FORGEJO_ORG}, 'bound to the organization');
    }
};

subtest 'notifications' => sub {
    my $notifications = $client->notifications->list;
    is(ref $notifications, 'ARRAY', 'list returns an arrayref');
    my $new = $client->notifications->check;
    ok(defined $new->{new}, 'check returns the number of new notifications');
};

subtest 'admin users list' => sub {
    my $users = $client->admin->users->list;
    is(ref $users, 'ARRAY', 'list returns an arrayref');
    note explain $users;
};

subtest 'admin hooks list' => sub {
    my $hooks = $client->admin->hooks->list;
    is(ref $hooks, 'ARRAY', 'list returns an arrayref');
};

subtest 'admin runners' => sub {
    my $runners = eval { $client->admin->runners->list };
    return plan skip_all => 'Actions runners not available or not enabled: ' . $@ unless defined $runners;
    ok(ref $runners, 'list returns a structure');
};

subtest 'admin cron list' => sub {
    my $tasks = $client->admin->cron->list;
    is(ref $tasks, 'ARRAY', 'list returns an arrayref');
};

subtest 'admin quota' => sub {
    my $me    = $client->current_user->get;
    my $quota = eval { $client->admin->users->quota($me->{login}) };
    return plan skip_all => 'Quota API not available on this instance: ' . $@ unless defined $quota;
    ok(ref $quota, 'quota returns a structure');
    note explain $quota;
};

done_testing;
