#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use WWW::Forgejo;

# Live test of the admin controllers. Needs the token of an admin user. Creates
# a throwaway user (renamed on the way), an organization and a repository for
# it, a quota group with a rule and a system hook, all named with the prefix
# below; leftovers of an earlier, aborted run are removed first, and everything
# is deleted at the end.

plan skip_all => 'TEST_FORGEJO_URL and TEST_FORGEJO_TOKEN required'
    unless $ENV{TEST_FORGEJO_URL} && $ENV{TEST_FORGEJO_TOKEN};

my $client = WWW::Forgejo->new(
    url   => $ENV{TEST_FORGEJO_URL},
    token => $ENV{TEST_FORGEJO_TOKEN},
);

my $PREFIX   = 'wfl90-';
my $USER     = $PREFIX . 'u' . $$;
my $RENAMED  = $PREFIX . 'r' . $$;
my $ORG      = $PREFIX . 'org-' . $$;
my $GROUP    = $PREFIX . 'group-' . $$;
my $RULE     = $PREFIX . 'rule-' . $$;
my $RULE2    = $PREFIX . 'rule2-' . $$;
my $HOOK_URL = 'http://127.0.0.1:9/' . $PREFIX . 'hook';
my $USER_KEY = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBpKEyuOdfQ+0EmAuN9VVb9i4ATvdRCyjB2CdW1hlJF0 wfl-live-user';
my $me       = $client->current_user->get;

my $all_orgs = $client->orgs->list;
for my $old_org (@$all_orgs) {
    next unless index($old_org->name, $PREFIX) == 0;
    my $org_repos = $client->repos->list_for_org($old_org->name);
    for my $repo_of_org (@$org_repos) { $client->repos->delete($old_org->name, $repo_of_org->repo) }
    $client->orgs->delete($old_org->name);
}
for my $old_user (@{ $client->admin->users->list }) {
    $client->admin->users->delete($old_user->{login}, purge => 'true') if index($old_user->{login}, $PREFIX) == 0;
}
for my $old_group (@{ $client->admin->quota->list_groups }) {
    $client->admin->quota->delete_group($old_group->name) if index($old_group->name, $PREFIX) == 0;
}
for my $old_rule (@{ $client->admin->quota->list_rules }) {
    $client->admin->quota->delete_rule($old_rule->name) if index($old_rule->name, $PREFIX) == 0;
}

END {
    if ($client) {
        eval { $client->repos->delete($ORG, 'admin-made') };
        eval { $client->orgs->delete($ORG) };
        for my $login ($USER, $RENAMED) { eval { $client->admin->users->delete($login, purge => 'true') } }
        eval { $client->admin->quota->delete_group($GROUP) };
        eval { $client->admin->quota->delete_rule($RULE) };
        eval { $client->admin->quota->delete_rule($RULE2) };
    }
}

# =============================================================================
# Users
# =============================================================================

subtest 'users list' => sub {
    my $users = $client->admin->users->list;
    is(ref $users, 'ARRAY', 'list returns an arrayref');
    ok((grep { $_->{login} eq $me->{login} } @$users), 'the admin is listed');
    my $first = $client->admin->users->list(limit => 1, page => 1);
    is(scalar @$first, 1, 'an explicit page');
};

subtest 'users create, edit, rename' => sub {
    my $user = $client->admin->users->create(
        username             => $USER,
        email                => $USER . '@example.com',
        password             => 'Live-Test-' . $$ . '!',
        must_change_password => \0,
        full_name            => 'Live User',
    );
    is($user->{login}, $USER, 'created');
    is($user->{full_name}, 'Live User', 'full_name');
    is($client->users->get($USER)->{login}, $USER, 'readable through users');

    my $edited = $client->admin->users->edit($USER,
        login_name => $USER,
        source_id  => 0,
        full_name  => "Gr\x{fc}\x{df}e",
        location   => 'Live',
    );
    is($edited->{full_name}, "Gr\x{fc}\x{df}e", 'edit, with non-ASCII text');
    is($edited->{location}, 'Live', 'edit');

    is($client->admin->users->rename($USER, $RENAMED), undef, 'rename');
    is($client->users->get($RENAMED)->{login}, $RENAMED, 'renamed');
    is($client->users->get($USER)->{login}, $RENAMED, 'the old name redirects to the new one');
};

