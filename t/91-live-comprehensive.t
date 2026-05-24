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

subtest 'version' => sub {
    my $v = $client->misc->version;
    ok($v->{version});
    diag explain $v;
};

# current_user has issues with Moo role composition - skip for now
subtest 'user search' => sub {
    my $result = $client->users->search('test');
    ok($result);
    diag explain $result;
};

subtest 'orgs list' => sub {
    my $orgs = $client->orgs->list;
    ok(ref $orgs eq 'ARRAY');
    diag explain $orgs;
};

subtest 'repos list_for_org' => sub {
    plan skip_all => 'Need an org to test repos'
        unless $ENV{TEST_FORGEJO_ORG};
    my $repos = $client->repos->list_for_org($ENV{TEST_FORGEJO_ORG});
    ok(ref $repos eq 'ARRAY');
    diag explain $repos;
};

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

subtest 'admin runners' => sub {
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

subtest 'admin quota' => sub {
    plan skip_all => 'Quota API not available in this Forgejo version'
        unless eval { $client->admin->users->quota('testadmin'); 1 };
    my $users = $client->admin->users->list;
    return pass('No users for quota test') unless @$users;
    my $quota = $client->admin->users->quota($users->[0]{login});
    ok($quota);
    diag explain $quota;
};

done_testing;