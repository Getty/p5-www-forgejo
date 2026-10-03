#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use MIME::Base64 qw(encode_base64);
use lib 'lib';
use WWW::Forgejo;

# Live test of the collaboration side of a repository: issues, labels,
# milestones, a pull request from a branch through review and merge,
# collaborators and reviewers, hooks, deploy keys, topics, forks, stars,
# watching, flags and Actions. Needs the token of an admin user. Works on a
# throwaway repository of the token user, a throwaway user and a throwaway
# organization (for the fork), named with the prefix below; leftovers of an
# earlier, aborted run are removed first, and everything is deleted at the end.

plan skip_all => 'TEST_FORGEJO_URL and TEST_FORGEJO_TOKEN required'
    unless $ENV{TEST_FORGEJO_URL} && $ENV{TEST_FORGEJO_TOKEN};

my $client = WWW::Forgejo->new(
    url   => $ENV{TEST_FORGEJO_URL},
    token => $ENV{TEST_FORGEJO_TOKEN},
);

my $PREFIX = 'wfl95-';
my $NAME   = $PREFIX . $$;
my $USER   = $PREFIX . 'u' . $$;
my $ORG    = $PREFIX . 'org-' . $$;
my $me     = $client->current_user->get;
my $OWNER  = $me->{login};
my ($MAJOR) = $client->misc->version->{version} =~ /^(\d+)/;

my $DEPLOY_KEY = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDPOg733H1RPa/IOT7kD4ZbQ4OtbOx03VBnm2f+2q6sH wfl-live-test';

sub remove_org {
    my ($name) = @_;
    my $org_repos = $client->repos->list_for_org($name);
    for my $repo_of_org (@$org_repos) {
        $client->repos->delete($name, $repo_of_org->repo);
    }
    $client->orgs->delete($name);
}

for my $old (@{ $client->current_user->repos }) {
    $client->repos->delete($OWNER, $old->{name}) if index($old->{name}, $PREFIX) == 0;
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
        eval { $client->repos->delete($OWNER, $NAME) };
        eval { $client->repos->delete($OWNER, $NAME . '-gen') };
        eval { remove_org($ORG) };
        eval { $client->admin->users->delete($USER, purge => 'true') };
    }
}

$client->repos->create(name => $NAME, auto_init => \1, default_branch => 'main', description => 'from t/95');
$client->admin->users->create(
    username             => $USER,
    email                => $USER . '@example.com',
    password             => 'Live-Test-' . $$ . '!',
    must_change_password => \0,
);
$client->orgs->create(username => $ORG, visibility => 'public');

my $repo = $client->repos->get($OWNER, $NAME);

subtest 'repository' => sub {
    is($repo->data->{description}, 'from t/95', 'get');
    my $updated = $repo->update({ description => 'updated by t/95', has_wiki => \0 });
    isa_ok($updated, 'WWW::Forgejo::Entity::Repo');
    is($updated->data->{description}, 'updated by t/95', 'update');
    ok(!$updated->data->{has_wiki}, 'units switched off');

    my $found = $client->repos->search(q => $NAME);
    ok($found->{ok}, 'search answers ok');
    is($found->{data}[0]{name}, $NAME, 'search finds it');

    is(ref $client->repos->push_mirrors($OWNER, $NAME), 'ARRAY', 'push_mirrors');
};

# =============================================================================
# Labels, milestones, issues
# =============================================================================

my ($bug, $feature, $milestone_id, $issue_number);

subtest 'labels' => sub {
    $bug = $repo->labels->create({ name => 'bug', color => '#ee0701', description => 'something broke' });
    ok($bug->{id}, 'created');
    is($bug->{color}, 'ee0701', 'color');
    $feature = $repo->labels->create({ name => 'feature', color => '00aa00' });
    is($repo->labels->get($bug->{id})->{name}, 'bug', 'get');
    is($repo->labels->update($bug->{id}, { description => 'edited' })->{description}, 'edited', 'update');
    is(scalar(my @labels = $repo->labels->list), 2, 'list');
};

