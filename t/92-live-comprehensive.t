#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use WWW::Forgejo;

# Live walk through the controllers and entities. Needs the token of an admin
# user and CHANGES the instance: it creates and deletes a user, an issue, a
# label and a milestone. TEST_FORGEJO_ORG and TEST_FORGEJO_REPO name an
# organization and repository to work in (created when missing, and left
# there); without them a throwaway organization and repository, named with the
# prefix below, are made and deleted at the end.

plan skip_all => 'TEST_FORGEJO_URL and TEST_FORGEJO_TOKEN required'
    unless $ENV{TEST_FORGEJO_URL} && $ENV{TEST_FORGEJO_TOKEN};

my $client = WWW::Forgejo->new(
    url   => $ENV{TEST_FORGEJO_URL},
    token => $ENV{TEST_FORGEJO_TOKEN},
);

my $PREFIX    = 'wfl92-';
my $OWN_ORG   = !defined $ENV{TEST_FORGEJO_ORG};
my $OWN_REPO  = !defined $ENV{TEST_FORGEJO_REPO};
my $TEST_ORG  = $ENV{TEST_FORGEJO_ORG}  // $PREFIX . 'org-' . $$;
my $TEST_REPO = $ENV{TEST_FORGEJO_REPO} // $PREFIX . 'repo-' . $$;

# The user the token belongs to, unless another one is named.
my $me        = $client->current_user->get;
my $TEST_USER = $ENV{TEST_FORGEJO_USER} // $me->{login};

my $all_orgs = $client->orgs->list;
for my $old_org (@$all_orgs) {
    next unless index($old_org->name, $PREFIX) == 0;
    my $org_repos = $client->repos->list_for_org($old_org->name);
    for my $repo_of_org (@$org_repos) { $client->repos->delete($old_org->name, $repo_of_org->repo) }
    $client->orgs->delete($old_org->name);
}

END {
    if ($client) {
        eval { $client->repos->delete($TEST_ORG, $TEST_REPO) } if $OWN_REPO || $OWN_ORG;
        eval { $client->orgs->delete($TEST_ORG) } if $OWN_ORG;
    }
}

# Run a call that needs a feature the instance may have switched off. Only the
# plain-text 404 of a missing route counts as "not there" and skips the
# subtest; any other error fails it.
sub optional {
    my ($what, $code) = @_;
    my $result = eval { $code->() };
    return $result unless $@;
    die $@ unless $@ =~ /^Forgejo API error: 404 page not found/;
    plan skip_all => "$what: no such route on this instance";
    return;
}

# Create the test organization unless it exists.
sub ensure_org {
    my ($org_name) = @_;
    my $orgs = $client->orgs->list;
    for my $org (@$orgs) {
        return $org if $org->name eq $org_name;
    }
    return $client->orgs->create(username => $org_name, visibility => 'public');
}

# Create the test repository (with an initial commit) unless it exists.
sub ensure_repo {
    my ($org_name, $repo_name) = @_;
    ensure_org($org_name);
    my $repos = $client->repos->list_for_org($org_name);
    for my $repo (@$repos) {
        return $repo if $repo->repo eq $repo_name;
    }
    return $client->repos->create_for_org(
        $org_name,
        name        => $repo_name,
        description => 'Test repo',
        private     => \0,
        auto_init   => \1,
    );
}

# =============================================================================
# Misc
# =============================================================================

subtest 'misc version' => sub {
    my $v = $client->misc->version;
    ok($v->{version}, 'has version');
    note explain $v;
};

subtest 'misc nodeinfo' => sub {
    my $info = optional(nodeinfo => sub { $client->misc->nodeinfo }) or return;
    ok($info->{software}, 'nodeinfo names the software');
};

subtest 'misc templates' => sub {
    is(ref $client->misc->gitignore_templates, 'ARRAY', 'gitignore_templates returns an arrayref');
    is(ref $client->misc->license_templates,   'ARRAY', 'license_templates returns an arrayref');
    is(ref $client->misc->label_templates,     'ARRAY', 'label_templates returns an arrayref');
};

subtest 'misc settings' => sub {
    my $api = $client->misc->settings('api');
    ok($api->{max_response_items}, 'api settings carry max_response_items');
};

# =============================================================================
# Users
# =============================================================================

subtest 'users search' => sub {
    my $result = $client->users->search($TEST_USER);
    is(ref $result->{data}, 'ARRAY', 'data is an array');
    ok((grep { $_->{login} eq $TEST_USER } @{ $result->{data} }), 'finds the test user');
};