subtest 'emails' => sub {
    my $emails = $client->admin->users->list_emails($RENAMED);
    is($emails->[0]{email}, $USER . '@example.com', 'list_emails');
    ok($emails->[0]{primary}, 'the primary address');

    # A second address is added as the user would: no admin endpoint for it.
    my $found = $client->admin->users->search_emails(q => $USER);
    is($found->[0]{email}, $USER . '@example.com', 'search_emails');
    is($found->[0]{username}, $RENAMED, 'names the user');

    eval { $client->admin->users->delete_email($RENAMED, $USER . '@example.com') };
    like($@, qr/^Forgejo API error: \S/, 'the primary address cannot be deleted: ' . ($@ =~ /^(.*?) at /)[0]);
};

subtest 'keys' => sub {
    my $key = $client->admin->users->add_key($RENAMED, title => $PREFIX . 'key', key => $USER_KEY);
    ok($key->{id}, 'add_key');
    is($client->users->keys($RENAMED)->[0]{id}, $key->{id}, 'listed for the user');
    $client->admin->users->delete_key($RENAMED, $key->{id});
    is(scalar @{ $client->users->keys($RENAMED) }, 0, 'delete_key');
};

subtest 'organization and repository for a user' => sub {
    my $org = $client->admin->users->create_org_for($RENAMED, username => $ORG, visibility => 'public');
    is($org->{username}, $ORG, 'create_org_for');
    my %orgs = map { ($_->{username} => 1) } @{ $client->users->orgs($RENAMED) };
    ok($orgs{$ORG}, 'the user is a member');

    my $repo = $client->admin->users->create_repo_for($ORG, name => 'admin-made', auto_init => \1);
    is($repo->{full_name}, "$ORG/admin-made", 'create_repo_for, owned by the organization');
    $client->repos->delete($ORG, 'admin-made');
    $client->orgs->delete($ORG);
};

# =============================================================================
# Quota
# =============================================================================

subtest 'quota groups and rules' => sub {
    my $group = $client->admin->quota->create_group(
        name  => $GROUP,
        rules => [ { name => $RULE, limit => 1024 * 1024, subjects => ['size:repos:all'] } ],
    );
    isa_ok($group, 'WWW::Forgejo::Entity::QuotaGroup');
    is($group->name, $GROUP, 'create_group, with a rule');
    is(scalar @{ $group->rules }, 1, 'the group holds one rule');

    my $fetched = $client->admin->quota->get_group($GROUP);
    is($fetched->name, $GROUP, 'get_group');
    is(scalar @{ $fetched->rules }, 1, 'and its rule');

    my $groups = $client->admin->quota->list_groups;
    my %groups;
    for my $one (@$groups) { $groups{ $one->name } = 1 }
    ok($groups{$GROUP}, 'list_groups');

    # The rules have their own controller.
    my $rules = $client->admin->quota->list_rules;
    my %rules;
    for my $one (@$rules) { $rules{ $one->name } = 1 }
    ok($rules{$RULE}, 'list_rules');
    is($client->admin->quota->get_rule($RULE)->limit, 1024 * 1024, 'get_rule');
    is($client->admin->quota->edit_rule($RULE, limit => 2048)->limit, 2048, 'edit_rule');

    # A second rule, added to the group afterwards.
    my $rule2 = $client->admin->quota->create_rule(
        name     => $RULE2,
        limit    => 4096,
        subjects => ['size:repos:all'],
    );
    isa_ok($rule2, 'WWW::Forgejo::Entity::QuotaRule');
    is($rule2->name, $RULE2, 'create_rule');
    ok($client->admin->quota->add_rule_to_group($GROUP, $RULE2), 'add_rule_to_group');
    is(scalar @{ $client->admin->quota->get_group($GROUP)->rules }, 2, 'the group holds both rules');
    $client->admin->quota->remove_rule_from_group($GROUP, $RULE2);
    is(scalar @{ $client->admin->quota->get_group($GROUP)->rules }, 1, 'and only one again');

    # The users of a group.
    ok($client->admin->quota->add_user_to_group($GROUP, $RENAMED), 'add_user_to_group');
    my @users = @{ $client->admin->quota->list_group_users($GROUP) };
    ok((grep { $_->{login} eq $RENAMED } @users), 'list_group_users');
    $client->admin->quota->remove_user_from_group($GROUP, $RENAMED);
    my @after = @{ $client->admin->quota->list_group_users($GROUP) };
    ok(!(grep { $_->{login} eq $RENAMED } @after), 'remove_user_from_group');

    is($client->admin->users->set_quota_groups($RENAMED, $GROUP), undef, 'set_quota_groups');
    my $quota = $client->admin->users->quota($RENAMED);
    is($quota->{groups}[0]{name}, $GROUP, 'users->quota names the group');
    ok(exists $quota->{used}, 'and what is used');

    $client->admin->users->set_quota_groups($RENAMED);
    is(scalar @{ $client->admin->users->quota($RENAMED)->{groups} || [] }, 0, 'set_quota_groups with none');

    $client->admin->quota->delete_group($GROUP);
    ok(!eval { $client->admin->quota->get_group($GROUP); 1 }, 'delete_group');
    my $left = $client->admin->quota->list_rules;
    my %left;
    for my $one (@$left) { $left{ $one->name } = 1 }
    ok($left{$RULE}, 'the rule outlives its group');
    $client->admin->quota->delete_rule($RULE);
    $client->admin->quota->delete_rule($RULE2);
};

