#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use WWW::Forgejo;

# Live test of the organization controllers on a throwaway organization:
# teams, members, labels, hooks, Actions variables and secrets, quota, blocked
# users, rename. Needs the token of an admin user (a second, throwaway user is
# created as team member). Everything is named with the prefix below; leftovers
# of an earlier, aborted run are removed first, and everything is deleted at
# the end.
#
# The controllers of a bound organization (C<< $org->teams >> and friends)
# still take the organization name as their first argument (karr #19); the
# TODO tests below record how the natural call behaves today.

plan skip_all => 'TEST_FORGEJO_URL and TEST_FORGEJO_TOKEN required'
    unless $ENV{TEST_FORGEJO_URL} && $ENV{TEST_FORGEJO_TOKEN};

my $client = WWW::Forgejo->new(
    url   => $ENV{TEST_FORGEJO_URL},
    token => $ENV{TEST_FORGEJO_TOKEN},
);

my $PREFIX  = 'wfl94-';
my $ORG     = $PREFIX . 'org-' . $$;
my $RENAMED = $PREFIX . 'renamed-' . $$;
my $USER    = $PREFIX . 'u' . $$;
my $REPO    = 'team-repo';
my $me      = $client->current_user->get;
my $OWNER   = $me->{login};

sub remove_org {
    my ($name) = @_;
    my $org_repos = $client->repos->list_for_org($name);
    for my $repo_of_org (@$org_repos) {
        $client->repos->delete($name, $repo_of_org->repo);
    }
    $client->orgs->delete($name);
}

my $all_orgs = $client->orgs->list;
for my $old_org (@$all_orgs) {
    remove_org($old_org->name) if index($old_org->name, $PREFIX) == 0;
}
for my $old_user (@{ $client->admin->users->list }) {
    $client->admin->users->delete($old_user->{login}, purge => 'true') if index($old_user->{login}, $PREFIX) == 0;
}

END {
    if ($client) {
        for my $name ($ORG, $RENAMED) { eval { remove_org($name) } }
        eval { $client->admin->users->delete($USER, purge => 'true') };
    }
}

my $created = $client->orgs->create(username => $ORG, visibility => 'public', full_name => 'Live Org');
my $user    = $client->admin->users->create(
    username             => $USER,
    email                => $USER . '@example.com',
    password             => 'Live-Test-' . $$ . '!',
    must_change_password => \0,
);
my $org = $client->orgs->get($ORG);

subtest 'organization' => sub {
    isa_ok($created, 'WWW::Forgejo::Entity::Org');
    is($org->name, $ORG, 'get');
    is($org->data->{full_name}, 'Live Org', 'full_name');
    is($org->data->{visibility}, 'public', 'visibility');

    my %listed = map { ($_->{username} => 1) } @{ $client->users->orgs($OWNER) };
    ok($listed{$ORG}, 'listed among the orgs of the owner');

    my $edited = $client->orgs->edit($ORG, description => 'edited by t/94');
    isa_ok($edited, 'WWW::Forgejo::Entity::Org');
    is($edited->data->{description}, 'edited by t/94', 'edit');

    is($org->update(website => 'https://example.com'), $org, 'update through the entity returns it');
    is($org->data->{website}, 'https://example.com', 'which refreshes its data');
};

subtest 'organization repositories' => sub {
    my $repo = $client->repos->create_for_org($ORG, name => $REPO, auto_init => \1);
    isa_ok($repo, 'WWW::Forgejo::Entity::Repo');
    is($repo->owner, $ORG, 'owned by the organization');
    is(scalar @{ $org->repos }, 1, 'org->repos lists it');
    my $listed_repos = $client->repos->list_for_org($ORG);
    for my $listed (@$listed_repos) {
        is($listed->repo, $REPO, 'list_for_org: by name');
        is($listed->owner, $ORG, 'bound to the organization');
    }
};

# =============================================================================
# Teams and members
# =============================================================================

my $team_data;