subtest 'users get' => sub {
    my $user = $client->users->get($TEST_USER);
    is($user->{login}, $TEST_USER, 'get returns the user');
    note explain $user;
};

subtest 'users lists' => sub {
    is(ref $client->users->keys($TEST_USER),      'ARRAY', 'keys returns an arrayref');
    is(ref $client->users->orgs($TEST_USER),      'ARRAY', 'orgs returns an arrayref');
    is(ref $client->users->repos($TEST_USER),     'ARRAY', 'repos returns an arrayref');
    is(ref $client->users->followers($TEST_USER), 'ARRAY', 'followers returns an arrayref');
};

# =============================================================================
# Current user
# =============================================================================

subtest 'current_user' => sub {
    ok($me->{login}, 'get returns the user of the token');
    ok(ref $client->current_user->settings, 'settings returns a structure');
    is(ref $client->current_user->list_emails, 'ARRAY', 'list_emails returns an arrayref');
    is(ref $client->current_user->list_keys,   'ARRAY', 'list_keys returns an arrayref');
    is(ref $client->current_user->list_hooks,  'ARRAY', 'list_hooks returns an arrayref');
    is(ref $client->current_user->orgs,        'ARRAY', 'orgs returns an arrayref');
    is(ref $client->current_user->repos,       'ARRAY', 'repos returns an arrayref');
    is(ref $client->current_user->teams,       'ARRAY', 'teams returns an arrayref');
};

# =============================================================================
# Organizations
# =============================================================================

subtest 'orgs' => sub {
    ensure_org($TEST_ORG);
    my $orgs = $client->orgs->list;
    is(ref $orgs, 'ARRAY', 'list returns an arrayref');
    my $listed = 0;
    for my $listed_org (@$orgs) {
        $listed++ if $listed_org->name eq $TEST_ORG;
    }
    is($listed, 1, "the test organization is listed once");

    my $org = $client->orgs->get($TEST_ORG);
    isa_ok($org, 'WWW::Forgejo::Entity::Org');
    is($org->name, $TEST_ORG, 'get returns the organization');

    is(ref $org->members->list, 'ARRAY', 'members list');
    is(ref $org->teams->list,   'ARRAY', 'teams list');
    is(ref $org->hooks->list,   'ARRAY', 'hooks list');
    is(ref $org->labels->list,  'ARRAY', 'labels list');
    is(ref $org->repos,         'ARRAY', 'repos');
    ok(defined $org->members->check(undef, $TEST_USER), "members check answers yes or no");
};

subtest 'teams' => sub {
    ensure_org($TEST_ORG);
    my $org   = $client->orgs->get($TEST_ORG);
    my $teams = $org->teams->list;
    ok(scalar @$teams, 'an organization has at least its owners team');

    my $team = $client->teams->get($teams->[0]{id});
    isa_ok($team, 'WWW::Forgejo::Entity::Team');
    is($team->id, $teams->[0]{id}, 'get returns the team');
    is(ref $team->list_members, 'ARRAY', 'list_members');
    is(ref $team->list_repos,   'ARRAY', 'list_repos');
};

# =============================================================================
# Repositories
# =============================================================================

subtest 'repos search' => sub {
    ensure_repo($TEST_ORG, $TEST_REPO);
    my $result = $client->repos->search(q => $TEST_REPO);
    is(ref $result->{data}, 'ARRAY', 'data is an array');
};

subtest 'repos get and list_for_org' => sub {
    ensure_repo($TEST_ORG, $TEST_REPO);
    my $repos = $client->repos->list_for_org($TEST_ORG);
    is(ref $repos, 'ARRAY', 'list_for_org returns an arrayref');

    my $repo = $client->repos->get($TEST_ORG, $TEST_REPO);
    isa_ok($repo, 'WWW::Forgejo::Entity::Repo');
    is($repo->data->{name}, $TEST_REPO, 'get returns the repository');
    is($repo->owner, $TEST_ORG, 'bound to its owner');
};

