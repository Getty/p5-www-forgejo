#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);
use WWW::Forgejo::Entity::Repo;

# The per-repository controllers against the Swagger document: for every
# method the verb, the path, the query string and the JSON body it sends, and
# what it makes of the answer.

my ($client, $io) = mock_client();
my $base = 'https://forgejo.test/api/v1';
my $R    = '/repos/o/r';

my $repo = WWW::Forgejo::Entity::Repo->new(client => $client, owner => 'o', repo => 'r');

# Run one controller method against a canned answer; returns its result in
# list context. $answer is [status, content].
sub call {
    my ($accessor, $method, $args, $answer) = @_;
    $io->reset->add(@{ $answer || [ 200, '{}' ] });
    return $repo->$accessor->$method(@$args);
}

sub request { $io->last->method . ' ' . substr($io->last->url, length $base) }

sub body {
    return undef unless $io->last->has_content;
    return decode_json($io->last->content);
}

# ---------------------------------------------------------------------------
# Request table: [ accessor, method, [args], [status, content], request, body ]
# A body of undef means the request must not carry content at all.
# ---------------------------------------------------------------------------

my $list  = [ 200, '[]' ];
my $none  = [ 204, '' ];
my @table = (
    # Actions
    [ actions => list_runs => [ status => 'success', page => 2 ], [ 200, '{"workflow_runs":[],"total_count":0}' ],
        "GET $R/actions/runs?page=2&status=success" ],
    [ actions => get_run      => [7], undef, "GET $R/actions/runs/7" ],
    [ actions => get_run_jobs => [7], $list, "GET $R/actions/runs/7/jobs" ],
    [ actions => cancel_run   => [7], $none, "POST $R/actions/runs/7/cancel" ],
    [ actions => delete_run   => [7], $none, "DELETE $R/actions/runs/7" ],
    [ actions => list_secrets => [ limit => 5 ], $list, "GET $R/actions/secrets?limit=5" ],
    [ actions => set_secret   => [ 'KEY', { data => 's3cret' } ], $none,
        "PUT $R/actions/secrets/KEY", { data => 's3cret' } ],
    [ actions => delete_secret   => ['KEY'], $none, "DELETE $R/actions/secrets/KEY" ],
    [ actions => list_variables  => [ page => 1 ], $list, "GET $R/actions/variables?page=1" ],
    [ actions => get_variable    => ['STAGE'], undef, "GET $R/actions/variables/STAGE" ],
    [ actions => create_variable => [ 'STAGE', { value => 'prod' } ], $none,
        "POST $R/actions/variables/STAGE", { value => 'prod' } ],
    [ actions => set_variable => [ 'STAGE', { value => 'test', name => 'ENV' } ], $none,
        "PUT $R/actions/variables/STAGE", { value => 'test', name => 'ENV' } ],
    [ actions => delete_variable => ['STAGE'], $none, "DELETE $R/actions/variables/STAGE" ],
    [ actions => list_runners    => [ visible => 'true' ], $list, "GET $R/actions/runners?visible=true" ],

    # Assignees
    [ assignees => list => [], $list, "GET $R/assignees" ],

    # Branches
    [ branches => list   => [ page => 2, limit => 50 ], $list, "GET $R/branches?limit=50&page=2" ],
    [ branches => list   => [], $list, "GET $R/branches" ],
    [ branches => get    => ['main'], undef, "GET $R/branches/main" ],
    [ branches => get    => ['feature/x y'], undef, "GET $R/branches/feature%2Fx%20y" ],
    [ branches => create => [ { new_branch_name => 'dev', old_ref_name => 'main' } ], [ 201, '{"name":"dev"}' ],
        "POST $R/branches", { new_branch_name => 'dev', old_ref_name => 'main' } ],
    [ branches => delete => ['dev'], $none, "DELETE $R/branches/dev" ],
    [ branches => rename => [ "feature/x", "develop" ], $none, "PATCH $R/branches/feature%2Fx", { name => "develop" } ],

    # Branch protections
    [ branch_protections => list   => [], $list, "GET $R/branch_protections" ],
    [ branch_protections => get    => ['main'], undef, "GET $R/branch_protections/main" ],
    [ branch_protections => create => [ { rule_name => 'main' } ], [ 201, '{}' ],
        "POST $R/branch_protections", { rule_name => 'main' } ],
    [ branch_protections => update => [ 'main', { required_approvals => 2 } ], undef,
        "PATCH $R/branch_protections/main", { required_approvals => 2 } ],
    [ branch_protections => edit => [ 'main', { required_approvals => 3 } ], undef,
        "PATCH $R/branch_protections/main", { required_approvals => 3 } ],
    [ branch_protections => delete => ['main'], $none, "DELETE $R/branch_protections/main" ],

    # Collaborators
    [ collaborators => list  => [ limit => 10 ], $list, "GET $R/collaborators?limit=10" ],
    [ collaborators => check => ['alice'], $none, "GET $R/collaborators/alice" ],
    [ collaborators => add   => [ 'alice', { permission => 'write' } ], $none,
        "PUT $R/collaborators/alice", { permission => 'write' } ],
    [ collaborators => add        => ['alice'], $none, "PUT $R/collaborators/alice" ],
    [ collaborators => remove     => ['alice'], $none, "DELETE $R/collaborators/alice" ],
    [ collaborators => permission => ['alice'], undef, "GET $R/collaborators/alice/permission" ],

    # Contents
    [ contents => get => ['lib/My Module.pm'], undef, "GET $R/contents/lib/My%20Module.pm" ],
    [ contents => get => [ 'README.md', ref => 'dev' ], undef, "GET $R/contents/README.md?ref=dev" ],
    [ contents => get => [''], $list, "GET $R/contents" ],
    [ contents => create => [ 'a/b.txt', { content => 'eA==', message => 'add' } ], [ 201, '{}' ],
        "POST $R/contents/a/b.txt", { content => 'eA==', message => 'add' } ],
    [ contents => update => [ 'a/b.txt', { content => 'eQ==', sha => 'abc' } ], undef,
        "PUT $R/contents/a/b.txt", { content => 'eQ==', sha => 'abc' } ],
    [ contents => delete => [ 'a/b.txt', { sha => 'abc', message => 'rm', branch => 'main' } ], undef,
        "DELETE $R/contents/a/b.txt", { sha => 'abc', message => 'rm', branch => 'main' } ],
    [ contents => get_archive => ['main.zip'], [ 200, 'PK-raw' ], "GET $R/archive/main.zip" ],
    [ contents => raw   => [ 'a/b.txt', ref => 'dev' ], [ 200, 'raw text' ], "GET $R/raw/a/b.txt?ref=dev" ],
    [ contents => media => ['a/b.bin'], [ 200, 'raw bytes' ], "GET $R/media/a/b.bin" ],

    # Flags
    [ flags => list   => [], $list, "GET $R/flags" ],
    [ flags => add    => ['featured'], $none, "PUT $R/flags/featured" ],
    [ flags => remove => ['featured'], $none, "DELETE $R/flags/featured" ],
    [ flags => check      => ["featured"], $none, "GET $R/flags/featured" ],
    [ flags => replace    => [ [ "a", "b" ] ], $none, "PUT $R/flags", { flags => [ "a", "b" ] } ],
    [ flags => remove_all => [], $none, "DELETE $R/flags" ],

    # Forks
    [ forks => list   => [ page => 3 ], $list, "GET $R/forks?page=3" ],
    [ forks => create => [ { organization => 'myorg' } ], [ 202, '{}' ], "POST $R/forks", { organization => 'myorg' } ],

    # Git
    [ git => list_refs  => [], $list, "GET $R/git/refs" ],
    [ git => get_ref    => ['heads/main'], $list, "GET $R/git/refs/heads/main" ],
    [ git => get_commit => ['abc'], undef, "GET $R/git/commits/abc" ],
    [ git => get_commit => [ 'abc', stat => 'false' ], undef, "GET $R/git/commits/abc?stat=false" ],
    [ git => get_tree   => [ 'abc', recursive => 'true' ], undef, "GET $R/git/trees/abc?recursive=true" ],
    [ git => get_blob   => ['abc'], undef, "GET $R/git/blobs/abc" ],

    # Hooks
    [ hooks => list   => [ limit => 5 ], $list, "GET $R/hooks?limit=5" ],
    [ hooks => get    => [3], undef, "GET $R/hooks/3" ],
    [ hooks => create => [ { type => 'forgejo', config => { url => 'https://e.x/h' } } ], [ 201, '{}' ],
        "POST $R/hooks", { type => 'forgejo', config => { url => 'https://e.x/h' } } ],
    [ hooks => update => [ 3, { events => ['push'] } ], undef, "PATCH $R/hooks/3", { events => ['push'] } ],
    [ hooks => edit   => [ 3, { events => ['push'] } ], undef, "PATCH $R/hooks/3", { events => ['push'] } ],
    [ hooks => delete => [3], $none, "DELETE $R/hooks/3" ],
    [ hooks => test   => [3], $none, "POST $R/hooks/3/tests" ],
    [ hooks => test   => [ 3, ref => 'main' ], $none, "POST $R/hooks/3/tests?ref=main" ],

    # Issues
    [ issues => list   => [ state => 'open', labels => 'bug' ], $list, "GET $R/issues?labels=bug&state=open" ],
    [ issues => get    => [5], undef, "GET $R/issues/5" ],
    [ issues => create => [ { title => 'T' } ], [ 201, '{}' ], "POST $R/issues", { title => 'T' } ],
    [ issues => edit   => [ 5, { state => 'closed' } ], [ 201, '{}' ], "PATCH $R/issues/5", { state => 'closed' } ],
    [ issues => update => [ 5, { title => 'U' } ], [ 201, '{}' ], "PATCH $R/issues/5", { title => 'U' } ],
    [ issues => delete => [5], $none, "DELETE $R/issues/5" ],
    [ issues => list_comments => [ 5, since => '2026-01-01T00:00:00Z' ], $list,
        "GET $R/issues/5/comments?since=2026-01-01T00%3A00%3A00Z" ],
    [ issues => comments    => [5], $list, "GET $R/issues/5/comments" ],
    [ issues => add_comment => [ 5, { body => 'hi' } ], [ 201, '{}' ], "POST $R/issues/5/comments", { body => 'hi' } ],
    [ issues => list_labels => [5], $list, "GET $R/issues/5/labels" ],
    [ issues => labels      => [5], $list, "GET $R/issues/5/labels" ],
    [ issues => add_label   => [ 5, { labels => [ 1, 2 ] } ], $list, "POST $R/issues/5/labels", { labels => [ 1, 2 ] } ],
    [ issues => remove_label => [ 5, 2 ], $none, "DELETE $R/issues/5/labels/2" ],

    # Keys
    [ keys => list   => [ fingerprint => 'SHA256:x' ], $list, "GET $R/keys?fingerprint=SHA256%3Ax" ],
    [ keys => get    => [4], undef, "GET $R/keys/4" ],
    [ keys => create => [ { title => 't', key => 'ssh-ed25519 AAAA' } ], [ 201, '{}' ],
        "POST $R/keys", { title => 't', key => 'ssh-ed25519 AAAA' } ],
    [ keys => delete => [4], $none, "DELETE $R/keys/4" ],

    # Labels
    [ labels => list   => [ sort => 'mostissues' ], $list, "GET $R/labels?sort=mostissues" ],
    [ labels => get    => [9], undef, "GET $R/labels/9" ],
    [ labels => create => [ { name => 'bug', color => 'ff0000' } ], [ 201, '{}' ],
        "POST $R/labels", { name => 'bug', color => 'ff0000' } ],
    [ labels => update => [ 9, { color => '00ff00' } ], undef, "PATCH $R/labels/9", { color => '00ff00' } ],
    [ labels => edit   => [ 9, { name => 'defect' } ], undef, "PATCH $R/labels/9", { name => 'defect' } ],
    [ labels => delete => [9], $none, "DELETE $R/labels/9" ],

    # Milestones
    [ milestones => list   => [ state => 'closed' ], $list, "GET $R/milestones?state=closed" ],
    [ milestones => get    => [2], undef, "GET $R/milestones/2" ],
    [ milestones => create => [ { title => 'v1' } ], [ 201, '{}' ], "POST $R/milestones", { title => 'v1' } ],
    [ milestones => edit   => [ 2, { state => 'closed' } ], undef, "PATCH $R/milestones/2", { state => 'closed' } ],
    [ milestones => update => [ 2, { title => 'v2' } ], undef, "PATCH $R/milestones/2", { title => 'v2' } ],
    [ milestones => delete => [2], $none, "DELETE $R/milestones/2" ],
    [ milestones => issues => [2], $list, "GET $R/issues?milestones=2" ],
    [ milestones => issues => [ 2, state => 'closed' ], $list, "GET $R/issues?milestones=2&state=closed" ],

    # Pull requests
    [ pulls => list   => [ state => 'open', base => 'main' ], $list, "GET $R/pulls?base=main&state=open" ],
    [ pulls => get    => [7], undef, "GET $R/pulls/7" ],
    [ pulls => create => [ { title => 'T', head => 'f', base => 'main' } ], [ 201, '{}' ],
        "POST $R/pulls", { title => 'T', head => 'f', base => 'main' } ],
    [ pulls => edit   => [ 7, { title => 'U' } ], [ 201, '{}' ], "PATCH $R/pulls/7", { title => 'U' } ],
    [ pulls => update => [ 7, { title => 'V' } ], [ 201, '{}' ], "PATCH $R/pulls/7", { title => 'V' } ],
    [ pulls => merge  => [ 7, { Do => 'squash' } ], [ 200, '' ], "POST $R/pulls/7/merge", { Do => 'squash' } ],
    [ pulls => is_merged     => [7], $none, "GET $R/pulls/7/merge" ],
    [ pulls => reviews       => [ 7, page => 2 ], $list, "GET $R/pulls/7/reviews?page=2" ],
    [ pulls => create_review => [ 7, { event => 'COMMENT', body => 'b' } ], undef,
        "POST $R/pulls/7/reviews", { event => 'COMMENT', body => 'b' } ],

    # Releases
    [ releases => list => [ draft => 'true', 'pre-release' => 'false' ], $list,
        "GET $R/releases?draft=true&pre-release=false" ],
    [ releases => get        => [1], undef, "GET $R/releases/1" ],
    [ releases => get_by_tag => ['v1.0'], undef, "GET $R/releases/tags/v1.0" ],
    [ releases => create     => [ { tag_name => 'v1.0' } ], [ 201, '{}' ], "POST $R/releases", { tag_name => 'v1.0' } ],
    [ releases => edit       => [ 1, { name => 'N' } ], undef, "PATCH $R/releases/1", { name => 'N' } ],
    [ releases => update     => [ 1, { name => 'M' } ], undef, "PATCH $R/releases/1", { name => 'M' } ],
    [ releases => delete     => [1], $none, "DELETE $R/releases/1" ],
    [ releases => assets     => [1], $list, "GET $R/releases/1/assets" ],
    [ releases => latest        => [], undef, "GET $R/releases/latest" ],
    [ releases => delete_by_tag => ["v1.0"], $none, "DELETE $R/releases/tags/v1.0" ],
    [ releases => get_asset     => [ 1, 9 ], undef, "GET $R/releases/1/assets/9" ],
    [ releases => edit_asset    => [ 1, 9, { name => "new.tar.gz" } ], [ 201, "{}" ],
        "PATCH $R/releases/1/assets/9", { name => "new.tar.gz" } ],
    [ releases => delete_asset  => [ 1, 9 ], $none, "DELETE $R/releases/1/assets/9" ],

    # Reviewers
    [ reviewers => list => [], $list, "GET $R/reviewers" ],
    [ reviewers => add  => [ 7, [ 'a', 'b' ] ], [ 201, '[]' ],
        "POST $R/pulls/7/requested_reviewers", { reviewers => [ 'a', 'b' ] } ],
    [ reviewers => add => [ 7, 'a', ['team'] ], [ 201, '[]' ],
        "POST $R/pulls/7/requested_reviewers", { reviewers => ['a'], team_reviewers => ['team'] } ],
    [ reviewers => remove => [ 7, 'a' ], $none,
        "DELETE $R/pulls/7/requested_reviewers", { reviewers => ['a'] } ],
    [ reviewers => remove => [ 7, undef, 'team' ], $none,
        "DELETE $R/pulls/7/requested_reviewers", { team_reviewers => ['team'] } ],

    # Stargazers, subscribers
    [ stargazers  => list => [ page => 2, limit => 10 ], $list, "GET $R/stargazers?limit=10&page=2" ],
    [ subscribers => list => [ page => 2, limit => 10 ], $list, "GET $R/subscribers?limit=10&page=2" ],

    # Statuses
    [ statuses => list   => ['abc'], $list, "GET $R/statuses/abc" ],
    [ statuses => list   => [ 'abc', state => 'failure', sort => 'oldest' ], $list,
        "GET $R/statuses/abc?sort=oldest&state=failure" ],
    [ statuses => create => [ 'abc', { state => 'success', context => 'ci' } ], [ 201, '{}' ],
        "POST $R/statuses/abc", { state => 'success', context => 'ci' } ],
    [ statuses => combined => ['main'], undef, "GET $R/commits/main/status" ],
    [ statuses => combined => [ 'feature/x', limit => 5 ], undef, "GET $R/commits/feature%2Fx/status?limit=5" ],

    # Subscription
    [ subscription => get         => [], undef, "GET $R/subscription" ],
    [ subscription => subscribe   => [], undef, "PUT $R/subscription" ],
    [ subscription => unsubscribe => [], $none, "DELETE $R/subscription" ],

    # Tag protections
    [ tag_protections => list   => [], $list, "GET $R/tag_protections" ],
    [ tag_protections => get    => [6], undef, "GET $R/tag_protections/6" ],
    [ tag_protections => create => [ { name_pattern => 'v*' } ], [ 201, '{}' ],
        "POST $R/tag_protections", { name_pattern => 'v*' } ],
    [ tag_protections => delete => [6], $none, "DELETE $R/tag_protections/6" ],
    [ tag_protections => edit   => [ 6, { name_pattern => "release-*" } ], undef,
        "PATCH $R/tag_protections/6", { name_pattern => "release-*" } ],
    [ tag_protections => update => [ 6, { whitelist_teams => ["core"] } ], undef,
        "PATCH $R/tag_protections/6", { whitelist_teams => ["core"] } ],

    # Tags
    [ tags => list   => [ limit => 100 ], $list, "GET $R/tags?limit=100" ],
    [ tags => get    => ['v1.0'], undef, "GET $R/tags/v1.0" ],
    [ tags => create => [ { tag_name => 'v1.0', target => 'main' } ], [ 201, '{}' ],
        "POST $R/tags", { tag_name => 'v1.0', target => 'main' } ],
    [ tags => delete => ['v1.0'], $none, "DELETE $R/tags/v1.0" ],

    # Topics
    [ topics => list    => [ limit => 5 ], [ 200, '{"topics":[]}' ], "GET $R/topics?limit=5" ],
    [ topics => add     => ['perl'], $none, "PUT $R/topics/perl" ],
    [ topics => replace => [ [ 'perl', 'cpan' ] ], $none, "PUT $R/topics", { topics => [ 'perl', 'cpan' ] } ],
    [ topics => remove  => ['perl'], $none, "DELETE $R/topics/perl" ],

    # Wiki
    [ wiki => list_pages  => [ page => 2 ], $list, "GET $R/wiki/pages?page=2" ],
    [ wiki => get_page    => ['Home Page'], undef, "GET $R/wiki/page/Home%20Page" ],
    [ wiki => create_page => [ { title => 'T', content_base64 => 'eA==' } ], [ 201, '{}' ],
        "POST $R/wiki/new", { title => 'T', content_base64 => 'eA==' } ],
    [ wiki => edit_page => [ 'Home', { content_base64 => 'eQ==' } ], undef,
        "PATCH $R/wiki/page/Home", { content_base64 => 'eQ==' } ],
    [ wiki => delete_page => ['Home'], $none, "DELETE $R/wiki/page/Home" ],
);