subtest 'milestones' => sub {
    my $milestone = $repo->milestones->create({
        title       => 'v1',
        description => 'first milestone',
        due_on      => '2030-01-01T00:00:00Z',
    });
    isa_ok($milestone, 'WWW::Forgejo::Entity::Milestone');
    ok($milestone_id = $milestone->id, 'created');
    is($milestone->title, 'v1', 'title');
    is($milestone->description, 'first milestone', 'description');
    is($milestone->state, 'open', 'state');
    like($milestone->due_on, qr/^2030-01-01/, 'due_on');
    ok($milestone->created_at, 'created_at');
    ok($milestone->updated_at, 'updated_at');
    ok(!$milestone->closed_at, 'not closed');

    is($repo->milestones->get($milestone_id)->title, 'v1', 'get');
    my $closed = $repo->milestones->edit($milestone_id, { state => 'closed' });
    is($closed->state, 'closed', 'edit');
    ok($closed->closed_at, 'closed_at');
    $repo->milestones->update($milestone_id, { state => 'open' });
    is(scalar(my @open = $repo->milestones->list), 1, 'list');
};

subtest 'issues' => sub {
    my $issue = $repo->issues->create({
        title     => "Gr\x{fc}\x{df}e \x{2713}",
        body      => 'created by t/95',
        labels    => [ $bug->{id} ],
        milestone => $milestone_id,
        assignees => [$OWNER],
    });
    isa_ok($issue, 'WWW::Forgejo::Entity::Issue');
    ok($issue_number = $issue->number, 'created');
    ok($issue->id, 'id');
    is($issue->title, "Gr\x{fc}\x{df}e \x{2713}", 'non-ASCII title round trips');
    is($issue->body, 'created by t/95', 'body');
    is($issue->state, 'open', 'state');
    is($issue->labels->[0]{name}, 'bug', 'labels');

    my @in_milestone = $repo->milestones->issues($milestone_id);
    is(scalar @in_milestone, 1, 'milestones->issues');
    for my $listed (@in_milestone) { is($listed->number, $issue_number, 'the issue') }

    $repo->issues->add_label($issue_number, { labels => [ $feature->{id} ] });
    my %labels = map { ($_->{name} => 1) } $repo->issues->list_labels($issue_number);
    ok($labels{bug} && $labels{feature}, 'add_label, list_labels');
    ok($repo->issues->remove_label($issue_number, $bug->{id}), 'remove_label');
    is(scalar(my @left = $repo->issues->labels($issue_number)), 1, 'one label left');

    my $comment = $repo->issues->add_comment($issue_number, { body => "first \x{2713}" });
    ok($comment->{id}, 'add_comment');
    my @comments = $repo->issues->list_comments($issue_number);
    is(scalar @comments, 1, 'list_comments');
    for my $listed_comment (@comments) {
        isa_ok($listed_comment, 'WWW::Forgejo::Entity::IssueComment');
        is($listed_comment->id, $comment->{id}, 'comment id');
        is($listed_comment->body, "first \x{2713}", 'comment body');
        is($listed_comment->user->{login}, $OWNER, 'comment user');
        ok($listed_comment->created_at, 'created_at');
        ok($listed_comment->updated_at, 'updated_at');
    }

    my $closed = $repo->issues->edit($issue_number, { state => 'closed' });
    is($closed->state, 'closed', 'edit');
    is(scalar(my @open = $repo->issues->list(state => 'open', type => 'issues')), 0, 'list with a filter');
    is(scalar(my @all = $repo->issues->list(state => 'closed', type => 'issues')), 1, 'the closed one');
    is($repo->issues->get($issue_number)->state, 'closed', 'get');
};

# =============================================================================
# Collaborators, a pull request from a branch, review, merge
# =============================================================================

subtest 'collaborators' => sub {
    is($repo->collaborators->check($USER), 0, 'not a collaborator yet');
    ok($repo->collaborators->add($USER, { permission => 'write' }), 'add');
    is($repo->collaborators->check($USER), 1, 'check');
    is($repo->collaborators->permission($USER)->{permission}, 'write', 'permission');
    my @collaborators = $repo->collaborators->list;
    is(scalar @collaborators, 1, 'list');
    for my $collaborator (@collaborators) {
        is($collaborator->login, $USER, 'login');
        ok($collaborator->id, 'id');
    }
    my %assignees = map { ($_->{login} => 1) } $repo->assignees->list;
    ok($assignees{$USER} && $assignees{$OWNER}, 'assignees');
};