subtest 'repository controllers: lists' => sub {
    ensure_repo($TEST_ORG, $TEST_REPO);
    my $repo = $client->repos->get($TEST_ORG, $TEST_REPO);

    my @branches = $repo->branches->list;
    ok(scalar @branches, 'an initialised repository has a branch');
    for my $branch (@branches) {
        isa_ok($branch, 'WWW::Forgejo::Entity::Branch');
        ok($branch->name, 'branch has a name');
    }

    is(eval { my @list = $repo->collaborators->list; 1 }, 1, 'collaborators list') or diag $@;
    is(eval { my @list = $repo->hooks->list;         1 }, 1, 'hooks list')         or diag $@;
    is(eval { my @list = $repo->labels->list;        1 }, 1, 'labels list')        or diag $@;
    is(eval { my @list = $repo->milestones->list;    1 }, 1, 'milestones list')    or diag $@;
    is(eval { my @list = $repo->issues->list;        1 }, 1, 'issues list')        or diag $@;
    is(eval { my @list = $repo->pulls->list;         1 }, 1, 'pulls list')         or diag $@;
    is(eval { my @list = $repo->releases->list;      1 }, 1, 'releases list')      or diag $@;
    is(eval { my @list = $repo->tags->list;          1 }, 1, 'tags list')          or diag $@;
    is(eval { my @list = $repo->keys->list;          1 }, 1, 'keys list')          or diag $@;
    is(ref $repo->topics->list, 'ARRAY', 'topics list');
};

subtest 'repository controllers: issue, label and milestone round trip' => sub {
    ensure_repo($TEST_ORG, $TEST_REPO);
    my $repo = $client->repos->get($TEST_ORG, $TEST_REPO);

    my $label = $repo->labels->create({ name => 'live-test', color => '#00aabb' });
    ok($label->{id}, 'label created');

    my $milestone = $repo->milestones->create({ title => 'live test milestone' });
    isa_ok($milestone, 'WWW::Forgejo::Entity::Milestone');
    is($milestone->title, 'live test milestone', 'milestone created');

    my $issue = $repo->issues->create({ title => 'live test issue', body => 'created by t/92' });
    isa_ok($issue, 'WWW::Forgejo::Entity::Issue');
    ok($issue->number, 'issue has a number');

    my $edited = $repo->issues->edit($issue->number, { title => 'live test issue (edited)' });
    is($edited->title, 'live test issue (edited)', 'issue edited');

    $repo->issues->add_comment($issue->number, { body => 'a comment' });
    my @comments = $repo->issues->list_comments($issue->number);
    is(scalar @comments, 1, 'one comment');
    for my $comment (@comments) {
        is($comment->body, 'a comment', 'comment body');
    }

    my $fetched = $repo->issues->get($issue->number);
    is($fetched->state, 'open', 'issue is open');

    ok($repo->issues->delete($issue->number),  'issue deleted');
    ok($repo->milestones->delete($milestone->id), 'milestone deleted');
    $repo->labels->delete($label->{id});
    pass('label deleted');
};

# =============================================================================
# Packages and notifications
# =============================================================================

subtest 'packages list' => sub {
    my $packages = optional(packages => sub { $client->packages->list($TEST_USER) }) or return;
    is(ref $packages, 'ARRAY', 'list returns an arrayref');
};

subtest 'notifications list' => sub {
    is(ref $client->notifications->list, 'ARRAY', 'list returns an arrayref');
};

# =============================================================================
# Admin
# =============================================================================

subtest 'admin users' => sub {
    my $users = $client->admin->users->list;
    is(ref $users, 'ARRAY', 'list returns an arrayref');
    ok((grep { $_->{login} eq $me->{login} } @$users), 'the admin is listed');
};

subtest 'admin users create and delete' => sub {
    my $name = $PREFIX . 'u' . $$;
    my $user = $client->admin->users->create(
        email                => $name . '@example.com',
        username             => $name,
        password             => 'NewTest123!' . $$,
        must_change_password => \0,
    );
    is($user->{login}, $name, 'user created');
    is($client->users->get($name)->{login}, $name, 'and can be read');
    $client->admin->users->delete($name);
    ok(!eval { $client->users->get($name); 1 }, 'gone after delete');
    like($@, qr/^Forgejo API error: /, 'reading it croaks with an API error');
};

subtest 'admin hooks list' => sub {
    is(ref $client->admin->hooks->list, 'ARRAY', 'list returns an arrayref');
};

subtest 'admin cron list' => sub {
    my $tasks = $client->admin->cron->list;
    is(ref $tasks, 'ARRAY', 'list returns an arrayref');
    ok($tasks->[0]{name}, 'tasks carry a name');
};

subtest 'admin runners list' => sub {
    my $runners = optional(runners => sub { $client->admin->runners->list }) or return;
    ok(ref $runners, 'list returns a structure');
};

subtest 'admin quota list_groups' => sub {
    my $groups = optional(quota => sub { $client->admin->quota->list_groups }) or return;
    ok(ref $groups, 'list_groups returns a structure');
};

done_testing;