subtest 'requests: verb, path, query string and body' => sub {
    for my $row (@table) {
        my ($accessor, $method, $args, $answer, $request, $body) = @$row;
        my $name = "$accessor->$method";
        my @result = eval { call($accessor, $method, $args, $answer) };
        is($@, '', "$name does not die");
        is($io->count, 1, "$name sends exactly one request") or next;
        is(request(), $request, "$name: $request");
        is_deeply(body(), $body, "$name: " . (defined $body ? 'JSON body' : 'no body'));
        is($io->last->headers->{Authorization}, 'token test-token', "$name: authenticated");
    }
};

subtest 'every public controller method is in the request table' => sub {
    my %covered = map { ("$_->[0]->$_->[1]" => 1) } @table;
    $covered{'releases->upload_asset'} = 1;    # multipart, tested on its own below
    opendir my $dh, 'lib/WWW/Forgejo/API/Repo' or die $!;
    my %accessor = (BranchProtections => 'branch_protections', TagProtections => 'tag_protections', PullRequests => 'pulls');
    for my $file (sort grep { /\.pm\z/ } readdir $dh) {
        (my $class = $file) =~ s/\.pm\z//;
        my $accessor = $accessor{$class} || lc $class;
        open my $fh, '<', "lib/WWW/Forgejo/API/Repo/$file" or die $!;
        my @subs = grep { !/^_/ } map { /^sub (\w+)/ ? $1 : () } <$fh>;
        ok($covered{"$accessor->$_"}, "$accessor->$_ is covered") for @subs;
    }
};