subtest 'pull request from a branch, reviewed and merged' => sub {
    $repo->contents->create('feature.txt', {
        content    => encode_base64("new feature\n", ''),
        message    => 'add a feature',
        branch     => 'main',
        new_branch => 'feature/pr',
    });
    my $pr = $repo->pulls->create({ head => 'feature/pr', base => 'main', title => 'Add a feature', body => 'please' });
    isa_ok($pr, 'WWW::Forgejo::Entity::PullRequest');
    my $index = $pr->number;
    ok($index, 'created');
    ok($pr->id, 'id');
    is($pr->title, 'Add a feature', 'title');
    is($pr->body, 'please', 'body');
    is($pr->state, 'open', 'state');
    is($pr->head->{ref}, 'feature/pr', 'head');
    is($pr->base->{ref}, 'main', 'base');
    is($pr->user->{login}, $OWNER, 'user');
    like($pr->html_url, qr{/pulls/$index$}, 'html_url');
    ok(!$pr->merged, 'not merged');

    my $got = $repo->pulls->get($index);
    is($got->additions, 1, 'additions');
    is($got->deletions, 0, 'deletions');
    is($got->changed_files, 1, 'changed_files');
    is($got->comments, 0, 'comments');

    my $edited = $repo->pulls->edit($index, { body => 'please merge' });
    is($edited->body, 'please merge', 'edit');

    my %possible = map { ($_->{login} => 1) } $repo->reviewers->list;
    ok($possible{$USER}, 'the collaborator can review');
    my $requested = $repo->reviewers->add($index, $USER);
    is($requested->[0]{state}, 'REQUEST_REVIEW', 'review requested');
    is($repo->reviewers->remove($index, [$USER]), undef, 'request removed');

    my $review = $repo->pulls->create_review($index, { body => 'looks fine', event => 'COMMENT' });
    ok($review->{id}, 'create_review');
    my @reviews = $repo->pulls->reviews($index);
    my $listed = 0;
    for my $listed_review (@reviews) {
        next unless $listed_review->id == $review->{id};
        $listed++;
        is($listed_review->body, 'looks fine', 'review body');
        is($listed_review->state, 'COMMENT', 'review state');
        is($listed_review->user->{login}, $OWNER, 'review user');
        ok($listed_review->submitted_at, 'submitted_at');
    }
    is($listed, 1, 'the review is listed');

    is(scalar(my @open = $repo->pulls->list(state => 'open')), 1, 'list');
    is($repo->pulls->is_merged($index), 0, 'is_merged: no');
    $repo->pulls->merge($index, { Do => 'merge', delete_branch_after_merge => \1 });
    is($repo->pulls->is_merged($index), 1, 'is_merged: yes');

    my $merged = $repo->pulls->get($index);
    ok($merged->merged, 'merged');
    ok($merged->merged_at, 'merged_at');
    is($merged->state, 'closed', 'closed');
    ok(!eval { $repo->branches->get('feature/pr'); 1 }, 'the head branch was deleted');

    eval { $repo->pulls->merge($index, { Do => 'merge' }) };
    like($@, qr/^Forgejo API error: \S/, 'merging twice croaks with the message of the server');
};

subtest 'remove the collaborator' => sub {
    $repo->collaborators->remove($USER);
    is($repo->collaborators->check($USER), 0, 'removed');
};

# =============================================================================
# Hooks, deploy keys, topics
# =============================================================================

subtest 'hooks' => sub {
    my $hook = $repo->hooks->create({
        type   => 'forgejo',
        config => { url => 'http://127.0.0.1:9/hook', content_type => 'json' },
        events => ['push'],
        active => \1,
    });
    isa_ok($hook, 'WWW::Forgejo::Entity::Hook');
    ok($hook->id, 'created');
    is($hook->type, 'forgejo', 'type');
    is($hook->config->{url}, 'http://127.0.0.1:9/hook', 'config');
    is_deeply($hook->events, ['push'], 'events');
    ok($hook->active, 'active');

    is($repo->hooks->get($hook->id)->id, $hook->id, 'get');
    my $updated = $repo->hooks->update($hook->id, { active => \0 });
    ok(!$updated->active, 'update');
    is($repo->hooks->test($hook->id), undef, 'test delivery queued');
    is(scalar(my @hooks = $repo->hooks->list), 1, 'list');
    $repo->hooks->delete($hook->id);
    is(scalar(my @none = $repo->hooks->list), 0, 'delete');
};

