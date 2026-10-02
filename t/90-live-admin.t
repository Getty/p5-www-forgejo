#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use WWW::Forgejo;

# Live test of the admin controllers. Needs the token of an admin user.

plan skip_all => 'TEST_FORGEJO_URL and TEST_FORGEJO_TOKEN required'
    unless $ENV{TEST_FORGEJO_URL} && $ENV{TEST_FORGEJO_TOKEN};

my $client = WWW::Forgejo->new(
    url   => $ENV{TEST_FORGEJO_URL},
    token => $ENV{TEST_FORGEJO_TOKEN},
);

subtest 'admin users list' => sub {
    my $users = $client->admin->users->list;
    is(ref $users, 'ARRAY', 'list returns an arrayref');
    ok(scalar @$users, 'at least the admin user itself');
    ok($users->[0]{login}, 'users carry a login');
    note explain $users;
};

subtest 'a user from the admin list can be read through users' => sub {
    my $users = $client->admin->users->list(limit => 1);
    return plan skip_all => 'no users' unless @$users;
    my $user = $client->users->get($users->[0]{login});
    is($user->{login}, $users->[0]{login}, 'same user');
};

subtest 'admin hooks list' => sub {
    my $hooks = $client->admin->hooks->list;
    is(ref $hooks, 'ARRAY', 'list returns an arrayref');
    note explain $hooks;
};

subtest 'admin runners list' => sub {
    my $runners = eval { $client->admin->runners->list };
    return plan skip_all => 'Actions runners not available or not enabled: ' . $@ unless defined $runners;
    ok(ref $runners, 'list returns a structure');
    note explain $runners;
};

subtest 'admin cron list' => sub {
    my $tasks = $client->admin->cron->list;
    is(ref $tasks, 'ARRAY', 'list returns an arrayref');
    ok(scalar @$tasks, 'the instance has cron tasks');
    ok($tasks->[0]{name}, 'tasks carry a name');
    note explain $tasks;
};

done_testing;
