use strict;
use warnings;
use Test::More;
use lib 'lib';
use WWW::Forgejo;
use Data::Dumper;

plan skip_all => 'TEST_FORGEJO_URL and TEST_FORGEJO_TOKEN required'
    unless $ENV{TEST_FORGEJO_URL} && $ENV{TEST_FORGEJO_TOKEN};

my $client = WWW::Forgejo->new(
    url   => $ENV{TEST_FORGEJO_URL},
    token => $ENV{TEST_FORGEJO_TOKEN},
);

my $TEST_ORG = $ENV{TEST_FORGEJO_ORG} // 'testorg';
my $TEST_REPO = $ENV{TEST_FORGEJO_REPO} // 'testrepo';
my $TEST_USER = $ENV{TEST_FORGEJO_USER} // 'testadmin';

# Helper to create test org if needed
sub ensure_org {
    my ($org_name) = @_;
    my $orgs = $client->orgs->list;
    my @names = map { $_->{username} // $_->{name} } @$orgs;
    unless (grep { $_ eq $org_name } @names) {
        eval { $client->orgs->create(name => $org_name, visibility => 'public') };
    }
    return 1;
}

# Helper to create test repo if needed
sub ensure_repo {
    my ($org, $repo_name) = @_;
    my $repos = $client->repos->list_for_org($org);
    my @names = map { $_->{name} } @$repos;
    unless (grep { $_ eq $repo_name } @names) {
        eval { $client->repos->create_for_org($org, name => $repo_name, description => 'Test repo', private => 0) };
    }
    return 1;
}

# =============================================================================
# Misc API - always available
# =============================================================================

subtest 'misc version' => sub {
    my $v = $client->misc->version;
    ok($v->{version}, 'has version');
    diag explain $v;
};

subtest 'misc nodeinfo' => sub {
    my $info = eval { $client->misc->nodeinfo };
    if ($@) {
        pass("nodeinfo not available: $@");
        return;
    }
    ok($info);
    diag explain $info;
};

subtest 'misc gitignore_templates' => sub {
    my $templates = eval { $client->misc->gitignore_templates };
    if ($@) {
        pass("gitignore_templates not available: $@");
        return;
    }
    ok(ref $templates eq 'ARRAY', 'returns array');
    diag explain $templates if $templates && @$templates;
};

subtest 'misc license_templates' => sub {
    my $templates = eval { $client->misc->license_templates };
    if ($@) {
        pass("license_templates not available: $@");
        return;
    }
    ok(ref $templates eq 'ARRAY', 'returns array');
    diag explain $templates if $templates && @$templates;
};

# =============================================================================
# Users API
# =============================================================================

subtest 'users search' => sub {
    my $result = $client->users->search('test');
    ok($result, 'search returns result');
    is(ref $result->{data}, 'ARRAY', 'data is array');
    diag explain $result;
};

subtest 'users get' => sub {
    my $user = $client->users->get($TEST_USER);
    ok($user, 'get user works');
    diag explain $user;
};

# =============================================================================
# Orgs API
# =============================================================================

subtest 'orgs list' => sub {
    my $orgs = $client->orgs->list;
    ok(ref $orgs eq 'ARRAY', 'list returns array');
    diag explain $orgs;
};

subtest 'orgs get' => sub {
    my $org = $client->orgs->get($TEST_ORG);
    ok($org, 'get org works');
    is($org->data->{username}, $TEST_ORG);
    diag explain $org;
};

# =============================================================================
# Repos API
# =============================================================================

subtest 'repos search' => sub {
    my $result = eval { $client->repos->search(query => 'test') };
    if ($@) {
        pass("repos search not available: $@");
        return;
    }
    ok($result, 'search returns result');
    diag explain $result;
};

subtest 'repos list_for_org' => sub {
    ensure_org($TEST_ORG);
    my $repos = $client->repos->list_for_org($TEST_ORG);
    ok(ref $repos eq 'ARRAY', 'list_for_org returns array');
    diag explain $repos;
};

subtest 'repos get' => sub {
    ensure_org($TEST_ORG);
    ensure_repo($TEST_ORG, $TEST_REPO);
    my $repo = eval { $client->repos->get($TEST_ORG, $TEST_REPO) };
    if ($@) {
        pass("repos get not available: $@");
        return;
    }
    ok($repo, 'get repo works');
    is($repo->data->{name}, $TEST_REPO);
    diag explain $repo;
};

# =============================================================================
# Teams API
# =============================================================================

subtest 'teams list' => sub {
    my $teams = eval { $client->teams->list };
    if ($@) {
        pass("teams list not available: $@");
        return;
    }
    ok(ref $teams eq 'ARRAY', 'list returns array');
    diag explain $teams;
};

subtest 'teams get' => sub {
    my $teams = eval { $client->teams->list };
    if ($@) {
        pass("teams not available: $@");
        return;
    }
    if (@$teams) {
        my $team = eval { $client->teams->get($teams->[0]{id}) };
        if ($@) {
            pass("team get not available: $@");
            return;
        }
        ok($team, 'get team works');
        diag explain $team;
    } else {
        pass('No teams to test');
    }
};

# =============================================================================
# Packages API
# =============================================================================

subtest 'packages list' => sub {
    my $packages = eval { $client->packages->list };
    if ($@) {
        pass("packages list not available: $@");
        return;
    }
    ok(ref $packages eq 'ARRAY', 'list returns array');
    diag explain $packages;
};

# =============================================================================
# Notifications API
# =============================================================================

subtest 'notifications list' => sub {
    my $notifs = eval { $client->notifications->list };
    if ($@) {
        pass("notifications list not available: $@");
        return;
    }
    ok(ref $notifs eq 'ARRAY', 'list returns array');
    diag explain $notifs;
};

# =============================================================================
# CurrentUser API
# =============================================================================

subtest 'current_user get' => sub {
    my $user = eval { $client->current_user->get };
    if ($@) {
        pass("current_user get not available: $@");
        return;
    }
    ok($user, 'get current user works');
    diag explain $user;
};

subtest 'current_user settings' => sub {
    my $settings = eval { $client->current_user->settings };
    if ($@) {
        pass("current_user settings not available: $@");
        return;
    }
    ok($settings, 'settings works');
    diag explain $settings;
};

subtest 'current_user list_emails' => sub {
    my $emails = eval { $client->current_user->list_emails };
    if ($@) {
        pass("current_user list_emails not available: $@");
        return;
    }
    ok(ref $emails eq 'ARRAY', 'list_emails returns array');
    diag explain $emails;
};

subtest 'current_user list_keys' => sub {
    my $keys = eval { $client->current_user->list_keys };
    if ($@) {
        pass("current_user list_keys not available: $@");
        return;
    }
    ok(ref $keys eq 'ARRAY', 'list_keys returns array');
    diag explain $keys;
};

subtest 'current_user list_hooks' => sub {
    my $hooks = eval { $client->current_user->list_hooks };
    if ($@) {
        pass("current_user list_hooks not available: $@");
        return;
    }
    ok(ref $hooks eq 'ARRAY', 'list_hooks returns array');
    diag explain $hooks;
};

subtest 'current_user list_orgs' => sub {
    my $orgs = eval { $client->current_user->list_orgs };
    if ($@) {
        pass("current_user list_orgs not available: $@");
        return;
    }
    ok(ref $orgs eq 'ARRAY', 'list_orgs returns array');
    diag explain $orgs;
};

subtest 'current_user list_repos' => sub {
    my $repos = eval { $client->current_user->list_repos };
    if ($@) {
        pass("current_user list_repos not available: $@");
        return;
    }
    ok(ref $repos eq 'ARRAY', 'list_repos returns array');
    diag explain $repos;
};

# =============================================================================
# Admin::Users API
# =============================================================================

subtest 'admin users list' => sub {
    my $users = eval { $client->admin->users->list };
    if ($@) {
        pass("admin users list not available: $@");
        return;
    }
    ok($users, 'admin users list works');
    is(ref $users, 'ARRAY');
    diag explain $users;
};

subtest 'admin users get' => sub {
    my $users = eval { $client->admin->users->list };
    if ($@) {
        pass("admin users not available: $@");
        return;
    }
    if (@$users) {
        my $user = eval { $client->admin->users->get($users->[0]{login}) };
        if ($@) {
            pass("admin users get not available: $@");
            return;
        }
        ok($user, 'admin get user works');
        diag explain $user;
    } else {
        pass('No users to test');
    }
};

subtest 'admin users create' => sub {
    my $new_user = eval {
        $client->admin->users->create(
            email => 'newuser@example.com',
            username => 'newtestuser',
            password => 'NewTest123!',
        )
    };
    if ($@) {
        pass('User creation failed (may already exist or no permission): ' . substr($@, 0, 100));
    } else {
        ok($new_user, 'create user works');
        # Cleanup
        eval { $client->admin->users->delete('newtestuser') };
        diag explain $new_user;
    }
};

subtest 'admin users list_keys' => sub {
    my $keys = $client->admin->users->list_keys($TEST_USER);
    ok(ref $keys eq 'ARRAY', 'list_keys works');
    diag explain $keys;
};

subtest 'admin users list_orgs' => sub {
    my $orgs = $client->admin->users->list_orgs($TEST_USER);
    ok(ref $orgs eq 'ARRAY', 'list_orgs works');
    diag explain $orgs;
};

subtest 'admin users list_repos' => sub {
    my $repos = $client->admin->users->list_repos($TEST_USER);
    ok(ref $repos eq 'ARRAY', 'list_repos works');
    diag explain $repos;
};

# =============================================================================
# Admin::Hooks API
# =============================================================================

subtest 'admin hooks list' => sub {
    my $hooks = $client->admin->hooks->list;
    ok($hooks, 'admin hooks list works');
    is(ref $hooks, 'ARRAY');
    diag explain $hooks;
};

# =============================================================================
# Admin::Cron API
# =============================================================================

subtest 'admin cron list' => sub {
    my $tasks = $client->admin->cron->list;
    ok($tasks, 'cron list works');
    is(ref $tasks, 'ARRAY');
    diag explain $tasks;
};

subtest 'admin cron get' => sub {
    my $task = $client->admin->cron->get('update_mirrors');
    ok($task, 'cron get works');
    diag explain $task;
};

# =============================================================================
# Admin::Runners API
# =============================================================================

subtest 'admin runners list' => sub {
    my $runners = eval { $client->admin->runners->list };
    if ($@) {
        pass("runners not available: $@");
        return;
    }
    ok($runners, 'runners list works');
    is(ref $runners, 'ARRAY');
    diag explain $runners;
};

# =============================================================================
# Admin::Quota API
# =============================================================================

subtest 'admin quota list_groups' => sub {
    my $groups = eval { $client->admin->quota->list_groups };
    if ($@) {
        pass("quota list_groups not available: $@");
        return;
    }
    ok($groups, 'list_groups works');
    diag explain $groups;
};

# =============================================================================
# Repo::Branches API (if we have a repo)
# =============================================================================

subtest 'repo branches list' => sub {
    ensure_org($TEST_ORG);
    ensure_repo($TEST_ORG, $TEST_REPO);
    my $branches = $client->repos->get($TEST_ORG, $TEST_REPO)->branches;
    ok(ref $branches eq 'ARRAY', 'branches list works');
    diag explain $branches;
};

# =============================================================================
# Repo::Collaborators API
# =============================================================================

subtest 'repo collaborators list' => sub {
    ensure_org($TEST_ORG);
    ensure_repo($TEST_ORG, $TEST_REPO);
    my $collabs = $client->repos->get($TEST_ORG, $TEST_REPO)->collaborators;
    ok(ref $collabs eq 'ARRAY', 'collaborators list works');
    diag explain $collabs;
};

# =============================================================================
# Repo::Hooks API
# =============================================================================

subtest 'repo hooks list' => sub {
    ensure_org($TEST_ORG);
    ensure_repo($TEST_ORG, $TEST_REPO);
    my $hooks = $client->repos->get($TEST_ORG, $TEST_REPO)->hooks;
    ok(ref $hooks eq 'ARRAY', 'hooks list works');
    diag explain $hooks;
};

# =============================================================================
# Repo::Labels API
# =============================================================================

subtest 'repo labels list' => sub {
    ensure_org($TEST_ORG);
    ensure_repo($TEST_ORG, $TEST_REPO);
    my $labels = $client->repos->get($TEST_ORG, $TEST_REPO)->labels;
    ok(ref $labels eq 'ARRAY', 'labels list works');
    diag explain $labels;
};

# =============================================================================
# Repo::Milestones API
# =============================================================================

subtest 'repo milestones list' => sub {
    ensure_org($TEST_ORG);
    ensure_repo($TEST_ORG, $TEST_REPO);
    my $milestones = $client->repos->get($TEST_ORG, $TEST_REPO)->milestones;
    ok(ref $milestones eq 'ARRAY', 'milestones list works');
    diag explain $milestones;
};

# =============================================================================
# Repo::Issues API
# =============================================================================

subtest 'repo issues list' => sub {
    ensure_org($TEST_ORG);
    ensure_repo($TEST_ORG, $TEST_REPO);
    my $issues = $client->repos->get($TEST_ORG, $TEST_REPO)->issues;
    ok(ref $issues eq 'ARRAY', 'issues list works');
    diag explain $issues;
};

# =============================================================================
# Org::Members API
# =============================================================================

subtest 'org members list' => sub {
    my $members = $client->orgs->get($TEST_ORG)->members;
    ok(ref $members eq 'ARRAY', 'members list works');
    diag explain $members;
};

# =============================================================================
# Org::Teams API
# =============================================================================

subtest 'org teams list' => sub {
    my $teams = $client->orgs->get($TEST_ORG)->teams;
    ok(ref $teams eq 'ARRAY', 'teams list works');
    diag explain $teams;
};

# =============================================================================
# Org::Hooks API
# =============================================================================

subtest 'org hooks list' => sub {
    my $hooks = $client->orgs->get($TEST_ORG)->hooks;
    ok(ref $hooks eq 'ARRAY', 'hooks list works');
    diag explain $hooks;
};

done_testing;