subtest 'deploy keys' => sub {
    my $key = $repo->keys->create({ title => 'live deploy key', key => $DEPLOY_KEY, read_only => \1 });
    isa_ok($key, 'WWW::Forgejo::Entity::DeployKey');
    ok($key->id, 'created');
    is($key->title, 'live deploy key', 'title');
    like($DEPLOY_KEY, qr/^\Q@{[ $key->key ]}\E/, 'key');
    ok($key->read_only, 'read_only');
    is($repo->keys->get($key->id)->title, 'live deploy key', 'get');
    is(scalar(my @keys = $repo->keys->list), 1, 'list');
    $repo->keys->delete($key->id);
    is(scalar(my @none = $repo->keys->list), 0, 'delete');
};

subtest 'topics' => sub {
    $repo->topics->add('live');
    is_deeply($repo->topics->list, ['live'], 'add');
    $repo->topics->replace([qw(alpha beta)]);
    is_deeply([ sort @{ $repo->topics->list } ], [qw(alpha beta)], 'replace');
    $repo->topics->remove('alpha');
    is_deeply($repo->topics->list, ['beta'], 'remove');
};

# =============================================================================
# Forks, stars, watching, template
# =============================================================================

subtest 'forks' => sub {
    my $fork = $client->repos->fork($OWNER, $NAME, organization => $ORG);
    isa_ok($fork, 'WWW::Forgejo::Entity::Repo');
    is($fork->owner, $ORG, 'forked into the organization');
    ok($fork->data->{fork}, 'a fork');
    my @forks = $repo->forks->list;
    is($forks[0]{full_name}, "$ORG/$NAME", 'forks list');

    # One fork per owner: a second one into the organization is refused.
    eval { $repo->forks->create({ organization => $ORG, name => $NAME . '-2' }) };
    like($@, qr/^Forgejo API error: repository is already forked/, 'a second fork into the same owner croaks');

    $client->repos->delete($ORG, $NAME);
    my $second = $repo->forks->create({ organization => $ORG, name => $NAME . '-2' });
    is($second->{name}, $NAME . '-2', 'forks create, with another name');
    is(scalar(my @one = $repo->forks->list), 1, 'one fork again');
};

subtest 'stars, through the plain verbs' => sub {
    my $starred = "/user/starred/$OWNER/$NAME";
    is($client->check($starred), 0, 'not starred');
    $client->put($starred);
    is($client->check($starred), 1, 'starred');
    my %stargazers = map { ($_->{login} => 1) } $repo->stargazers->list;
    ok($stargazers{$OWNER}, 'stargazers');
    my %mine = map { ($_->{name} => 1) } @{ $client->current_user->starred };
    ok($mine{$NAME}, 'current_user->starred');
    my %theirs = map { ($_->{name} => 1) } @{ $client->users->starred($OWNER) };
    ok($theirs{$NAME}, 'users->starred');
    $client->delete($starred);
    is($client->check($starred), 0, 'unstarred');
};

subtest 'watching' => sub {
    ok($repo->subscription->get->{subscribed}, 'the owner watches the new repository');
    my %subscribers = map { ($_->{login} => 1) } $repo->subscribers->list;
    ok($subscribers{$OWNER}, 'subscribers');
    my %watched = map { ($_->{name} => 1) } @{ $client->current_user->subscriptions };
    ok($watched{$NAME}, 'current_user->subscriptions');
    is($repo->subscription->unsubscribe, undef, 'unsubscribe');
    ok(!eval { $repo->subscription->get; 1 }, 'get croaks when not watching');
    ok($repo->subscription->subscribe->{subscribed}, 'subscribe');
};

subtest 'create from a template' => sub {
    $repo->update({ template => \1 });
    my $generated = $client->repos->create_from_template($OWNER, $NAME,
        owner       => $OWNER,
        name        => $NAME . '-gen',
        git_content => \1,
        topics      => \1,
    );
    isa_ok($generated, 'WWW::Forgejo::Entity::Repo');
    is($generated->repo, $NAME . '-gen', 'generated');
    is($generated->owner, $OWNER, 'owned by the token user');
    ok($client->repos->delete($OWNER, $NAME . '-gen'), 'deleted');
};

# =============================================================================
# Flags (instance admins only)
# =============================================================================