subtest 'teams' => sub {
    my $teams = $org->teams->list(undef);
    is(scalar @$teams, 1, 'a new organization has its owners team');
    is($teams->[0]{name}, 'Owners', 'named Owners');

    $team_data = $org->teams->create(undef,
        name                      => 'live-team',
        description               => 'from t/94',
        permission                => 'write',
        units                     => [qw(repo.code repo.issues repo.pulls)],
        includes_all_repositories => \0,
    );
    ok($team_data->{id}, 'created');
    is($team_data->{permission}, 'write', 'permission');

    my $found = $org->teams->search(undef, q => 'live');
    ok($found->{ok}, 'search answers ok');
    is($found->{data}[0]{name}, 'live-team', 'search finds the team');

    my $team = $client->teams->get($team_data->{id});
    isa_ok($team, 'WWW::Forgejo::Entity::Team');
    is($team->name, 'live-team', 'get');

    my $edited = $client->teams->edit($team->id, name => 'live-team', description => 'edited');
    is($edited->data->{description}, 'edited', 'edit');
    $team->update(name => 'live-team', description => 'updated');
    is($team->data->{description}, 'updated', 'update through the entity');

    $team->add_member($USER);
    my %members = map { ($_->{login} => 1) } @{ $team->list_members };
    ok($members{$USER}, 'add_member');

    $team->add_repo($ORG, $REPO);
    is($team->list_repos->[0]{name}, $REPO, 'add_repo');
    $team->remove_repo($ORG, $REPO);
    is(scalar @{ $team->list_repos }, 0, 'remove_repo');

    my %teams_of_me = map { ($_->{id} => 1) } @{ $client->current_user->teams };
    ok($teams_of_me{ $teams->[0]{id} }, 'the owners team is among the teams of the token user');

    {
        # Today: GET /orgs/limit/teams, an odd-number warning, and a 404.
        local $TODO = 'karr #19: a bound organization controller still reads the first argument as the org name';
        local $SIG{__WARN__} = sub { };
        ok(eval { $org->teams->list(limit => 1); 1 }, 'org->teams->list(limit => 1)') or diag $@;
    }
};

subtest 'members' => sub {
    is($org->members->check(undef, $USER),  1, 'the team member is a member');
    is($org->members->check(undef, $OWNER), 1, 'so is the owner');
    my %members = map { ($_->{login} => 1) } @{ $org->members->list(undef) };
    ok($members{$USER} && $members{$OWNER}, 'both listed');

    is($org->members->check_public(undef, $OWNER), 0, 'membership is not public');
    $org->members->publicize(undef, $OWNER);
    is($org->members->check_public(undef, $OWNER), 1, 'publicize');
    my %public = map { ($_->{login} => 1) } @{ $org->members->list_public(undef) };
    ok($public{$OWNER}, 'list_public');
    $org->members->conceal(undef, $OWNER);
    is($org->members->check_public(undef, $OWNER), 0, 'conceal');

    $org->members->remove(undef, $USER);
    is($org->members->check(undef, $USER), 0, 'remove');

    {
        local $TODO = 'karr #19: a bound organization controller still reads the first argument as the org name';
        is(eval { $org->members->check($USER) }, 0, 'org->members->check($user)');
    }
};

subtest 'blocked users' => sub {
    $org->blocked_users->block(undef, $USER);
    my $blocked = $org->blocked_users->list(undef);
    is(scalar @$blocked, 1, 'block');
    ok($blocked->[0]{block_id}, 'listed with the id of the blocked user');
    $org->blocked_users->unblock(undef, $USER);
    is(scalar @{ $org->blocked_users->list(undef) }, 0, 'unblock');
};

subtest 'delete a team' => sub {
    my $team = $client->teams->get($team_data->{id});
    $team->delete;
    ok(!eval { $client->teams->get($team_data->{id}); 1 }, 'deleted');
    like($@, qr/^Forgejo API error: /, 'reading it croaks');
};

# =============================================================================
# Labels and hooks
# =============================================================================