# ---------------------------------------------------------------------------
# Query parameters (finding: %params used to be handed to get() raw, so the
# filters never reached the URL)
# ---------------------------------------------------------------------------

subtest 'undefined filters are left out, values are escaped' => sub {
    call(branches => list => [ page => undef, limit => 10 ], $list);
    is(request(), "GET $R/branches?limit=10", 'undef parameter dropped');

    call(releases => list => [ q => 'a b&c' ], $list);
    is(request(), "GET $R/releases?q=a%20b%26c", 'value escaped');
};

subtest 'a pinned page is not auto-paginated, an unpinned list is' => sub {
    $io->reset->add(200, '[{"name":"a"}]', 'X-Total-Count' => 3);
    my @tags = $repo->tags->list(page => 1, limit => 1);
    is($io->count, 1, 'page given: one request');
    is(scalar @tags, 1, 'one tag');

    $io->reset;
    $io->add(200, '[{"name":"a"}]', 'X-Total-Count' => 2);
    $io->add(200, '[{"name":"b"}]', 'X-Total-Count' => 2);
    @tags = $repo->tags->list;
    is($io->count, 2, 'no page given: follow-up request');
    is_deeply([ map { $_->{name} } @tags ], [ 'a', 'b' ], 'both pages');
    like($io->last->url, qr{/tags\?limit=1&page=2\z}, 'second page requested');
};