subtest 'flags' => sub {
    if (!eval { my @flags = $repo->flags->list; 1 }) {
        like($@, qr/^Forgejo API error: 404 page not found/, 'no flags routes on this instance');
        plan skip_all => 'repository flags are switched off ([repository] ENABLE_FLAGS)';
    }
    is($repo->flags->check('live-flag'), 0, 'not set');
    $repo->flags->add('live-flag');
    is($repo->flags->check('live-flag'), 1, 'add, check');
    is_deeply([ $repo->flags->list ], ['live-flag'], 'list');
    $repo->flags->replace([qw(one two)]);
    is_deeply([ sort $repo->flags->list ], [qw(one two)], 'replace');
    $repo->flags->remove('one');
    is_deeply([ $repo->flags->list ], ['two'], 'remove');
    $repo->flags->remove_all;
    is_deeply([ $repo->flags->list ], [], 'remove_all');
};

# =============================================================================
# Actions
# =============================================================================

subtest 'actions variables and secrets' => sub {
    $repo->actions->create_variable('LIVE_VAR', { value => 'one' });
    my $var = $repo->actions->get_variable('LIVE_VAR');
    is($var->{name}, 'LIVE_VAR', 'create_variable');
    is($var->{data}, 'one', 'value comes back as data');
    $repo->actions->set_variable('LIVE_VAR', { value => 'two' });
    is($repo->actions->get_variable('LIVE_VAR')->{data}, 'two', 'set_variable');
    is(scalar @{ $repo->actions->list_variables }, 1, 'list_variables');
    $repo->actions->delete_variable('LIVE_VAR');
    is(scalar @{ $repo->actions->list_variables }, 0, 'delete_variable');

    $repo->actions->set_secret('LIVE_SECRET', { data => 's3cret' });
    my $secrets = $repo->actions->list_secrets;
    is($secrets->[0]{name}, 'LIVE_SECRET', 'set_secret');
    $repo->actions->delete_secret('LIVE_SECRET');
    is(scalar @{ $repo->actions->list_secrets }, 0, 'delete_secret');

    is(scalar(my @runners = $repo->actions->list_runners), 0, 'list_runners: none registered');
};

subtest 'actions runs' => sub {
    # Each push of a workflow starts runs; no runner picks them up.
    for my $n (1 .. 2) {
        $repo->contents->create(".forgejo/workflows/live$n.yml", {
            content => encode_base64("on: [push]\njobs:\n  test:\n    runs-on: docker\n    steps:\n      - run: echo $n\n", ''),
            message => "workflow $n",
        });
    }
    my @runs;
    for (1 .. 10) {
        @runs = $repo->actions->list_runs;
        last if @runs >= 3;
        sleep 1;
    }
    is(scalar @runs, 3, 'list_runs: three runs from two pushes');
    my $run_id;
    for my $run (@runs) {
        $run_id //= $run->id;
        isa_ok($run, 'WWW::Forgejo::Entity::WorkflowRun');
        ok($run->id, 'id');
        like($run->title, qr/^workflow \d$/, 'title');
        is($run->prettyref, 'main', 'prettyref');
        like($run->commit_sha, qr/^[0-9a-f]{40}$/, 'commit_sha');
        like($run->status, qr/^(waiting|cancelled|blocked)$/, 'status: no runner');
        like($run->workflow_id, qr/^live\d\.yml$/, 'workflow_id');
        ok($run->created, 'created');
        ok($run->updated, 'updated');
    }

    # The answer is an envelope { workflow_runs, total_count } without an
    # X-Total-Count header (karr #22); Forgejo 15 honours limit only together
    # with page, and then answers with exactly that page.
    my @page = $repo->actions->list_runs(page => 1, limit => 2);
    is(scalar @page, 2, 'list_runs: an explicit page');
    my @limited = $repo->actions->list_runs(limit => 1);
    ok(scalar @limited >= 1, 'list_runs with limit alone: ' . scalar(@limited) . ' runs');

    my $run = $repo->actions->get_run($run_id);
    is($run->id, $run_id, 'get_run');

    SKIP: {
        skip "Forgejo $MAJOR: run jobs, cancel and delete are API operations of Forgejo 16", 3 if $MAJOR < 16;
        my @jobs = $repo->actions->get_run_jobs($run->id);
        ok(scalar @jobs, 'get_run_jobs');
        ok($repo->actions->cancel_run($run->id), 'cancel_run');
        ok($repo->actions->delete_run($run->id), 'delete_run');
    }
    if ($MAJOR < 16) {
        eval { $repo->actions->get_run_jobs($run->id) };
        like($@, qr/^Forgejo API error: 404 page not found/, "Forgejo $MAJOR: get_run_jobs names the missing route");
    }
};

done_testing;
