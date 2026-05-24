use strict;
use warnings;
use Test::More;
use lib 'lib';
use WWW::Forgejo;

plan skip_all => 'TEST_FORGEJO_URL and TEST_FORGEJO_TOKEN required'
    unless $ENV{TEST_FORGEJO_URL} && $ENV{TEST_FORGEJO_TOKEN};

my $client = WWW::Forgejo->new(
    url   => $ENV{TEST_FORGEJO_URL},
    token => $ENV{TEST_FORGEJO_TOKEN},
);

subtest 'admin users list' => sub {
    my $users = $client->admin->users->list;
    ok($users);
    diag explain $users;
};

subtest 'admin users get' => sub {
    my $users = $client->admin->users->list;
    return pass('No users to test') unless @$users;
    my $user = $client->admin->users->get($users->[0]{login});
    ok($user);
    diag explain $user;
};

subtest 'admin hooks list' => sub {
    my $hooks = $client->admin->hooks->list;
    ok($hooks);
    diag explain $hooks;
};

subtest 'admin runners list' => sub {
    plan skip_all => 'Actions runners not available or not enabled'
        unless eval { $client->admin->runners->list; 1 };
    my $runners = $client->admin->runners->list;
    ok($runners);
    diag explain $runners;
};

subtest 'admin cron list' => sub {
    my $tasks = $client->admin->cron->list;
    ok($tasks);
    diag explain $tasks;
};

done_testing;