subtest 'owner and repository name are escaped in every controller' => sub {
    my $odd = WWW::Forgejo::Entity::Repo->new(client => $client, owner => 'my org', repo => 'a/b');
    my %first = (
        actions => [ list_runners => "actions/runners" ], assignees => [ list => 'assignees' ],
        branches => [ list => 'branches' ], branch_protections => [ list => 'branch_protections' ],
        collaborators => [ list => 'collaborators' ], contents => [ get => 'contents' ],
        flags => [ list => 'flags' ], forks => [ list => 'forks' ], git => [ list_refs => 'git/refs' ],
        hooks => [ list => 'hooks' ], issues => [ list => 'issues' ], keys => [ list => 'keys' ],
        labels => [ list => 'labels' ], milestones => [ list => 'milestones' ], pulls => [ list => 'pulls' ],
        releases => [ list => 'releases' ], reviewers => [ list => 'reviewers' ],
        stargazers => [ list => 'stargazers' ], statuses => [ list => 'statuses/abc', 'abc' ],
        subscribers => [ list => 'subscribers' ], subscription => [ get => 'subscription' ],
        tag_protections => [ list => 'tag_protections' ], tags => [ list => 'tags' ],
        topics => [ list => 'topics' ], wiki => [ list_pages => 'wiki/pages' ],
    );
    for my $accessor (sort keys %first) {
        my ($method, $path, @args) = @{ $first{$accessor} };
        $io->reset->add(200, $accessor eq 'topics' || $accessor eq 'subscription' ? '{}' : '[]');
        eval { $odd->$accessor->$method(@args) };
        is(request(), "GET /repos/my%20org/a%2Fb/$path", "$accessor: escaped, no trailing slash");
    }
};

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------