# =============================================================================
# Hooks, cron, runners
# =============================================================================

subtest 'system hooks' => sub {
    my $hook = $client->admin->hooks->create(
        type   => 'forgejo',
        config => { url => $HOOK_URL, content_type => 'json' },
        events => ['push'],
        active => \0,
    );
    ok($hook->{id}, 'create');
    is($client->admin->hooks->get($hook->{id})->{config}{url}, $HOOK_URL, 'get');
    ok($client->admin->hooks->edit($hook->{id}, active => \1)->{active}, 'edit');
    # Forgejo 15 lists only system webhooks here; a hook made through the API
    # is not one of them and stays unlisted.
    my %hooks = map { ($_->{id} => 1) } @{ $client->admin->hooks->list };
    ok(!$hooks{ $hook->{id} }, 'list: the system webhooks, without the new hook');
    $client->admin->hooks->delete($hook->{id});
    ok(!eval { $client->admin->hooks->get($hook->{id}); 1 }, 'delete');
};

subtest 'cron' => sub {
    my $tasks = $client->admin->cron->list;
    ok(scalar @$tasks, 'the instance has cron tasks');
    my %tasks = map { ($_->{name} => $_) } @$tasks;
    ok($tasks{update_mirrors}, 'update_mirrors among them');
    ok($tasks{update_mirrors}{schedule}, 'with a schedule');
    is($client->admin->cron->run('update_mirrors'), undef, 'run');
    eval { $client->admin->cron->run('no_such_task') };
    like($@, qr/^Forgejo API error: /, 'an unknown task croaks');
};

subtest 'runners' => sub {
    my $token = $client->admin->runners->registration_token;
    ok($token->{token}, 'registration_token');
    my $runners = $client->admin->runners->list;
    is(ref $runners, 'ARRAY', 'list: no runner registered');
    eval { $client->admin->runners->get(999999) };
    like($@, qr/^Forgejo API error: /, 'get of a runner that does not exist croaks');
};

subtest 'delete the user' => sub {
    $client->admin->users->delete($RENAMED, purge => 'true');
    ok(!eval { $client->users->get($RENAMED); 1 }, 'gone after delete');
    like($@, qr/^Forgejo API error: /, 'reading it croaks with an API error');
};

done_testing;