subtest 'labels' => sub {
    my $label = $org->labels->create(undef, name => 'org-label', color => '#00aabb', description => 'from t/94');
    ok($label->{id}, 'created');
    is($label->{color}, '00aabb', 'the color comes back without #');
    is($org->labels->get(undef, $label->{id})->{name}, 'org-label', 'get');
    my $edited = $org->labels->edit(undef, $label->{id}, name => 'org-label-2');
    is($edited->{name}, 'org-label-2', 'edit');
    is(scalar @{ $org->labels->list(undef) }, 1, 'list');
    $org->labels->delete(undef, $label->{id});
    is(scalar @{ $org->labels->list(undef) }, 0, 'delete');
};

subtest 'hooks' => sub {
    my $hook = $org->hooks->create(undef,
        type   => 'forgejo',
        config => { url => 'http://127.0.0.1:9/hook', content_type => 'json' },
        events => ['push'],
        active => \0,
    );
    ok($hook->{id}, 'created');
    is($hook->{type}, 'forgejo', 'type');
    is($org->hooks->get(undef, $hook->{id})->{config}{url}, 'http://127.0.0.1:9/hook', 'get');
    my $edited = $org->hooks->edit(undef, $hook->{id}, events => [qw(push issues)]);
    # Forgejo answers with the single events "issues" stands for.
    my %events = map { ($_ => 1) } @{ $edited->{events} };
    ok($events{push}, 'edit keeps push');
    ok((grep { /^issue/ } keys %events), 'and adds the issue events') or diag explain $edited->{events};
    is(scalar @{ $org->hooks->list(undef) }, 1, 'list');
    $org->hooks->delete(undef, $hook->{id});
    is(scalar @{ $org->hooks->list(undef) }, 0, 'delete');
};

# =============================================================================
# Actions, quota
# =============================================================================

subtest 'actions variables' => sub {
    $org->actions->create_variable(undef, 'LIVE_VAR', { value => 'one' });
    my $var = $org->actions->get_variable(undef, 'LIVE_VAR');
    is($var->{name}, 'LIVE_VAR', 'created');
    is($var->{data}, 'one', 'value comes back as data');
    $org->actions->set_variable(undef, 'LIVE_VAR', { value => 'two' });
    is($org->actions->get_variable(undef, 'LIVE_VAR')->{data}, 'two', 'set_variable');
    my $vars = $org->actions->list_variables(undef);
    is(scalar @$vars, 1, 'list_variables');
    $org->actions->delete_variable(undef, 'LIVE_VAR');
    is(scalar @{ $org->actions->list_variables(undef) }, 0, 'delete_variable');
};

subtest 'actions secrets' => sub {
    $org->actions->set_secret(undef, 'LIVE_SECRET', { data => 's3cret' });
    my $secrets = $org->actions->list_secrets(undef);
    is(scalar @$secrets, 1, 'set_secret');
    is($secrets->[0]{name}, 'LIVE_SECRET', 'listed by name');
    ok(!exists $secrets->[0]{data}, 'without the value');
    $org->actions->delete_secret(undef, 'LIVE_SECRET');
    is(scalar @{ $org->actions->list_secrets(undef) }, 0, 'delete_secret');
};

subtest 'actions runners' => sub {
    my $token = $org->actions->runner_registration_token(undef);
    ok($token->{token}, 'registration token');
    my $runners = $org->actions->list_runners(undef);
    is(ref $runners, 'ARRAY', 'no runners registered');
};

subtest 'quota' => sub {
    my $quota = $org->quota->get(undef);
    ok(exists $quota->{used}, 'quota reports what is used');
    ok(exists $quota->{groups}, 'and the quota groups');
};

# =============================================================================
# Rename, delete
# =============================================================================

subtest 'rename and delete' => sub {
    $client->orgs->rename($ORG, new_name => $RENAMED);
    is($client->orgs->get($RENAMED)->name, $RENAMED, 'renamed');

    remove_org($RENAMED);
    ok(!eval { $client->orgs->get($RENAMED); 1 }, 'deleted');
};

done_testing;