sub is_bound {
    my ($entity, $class, $name) = @_;
    isa_ok($entity, "WWW::Forgejo::Entity::$class", $name);
    is($entity->client, $client, "$name: client");
    is($entity->owner, 'o', "$name: owner") if $entity->can('owner');
    is($entity->repo,  'r', "$name: repo")  if $entity->can('repo');
}

subtest 'actions: runs and jobs come back as entities' => sub {
    my @runs = call(actions => list_runs => [],
        [ 200, '{"total_count":2,"workflow_runs":[{"id":1,"status":"success"},{"id":2,"status":"failure"}]}' ]);
    is(scalar @runs, 2, 'runs taken from workflow_runs');
    is_bound($runs[0], 'WorkflowRun', 'run');
    is($runs[1]->status, 'failure', 'run data');

    @runs = call(actions => list_runs => [], [ 200, '{"total_count":0}' ]);
    is(scalar @runs, 0, 'no workflow_runs member: empty list');

    my ($run) = call(actions => get_run => [1], [ 200, '{"id":1,"status":"success"}' ]);
    is_bound($run, 'WorkflowRun', 'get_run');
    is($run->id, 1, 'get_run data');

    my @jobs = call(actions => get_run_jobs => [1], [ 200, '[{"id":10,"name":"test","status":"success"}]' ]);
    is(scalar @jobs, 1, 'one job');
    is_bound($jobs[0], 'WorkflowJob', 'job');
    is($jobs[0]->name, 'test', 'job data');

    is(scalar(call(actions => cancel_run => [1], $none)), 1, 'cancel_run returns true');
    is(scalar(call(actions => delete_run => [1], $none)), 1, 'delete_run returns true');

    my @runners = call(actions => list_runners => [], [ 200, '[{"id":1},{"id":2}]' ]);
    is(scalar @runners, 2, 'runners as list');
};

subtest 'actions: operations the API does not have are gone' => sub {
    ok(!WWW::Forgejo::API::Repo::Actions->can($_), "no actions->$_")
        for qw(rerun get_secret create_secret list_workflows);
};

subtest 'assignees: only the list exists' => sub {
    my @users = call(assignees => list => [], [ 200, '[{"login":"a"},{"login":"b"}]' ]);
    is_deeply([ map { $_->{login} } @users ], [ 'a', 'b' ], 'users as plain data');
    ok(!WWW::Forgejo::API::Repo::Assignees->can($_), "no assignees->$_") for qw(check add remove);
};

subtest 'branches: entities' => sub {
    my @branches = call(branches => list => [], [ 200, '[{"name":"main","protected":true},{"name":"dev"}]' ]);
    is(scalar @branches, 2, 'two branches');
    is_bound($branches[0], 'Branch', 'list');
    is($branches[0]->name, 'main', 'branch name');

    my ($branch) = call(branches => get => ['main'], [ 200, '{"name":"main"}' ]);
    is_bound($branch, 'Branch', 'get');

    ($branch) = call(branches => create => [ { new_branch_name => 'dev' } ], [ 201, '{"name":"dev"}' ]);
    is_bound($branch, 'Branch', 'create');
    is($branch->name, 'dev', 'created branch');

    is(scalar(call(branches => rename => [ "dev", "develop" ], $none)), 1, "rename returns true on the empty 204 answer");

    # branch protection lives in its own controller
    ok(!WWW::Forgejo::API::Repo::Branches->can($_), "no branches->$_") for qw(protect unprotect list_protected);
};

subtest 'branch protections: entities' => sub {
    my @list = call(branch_protections => list => [], [ 200, '[{"rule_name":"main"}]' ]);
    is_bound($list[0], 'BranchProtection', 'list');
    is($list[0]->rule_name, 'main', 'rule name');
    for my $method (qw(get create update edit)) {
        my ($p) = call(branch_protections => $method => [ $method eq 'create' ? {} : ('main', {}) ],
            [ 200, '{"rule_name":"main"}' ]);
        is_bound($p, 'BranchProtection', $method);
    }
};

subtest 'collaborators: check is a yes/no question' => sub {
    ok(scalar(call(collaborators => check => ['alice'], $none)), '204 => collaborator');
    my $is = eval { scalar call(collaborators => check => ['bob'], [ 404, '{"message":"not found"}' ]) };
    is($@, '', '404 does not croak');
    ok(!$is, '404 => not a collaborator');
    eval { call(collaborators => check => ['bob'], [ 403, '{"message":"forbidden"}' ]) };
    like($@, qr/Forgejo API error: forbidden/, 'other errors croak');

    my @list = call(collaborators => list => [], [ 200, '[{"login":"alice","id":3}]' ]);
    is_bound($list[0], 'Collaborator', 'list');
    is($list[0]->login, 'alice', 'login');

    is(scalar(call(collaborators => add => [ 'alice', { permission => 'read' } ], $none)), 1,
        'add returns true on the empty 204 answer');

    my $permission = call(collaborators => permission => ['alice'],
        [ 200, '{"permission":"write","role_name":"write","user":{"login":"alice"}}' ]);
    is($permission->{permission}, 'write', 'permission returns the permission structure');
    is($permission->{user}{login}, 'alice', 'with the user');

    # GET /collaborators/{collaborator} has no body, so there is nothing to get
    ok(!WWW::Forgejo::API::Repo::Collaborators->can('get'), 'no collaborators->get');
};

subtest 'contents: delete needs the sha and sends it in the body' => sub {
    $io->reset;
    eval { $repo->contents->delete('a.txt') };
    like($@, qr/sha required to delete a file/, 'croaks without data');
    eval { $repo->contents->delete('a.txt', { message => 'rm' }) };
    like($@, qr/sha required to delete a file/, 'croaks without sha');
    like($@, qr/31-repo-controllers\.t/, 'reported at the caller');
    is($io->count, 0, 'nothing sent');

    my $result = call(contents => delete => [ 'a.txt', { sha => 'abc' } ],
        [ 200, '{"commit":{"sha":"def"},"content":null}' ]);
    is($result->{commit}{sha}, 'def', 'delete returns the response');
    is($io->last->headers->{'Content-Type'}, 'application/json', 'JSON request');
};

subtest 'contents: file data and raw bodies' => sub {
    my $file = call(contents => get => ['a.txt'], [ 200, '{"name":"a.txt","sha":"abc","type":"file"}' ]);
    is($file->{sha}, 'abc', 'file metadata');

    my $dir = call(contents => get => ['lib'], [ 200, '[{"name":"A.pm"},{"name":"B.pm"}]' ]);
    is(scalar @$dir, 2, 'directory entries');

    is(call(contents => raw => ['a.txt'], [ 200, "plain\ntext\n" ]), "plain\ntext\n", 'raw returns the body as it is');
    is(call(contents => media => ['a.bin'], [ 200, 'BYTES' ]), 'BYTES', 'media returns the body as it is');
    is(call(contents => get_archive => ['main.zip'], [ 200, 'PKzip' ]), 'PKzip', 'archive returns the body as it is');

    # Found against a live Forgejo 15: a JSON file came back decoded, and a
    # text file as characters instead of the bytes the file holds.
    is(call(contents => raw => ['a.json'], [ 200, qq({"a":1}\n), 'Content-Type' => 'text/plain; charset=utf-8' ]),
        qq({"a":1}\n), 'raw: a JSON file is not decoded');
    is(call(contents => media => ['a.json'], [ 200, '[1,2]', 'Content-Type' => 'application/octet-stream' ]),
        '[1,2]', 'media: neither is a JSON array');
    my $utf8 = "Gr\xc3\xbc\xc3\x9fe \xe2\x9c\x93\n";
    my $raw  = call(contents => raw => ['u.txt'], [ 200, $utf8, 'Content-Type' => 'text/plain; charset=utf-8' ]);
    is($raw, $utf8, 'raw: a UTF-8 text file comes back as its bytes');
    ok(!utf8::is_utf8($raw), 'a byte string');
    is(call(contents => media => ['u.txt'], [ 200, $utf8, 'Content-Type' => 'text/plain; charset=utf-8' ]),
        $utf8, 'media: the same');
    eval { call(contents => raw => ['gone.txt'], [ 404, '{"message":"file does not exist"}', 'Content-Type' => 'application/json' ]) };
    like($@, qr/^Forgejo API error: file does not exist/, 'raw: an error still croaks with the message of the server');

    ok(!WWW::Forgejo::API::Repo::Contents->can('readme'), 'no contents->readme (not an API operation)');
};

subtest 'no path is built with ../' => sub {
    for my $row (@table) {
        my ($accessor, $method, $args, $answer) = @$row;
        eval { call($accessor, $method, $args, $answer) };
        unlike($io->last->url, qr{/\.\./|//repos|/\z}, "$accessor->$method: clean path");
    }
};

subtest 'flags and forks' => sub {
    my @flags = call(flags => list => [], [ 200, '["a","b"]' ]);
    is_deeply(\@flags, [ 'a', 'b' ], 'flags as list of strings');
    my @forks = call(forks => list => [], [ 200, '[{"name":"r","owner":{"login":"x"}}]' ]);
    is($forks[0]{owner}{login}, 'x', 'forks as plain data');
    my $fork = call(forks => create => [ {} ], [ 202, '{"name":"r","owner":{"login":"me"}}' ]);
    is($fork->{owner}{login}, 'me', 'created fork as plain data');

    is(scalar(call(flags => check => ["a"], $none)), 1, "check: 204 means the flag is set");
    is(scalar(call(flags => check => ["a"], [ 404, "" ])), 0, "check: 404 means it is not");
    ok(!eval { call(flags => check => ["a"], [ 403, q({"message":"nope"}) ]); 1 }, "check: other errors croak");
    is(eval { call(flags => replace => [ ["a"] ], $none); 1 }, 1, "replace copes with the empty 204 answer");
    is(eval { call(flags => remove_all => [], $none); 1 }, 1, "remove_all copes with the empty 204 answer");
};

subtest 'git: read only' => sub {
    my $refs = call(git => get_ref => ['heads/main'], [ 200, '[{"ref":"refs/heads/main"}]' ]);
    is($refs->[0]{ref}, 'refs/heads/main', 'get_ref returns the list the API sends');
    ok(!WWW::Forgejo::API::Repo::Git->can($_), "no git->$_") for qw(create_ref delete_ref);
};

subtest 'hooks: entities, and test is the only trigger' => sub {
    my @hooks = call(hooks => list => [], [ 200, '[{"id":1,"type":"forgejo","active":true}]' ]);
    is_bound($hooks[0], 'Hook', 'list');
    is($hooks[0]->type, 'forgejo', 'hook data');
    for my $method (qw(get create update edit)) {
        my ($hook) = call(hooks => $method => [ $method eq 'create' ? {} : (1, {}) ], [ 200, '{"id":1}' ]);
        is_bound($hook, 'Hook', $method);
    }
    ok(!WWW::Forgejo::API::Repo::Hooks->can('ping'), 'no hooks->ping');
    is(eval { call(hooks => test => [1], $none); 1 }, 1, 'test copes with the empty 204 answer');
};

subtest 'issues and milestones: entities' => sub {
    my @issues = call(issues => list => [], [ 200, '[{"number":1,"title":"a"}]' ]);
    is_bound($issues[0], 'Issue', 'issues->list');
    my @comments = call(issues => list_comments => [1], [ 200, '[{"id":5,"body":"c"}]' ]);
    is_bound($comments[0], 'IssueComment', 'issues->list_comments');
    @comments = call(issues => comments => [1], [ 200, '[{"id":5,"body":"c"}]' ]);
    is($comments[0]->body, 'c', 'comments alias');
    my @labels = call(issues => labels => [1], [ 200, '[{"id":1,"name":"bug"}]' ]);
    is($labels[0]{name}, 'bug', 'labels alias');

    my @milestones = call(milestones => list => [], [ 200, '[{"id":2,"title":"v1"}]' ]);
    is_bound($milestones[0], 'Milestone', 'milestones->list');
    for my $method (qw(get create edit update)) {
        my ($m) = call(milestones => $method => [ $method eq 'create' ? {} : (2, {}) ], [ 200, '{"id":2,"title":"v1"}' ]);
        is_bound($m, 'Milestone', "milestones->$method");
    }
    my @of = call(milestones => issues => [2], [ 200, '[{"number":3,"title":"in milestone"}]' ]);
    is_bound($of[0], 'Issue', 'milestones->issues');
    is($of[0]->number, 3, 'issue of the milestone');
};

subtest 'keys: entities' => sub {
    my @keys = call(keys => list => [], [ 200, '[{"id":4,"title":"deploy"}]' ]);
    is_bound($keys[0], 'DeployKey', 'list');
    for my $method (qw(get create)) {
        my ($key) = call(keys => $method => [ $method eq 'create' ? {} : 4 ], [ 200, '{"id":4,"title":"deploy"}' ]);
        is_bound($key, 'DeployKey', $method);
        is($key->title, 'deploy', "$method data");
    }
};

subtest 'releases: every method returns bound entities' => sub {
    my $release = '{"id":1,"tag_name":"v1.0","name":"First"}';
    my @releases = call(releases => list => [], [ 200, "[$release]" ]);
    is(scalar @releases, 1, 'one release');
    is_bound($releases[0], 'Release', 'list');
    is($releases[0]->tag_name, 'v1.0', 'list data');

    my %args = (get => [1], get_by_tag => ['v1.0'], create => [ { tag_name => 'v1.0' } ], edit => [ 1, {} ], update => [ 1, {} ]);
    for my $method (sort keys %args) {
        my ($r) = call(releases => $method => $args{$method}, [ 200, $release ]);
        is_bound($r, 'Release', $method);
        is($r->id, 1, "$method data");
    }

    my @assets = call(releases => assets => [1], [ 200, '[{"id":9,"name":"app.tar.gz","size":3}]' ]);
    is(scalar @assets, 1, 'one asset');
    is_bound($assets[0], 'ReleaseAsset', 'assets');
    is($assets[0]->name, 'app.tar.gz', 'asset data');

    is(scalar(call(releases => delete => [1], $none)), 1, 'delete returns true');

    my ($latest) = call(releases => latest => [], [ 200, $release ]);
    is_bound($latest, "Release", "latest");
    is($latest->tag_name, "v1.0", "latest data");
    is(scalar(call(releases => delete_by_tag => ["v1.0"], $none)), 1, "delete_by_tag returns true");

    my $asset = q({"id":9,"name":"app.tar.gz","size":3});
    my %asset_args = (get_asset => [ 1, 9 ], edit_asset => [ 1, 9, { name => "app.tar.gz" } ]);
    for my $method (sort keys %asset_args) {
        my ($a) = call(releases => $method => $asset_args{$method}, [ 200, $asset ]);
        is_bound($a, "ReleaseAsset", $method);
        is($a->id, 9, "$method data");
    }
    is(scalar(call(releases => delete_asset => [ 1, 9 ], $none)), 1, "delete_asset returns true");
};

subtest 'releases: upload_asset is a multipart upload' => sub {
    my ($asset) = call(releases => upload_asset => [ 1, filename => 'notes.txt', content => "hello\n", name => 'release notes.txt' ],
        [ 201, '{"id":9,"name":"release notes.txt","size":6}' ]);
    is(request(), "POST $R/releases/1/assets?name=release%20notes.txt", 'name goes into the query string');

    my $req = $io->last;
    like($req->headers->{'Content-Type'}, qr{^multipart/form-data; boundary=}, 'multipart content type');
    like($req->content, qr{Content-Disposition: form-data; name="attachment"; filename="notes\.txt"},
        'file sent in the attachment field');
    like($req->content, qr{\r\n\r\nhello\n\r\n--}, 'file content inside the part');
    unlike($req->content, qr{^\{}, 'not a JSON body');

    is_bound($asset, 'ReleaseAsset', 'upload_asset');
    is($asset->id, 9, 'asset data');

    call(releases => upload_asset => [ 1, file => 't/fixtures/user.json' ], [ 201, '{"id":10}' ]);
    is(request(), "POST $R/releases/1/assets", 'no name: no query string');
    like($io->last->content, qr{filename="user\.json"}, 'file name taken from the path');
    like($io->last->content, qr{"login"}, 'file content read from disk');

    $io->reset;
    eval { $repo->releases->upload_asset(1) };
    like($@, qr/upload: file or content required/, 'croaks without a file');
    is($io->count, 0, 'nothing sent');
};

subtest 'pull requests: entities' => sub {
    my @pulls = call(pulls => list => [], [ 200, '[{"number":7,"title":"t"}]' ]);
    is_bound($pulls[0], 'PullRequest', 'list');
    my @reviews = call(pulls => reviews => [7], [ 200, '[{"id":1,"state":"APPROVED"}]' ]);
    is_bound($reviews[0], 'PullRequestReview', 'reviews');
    is(eval { call(pulls => merge => [ 7, { Do => 'merge' } ], [ 200, '' ]); 1 }, 1, 'merge copes with the empty answer');
};

subtest 'reviewers' => sub {
    my @users = call(reviewers => list => [], [ 200, '[{"login":"a"}]' ]);
    is($users[0]{login}, 'a', 'possible reviewers as plain data');
    my $reviews = call(reviewers => add => [ 7, ['a'] ], [ 201, '[{"id":1,"state":"REQUEST_REVIEW"}]' ]);
    is($reviews->[0]{state}, 'REQUEST_REVIEW', 'add returns the reviews');
};

subtest 'statuses: entities and the combined status' => sub {
    my @statuses = call(statuses => list => ['abc'], [ 200, '[{"id":1,"status":"success","context":"ci"}]' ]);
    is(scalar @statuses, 1, 'one status');
    is_bound($statuses[0], 'CommitStatus', 'list');
    is($statuses[0]->context, 'ci', 'list data');

    my ($status) = call(statuses => create => [ 'abc', { state => 'pending' } ], [ 201, '{"id":2,"status":"pending"}' ]);
    is_bound($status, 'CommitStatus', 'create');
    is($status->status, 'pending', 'create data: the answer carries the state as "status"');

    my $combined = call(statuses => combined => ['main'],
        [ 200, '{"state":"success","sha":"abc","total_count":1,"statuses":[{"id":1}]}' ]);
    is($combined->{state}, 'success', 'combined state');
    is($combined->{statuses}[0]{id}, 1, 'combined statuses');
    ok(!WWW::Forgejo::API::Repo::Statuses->can('get_latest'), 'no statuses->get_latest');
};

subtest 'subscription' => sub {
    my $watch = call(subscription => subscribe => [], [ 200, '{"subscribed":true}' ]);
    ok($watch->{subscribed}, 'subscribe returns the watch state');
    eval { call(subscription => get => [], [ 404, '{"message":"not watching"}' ]) };
    like($@, qr/Forgejo API error: not watching/, 'get croaks when not watching');
};

subtest 'tags, tag protections, labels: plain data' => sub {
    my @tags = call(tags => list => [], [ 200, '[{"name":"v1"},{"name":"v2"}]' ]);
    is_deeply([ map { $_->{name} } @tags ], [ 'v1', 'v2' ], 'tags');
    my @protections = call(tag_protections => list => [], [ 200, '[{"id":1,"name_pattern":"v*"}]' ]);
    is($protections[0]{name_pattern}, 'v*', 'tag protections');
    my $edited = call(tag_protections => edit => [ 1, { name_pattern => "r*" } ], [ 200, q({"id":1,"name_pattern":"r*"}) ]);
    is($edited->{name_pattern}, "r*", "edited tag protection as plain data");
    my @labels = call(labels => list => [], [ 200, '[{"id":1,"name":"bug"}]' ]);
    is($labels[0]{name}, 'bug', 'labels');
};

subtest 'topics: add one, replace all' => sub {
    my $topics = call(topics => list => [], [ 200, '{"topics":["perl","cpan"]}' ]);
    is_deeply($topics, [ 'perl', 'cpan' ], 'list returns the names');
    is_deeply(call(topics => list => [], [ 200, '{}' ]), [], 'no topics member: empty list');
    is(eval { call(topics => add => ['x'], $none); 1 }, 1, 'add copes with the empty 204 answer');
    is(eval { call(topics => replace => [ ['x'] ], $none); 1 }, 1, 'replace copes with the empty 204 answer');
};

subtest 'wiki' => sub {
    my @pages = call(wiki => list_pages => [], [ 200, '[{"title":"Home"},{"title":"FAQ"}]' ]);
    is_deeply([ map { $_->{title} } @pages ], [ 'Home', 'FAQ' ], 'pages as list');
    my $page = call(wiki => get_page => ['Home'], [ 200, '{"title":"Home","content_base64":"eA=="}' ]);
    is($page->{content_base64}, 'eA==', 'page data');
    call(wiki => delete_page => ['Home'], $none);
    ok(!$io->last->has_content, 'delete_page sends no body');
};

subtest 'stargazers and subscribers' => sub {
    for my $accessor (qw(stargazers subscribers)) {
        my @users = call($accessor => list => [], [ 200, '[{"login":"a"},{"login":"b"}]' ]);
        is_deeply([ map { $_->{login} } @users ], [ 'a', 'b' ], "$accessor as list of users");
    }
};

done_testing;
