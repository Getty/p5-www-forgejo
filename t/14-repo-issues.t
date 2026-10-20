#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);
use WWW::Forgejo::API::Repo::Issues;

# The issue endpoints of a repository that the client did not cover yet: the
# comments of the repository as a whole, the assets and the reactions of issues
# and comments, the blocks and the dependencies, the deadline, the labels, the
# pin, the stopwatch, the subscriptions, the timeline and the tracked times.
#
# Every call is made in an eval, so a method that does not exist shows up as a
# failed test instead of a dead file.

my ($client, $io) = mock_client();
my $base = 'https://forgejo.test/api/v1';

my $issues = WWW::Forgejo::API::Repo::Issues->new(
    client => $client,
    owner  => 'owner',
    repo   => 'repo',
);

sub request {
    my $last = $io->last or return '(no request)';
    return $last->method . ' ' . substr($last->url, length $base);
}

sub body {
    my $last = $io->last or return undef;
    return $last->has_content ? decode_json($last->content) : undef;
}

# The value of an expression, or undef when it dies.
sub value { return eval { $_[0]->() } }

# ---------------------------------------------------------------------------
# The pinned issues
# ---------------------------------------------------------------------------

subtest 'the pinned issues of the repository' => sub {
    $io->reset->add(200, '[{"number":1,"title":"Pinned"}]');
    my $pinned = value(sub { $issues->list_pinned });
    is(request(), 'GET /repos/owner/repo/issues/pinned', 'GET /repos/{owner}/{repo}/issues/pinned');
    is(ref $pinned, 'ARRAY', 'list_pinned returns an arrayref') or return;
    isa_ok($pinned->[0], 'WWW::Forgejo::Entity::Issue');
    is(value(sub { $pinned->[0]->title }), 'Pinned', 'the title of the pinned issue');
};

# ---------------------------------------------------------------------------
# The comments of the repository
# ---------------------------------------------------------------------------

subtest 'the comments of all issues of the repository' => sub {
    $io->reset->add(200, '[{"id":7,"body":"a comment"}]');
    my $comments = value(sub { $issues->list_repo_comments });
    is(request(), 'GET /repos/owner/repo/issues/comments', 'GET /repos/{owner}/{repo}/issues/comments');
    is(ref $comments, 'ARRAY', 'list_repo_comments returns an arrayref') or return;
    isa_ok($comments->[0], 'WWW::Forgejo::Entity::IssueComment');
    is(value(sub { $comments->[0]->body }), 'a comment', 'the body of the comment');
};

subtest 'one comment of the repository' => sub {
    $io->reset->add(200, '{"id":7,"body":"a comment"}');
    my $comment = value(sub { $issues->get_repo_comment(7) });
    is(request(), 'GET /repos/owner/repo/issues/comments/7', 'GET /repos/{owner}/{repo}/issues/comments/{id}');
    isa_ok($comment, 'WWW::Forgejo::Entity::IssueComment');

    $io->reset->add(200, '{"id":7,"body":"corrected"}');
    my $edited = value(sub { $issues->edit_repo_comment(7, body => 'corrected') });
    is(request(), 'PATCH /repos/owner/repo/issues/comments/7', 'PATCH /repos/{owner}/{repo}/issues/comments/{id}');
    is_deeply(body(), { body => 'corrected' }, 'the new body is the body of the request');
    is(value(sub { $edited->body }), 'corrected', 'the edited comment');

    $io->reset->add(204, '');
    my $deleted = value(sub { $issues->delete_repo_comment(7) });
    is(request(), 'DELETE /repos/owner/repo/issues/comments/7', 'DELETE /repos/{owner}/{repo}/issues/comments/{id}');
    ok($deleted, 'delete_repo_comment returns true');
};

# ---------------------------------------------------------------------------
# The comments of an issue
# ---------------------------------------------------------------------------

subtest 'the comments of an issue' => sub {
    $io->reset->add(200, '{"id":8,"body":"corrected"}');
    my $comment = value(sub { $issues->edit_comment(3, 8, body => 'corrected') });
    is(request(), 'PATCH /repos/owner/repo/issues/3/comments/8', 'PATCH /repos/{owner}/{repo}/issues/{index}/comments/{id}');
    is_deeply(body(), { body => 'corrected' }, 'the new body is the body of the request');
    isa_ok($comment, 'WWW::Forgejo::Entity::IssueComment');

    $io->reset->add(204, '');
    my $deleted = value(sub { $issues->delete_comment(3, 8) });
    is(request(), 'DELETE /repos/owner/repo/issues/3/comments/8', 'DELETE /repos/{owner}/{repo}/issues/{index}/comments/{id}');
    ok($deleted, 'delete_comment returns true');
};

# ---------------------------------------------------------------------------
# The assets of a comment
# ---------------------------------------------------------------------------

subtest 'the assets of a comment' => sub {
    $io->reset->add(200, '[{"id":1,"name":"a.png"}]');
    my $assets = value(sub { $issues->list_comment_assets(7) });
    is(request(), 'GET /repos/owner/repo/issues/comments/7/assets', 'GET /repos/{owner}/{repo}/issues/comments/{id}/assets');
    is(ref $assets, 'ARRAY', 'list_comment_assets returns an arrayref') or return;
    is($assets->[0]{name}, 'a.png', 'the name of the asset');

    $io->reset->add(200, '{"id":1,"name":"a.png"}');
    value(sub { $issues->get_comment_asset(7, 1) });
    is(request(), 'GET /repos/owner/repo/issues/comments/7/assets/1', 'GET /repos/{owner}/{repo}/issues/comments/{id}/assets/{attachment_id}');

    # The API takes the file of an asset as multipart/form-data and its name as
    # query parameter.
    $io->reset->add(201, '{"id":2}');
    value(sub { $issues->create_comment_asset(7, name => 'a.png', content => 'data', filename => 'a.png') });
    is(request(), 'POST /repos/owner/repo/issues/comments/7/assets?name=a.png',
        'POST /repos/{owner}/{repo}/issues/comments/{id}/assets');
    like($io->last->headers->{'Content-Type'}, qr{^multipart/form-data}, 'the file is sent as multipart');
    like($io->last->content, qr{name="attachment"; filename="a\.png"}, 'the file is the attachment of the request');

    $io->reset->add(200, '{"id":1,"name":"b.png"}');
    value(sub { $issues->edit_comment_asset(7, 1, name => 'b.png') });
    is(request(), 'PATCH /repos/owner/repo/issues/comments/7/assets/1', 'PATCH /repos/{owner}/{repo}/issues/comments/{id}/assets/{attachment_id}');
    is_deeply(body(), { name => 'b.png' }, 'the new name is the body of the request');

    $io->reset->add(204, '');
    my $deleted = value(sub { $issues->delete_comment_asset(7, 1) });
    is(request(), 'DELETE /repos/owner/repo/issues/comments/7/assets/1', 'DELETE /repos/{owner}/{repo}/issues/comments/{id}/assets/{attachment_id}');
    ok($deleted, 'delete_comment_asset returns true');
};

# ---------------------------------------------------------------------------
# The reactions of a comment
# ---------------------------------------------------------------------------

subtest 'the reactions of a comment' => sub {
    $io->reset->add(200, '[{"content":"eyes"}]');
    my $reactions = value(sub { $issues->list_comment_reactions(7) });
    is(request(), 'GET /repos/owner/repo/issues/comments/7/reactions', 'GET /repos/{owner}/{repo}/issues/comments/{id}/reactions');
    is(ref $reactions, 'ARRAY', 'list_comment_reactions returns an arrayref') or return;
    is($reactions->[0]{content}, 'eyes', 'the content of the reaction');

    $io->reset->add(201, '{"content":"eyes"}');
    value(sub { $issues->create_comment_reaction(7, content => 'eyes') });
    is(request(), 'POST /repos/owner/repo/issues/comments/7/reactions', 'POST /repos/{owner}/{repo}/issues/comments/{id}/reactions');
    is_deeply(body(), { content => 'eyes' }, 'the content is the body of the request');

    $io->reset->add(204, '');
    my $deleted = value(sub { $issues->delete_comment_reaction(7) });
    is(request(), 'DELETE /repos/owner/repo/issues/comments/7/reactions', 'DELETE /repos/{owner}/{repo}/issues/comments/{id}/reactions');
    ok($deleted, 'delete_comment_reaction returns true');
};

# ---------------------------------------------------------------------------
# The assets of an issue
# ---------------------------------------------------------------------------

subtest 'the assets of an issue' => sub {
    $io->reset->add(200, '[{"id":1,"name":"a.png"}]');
    my $assets = value(sub { $issues->list_assets(3) });
    is(request(), 'GET /repos/owner/repo/issues/3/assets', 'GET /repos/{owner}/{repo}/issues/{index}/assets');
    is(ref $assets, 'ARRAY', 'list_assets returns an arrayref') or return;

    $io->reset->add(200, '{"id":1}');
    value(sub { $issues->get_asset(3, 1) });
    is(request(), 'GET /repos/owner/repo/issues/3/assets/1', 'GET /repos/{owner}/{repo}/issues/{index}/assets/{attachment_id}');

    # The API takes the file of an asset as multipart/form-data and its name as
    # query parameter.
    $io->reset->add(201, '{"id":2}');
    value(sub { $issues->create_asset(3, name => 'a.png', content => 'data', filename => 'a.png') });
    is(request(), 'POST /repos/owner/repo/issues/3/assets?name=a.png',
        'POST /repos/{owner}/{repo}/issues/{index}/assets');
    like($io->last->headers->{'Content-Type'}, qr{^multipart/form-data}, 'the file is sent as multipart');
    like($io->last->content, qr{name="attachment"; filename="a\.png"}, 'the file is the attachment of the request');

    $io->reset->add(200, '{"id":1}');
    value(sub { $issues->edit_asset(3, 1, name => 'b.png') });
    is(request(), 'PATCH /repos/owner/repo/issues/3/assets/1', 'PATCH /repos/{owner}/{repo}/issues/{index}/assets/{attachment_id}');

    $io->reset->add(204, '');
    my $deleted = value(sub { $issues->delete_asset(3, 1) });
    is(request(), 'DELETE /repos/owner/repo/issues/3/assets/1', 'DELETE /repos/{owner}/{repo}/issues/{index}/assets/{attachment_id}');
    ok($deleted, 'delete_asset returns true');
};

# ---------------------------------------------------------------------------
# The reactions of an issue
# ---------------------------------------------------------------------------

subtest 'the reactions of an issue' => sub {
    $io->reset->add(200, '[{"content":"eyes"}]');
    my $reactions = value(sub { $issues->list_reactions(3) });
    is(request(), 'GET /repos/owner/repo/issues/3/reactions', 'GET /repos/{owner}/{repo}/issues/{index}/reactions');
    is(ref $reactions, 'ARRAY', 'list_reactions returns an arrayref') or return;

    $io->reset->add(201, '{"content":"eyes"}');
    value(sub { $issues->create_reaction(3, content => 'eyes') });
    is(request(), 'POST /repos/owner/repo/issues/3/reactions', 'POST /repos/{owner}/{repo}/issues/{index}/reactions');
    is_deeply(body(), { content => 'eyes' }, 'the content is the body of the request');

    $io->reset->add(204, '');
    my $deleted = value(sub { $issues->delete_reaction(3) });
    is(request(), 'DELETE /repos/owner/repo/issues/3/reactions', 'DELETE /repos/{owner}/{repo}/issues/{index}/reactions');
    ok($deleted, 'delete_reaction returns true');
};

# ---------------------------------------------------------------------------
# The blocks and the dependencies of an issue
# ---------------------------------------------------------------------------

subtest 'the blocks of an issue' => sub {
    $io->reset->add(200, '[{"id":9}]');
    my $blocks = value(sub { $issues->list_blocks(3) });
    is(request(), 'GET /repos/owner/repo/issues/3/blocks', 'GET /repos/{owner}/{repo}/issues/{index}/blocks');
    is(ref $blocks, 'ARRAY', 'list_blocks returns an arrayref') or return;

    $io->reset->add(201, '{"id":9}');
    value(sub { $issues->create_block(3, issue_id => 9) });
    is(request(), 'POST /repos/owner/repo/issues/3/blocks', 'POST /repos/{owner}/{repo}/issues/{index}/blocks');
    is_deeply(body(), { issue_id => 9 }, 'the issue is the body of the request');

    $io->reset->add(204, '');
    my $deleted = value(sub { $issues->delete_block(3) });
    is(request(), 'DELETE /repos/owner/repo/issues/3/blocks', 'DELETE /repos/{owner}/{repo}/issues/{index}/blocks');
    ok($deleted, 'delete_block returns true');
};

subtest 'the dependencies of an issue' => sub {
    $io->reset->add(200, '[{"id":9}]');
    my $dependencies = value(sub { $issues->list_dependencies(3) });
    is(request(), 'GET /repos/owner/repo/issues/3/dependencies', 'GET /repos/{owner}/{repo}/issues/{index}/dependencies');
    is(ref $dependencies, 'ARRAY', 'list_dependencies returns an arrayref') or return;

    $io->reset->add(201, '{"id":9}');
    value(sub { $issues->create_dependency(3, issue_id => 9) });
    is(request(), 'POST /repos/owner/repo/issues/3/dependencies', 'POST /repos/{owner}/{repo}/issues/{index}/dependencies');
    is_deeply(body(), { issue_id => 9 }, 'the issue is the body of the request');

    $io->reset->add(204, '');
    my $deleted = value(sub { $issues->delete_dependency(3) });
    is(request(), 'DELETE /repos/owner/repo/issues/3/dependencies', 'DELETE /repos/{owner}/{repo}/issues/{index}/dependencies');
    ok($deleted, 'delete_dependency returns true');
};

# ---------------------------------------------------------------------------
# The deadline of an issue
# ---------------------------------------------------------------------------

subtest 'the deadline of an issue' => sub {
    $io->reset->add(200, '{"number":3}');
    value(sub { $issues->set_deadline(3, deadline => '2026-12-31T23:59:00Z') });
    is(request(), 'POST /repos/owner/repo/issues/3/deadline', 'POST /repos/{owner}/{repo}/issues/{index}/deadline');
    is_deeply(body(), { deadline => '2026-12-31T23:59:00Z' }, 'the deadline is the body of the request');
};

# ---------------------------------------------------------------------------
# The labels of an issue
# ---------------------------------------------------------------------------

subtest 'the labels of an issue' => sub {
    $io->reset->add(200, '[{"id":4,"name":"bug"}]');
    my $labels = value(sub { $issues->set_labels(3, labels => [4]) });
    is(request(), 'PUT /repos/owner/repo/issues/3/labels', 'PUT /repos/{owner}/{repo}/issues/{index}/labels');
    is_deeply(body(), { labels => [4] }, 'the labels are the body of the request');
    is(ref $labels, 'ARRAY', 'set_labels returns the labels of the issue');

    $io->reset->add(204, '');
    my $removed = value(sub { $issues->remove_all_labels(3) });
    is(request(), 'DELETE /repos/owner/repo/issues/3/labels', 'DELETE /repos/{owner}/{repo}/issues/{index}/labels');
    ok($removed, 'remove_all_labels returns true');
};

# ---------------------------------------------------------------------------
# The pin of an issue
# ---------------------------------------------------------------------------

subtest 'the pin of an issue' => sub {
    $io->reset->add(204, '');
    my $pinned = value(sub { $issues->pin(3) });
    is(request(), 'POST /repos/owner/repo/issues/3/pin', 'POST /repos/{owner}/{repo}/issues/{index}/pin');
    ok($pinned, 'pin returns true');

    $io->reset->add(204, '');
    my $unpinned = value(sub { $issues->unpin(3) });
    is(request(), 'DELETE /repos/owner/repo/issues/3/pin', 'DELETE /repos/{owner}/{repo}/issues/{index}/pin');
    ok($unpinned, 'unpin returns true');

    $io->reset->add(204, '');
    my $moved = value(sub { $issues->update_pin(3, 2) });
    is(request(), 'PATCH /repos/owner/repo/issues/3/pin/2', 'PATCH /repos/{owner}/{repo}/issues/{index}/pin/{position}');
    ok($moved, 'update_pin returns true');
};

# ---------------------------------------------------------------------------
# The stopwatch of an issue
# ---------------------------------------------------------------------------

subtest 'the stopwatch of an issue' => sub {
    $io->reset->add(204, '');
    my $started = value(sub { $issues->start_stopwatch(3) });
    is(request(), 'POST /repos/owner/repo/issues/3/stopwatch/start', 'POST /repos/{owner}/{repo}/issues/{index}/stopwatch/start');
    ok($started, 'start_stopwatch returns true');

    $io->reset->add(204, '');
    my $stopped = value(sub { $issues->stop_stopwatch(3) });
    is(request(), 'POST /repos/owner/repo/issues/3/stopwatch/stop', 'POST /repos/{owner}/{repo}/issues/{index}/stopwatch/stop');
    ok($stopped, 'stop_stopwatch returns true');

    $io->reset->add(204, '');
    my $deleted = value(sub { $issues->delete_stopwatch(3) });
    is(request(), 'DELETE /repos/owner/repo/issues/3/stopwatch/delete', 'DELETE /repos/{owner}/{repo}/issues/{index}/stopwatch/delete');
    ok($deleted, 'delete_stopwatch returns true');
};

# ---------------------------------------------------------------------------
# The subscriptions of an issue
# ---------------------------------------------------------------------------

subtest 'the subscriptions of an issue' => sub {
    $io->reset->add(200, '[{"login":"other"}]');
    my $subscribers = value(sub { $issues->list_subscribers(3) });
    is(request(), 'GET /repos/owner/repo/issues/3/subscriptions', 'GET /repos/{owner}/{repo}/issues/{index}/subscriptions');
    is(ref $subscribers, 'ARRAY', 'list_subscribers returns an arrayref') or return;

    $io->reset->add(404, '{"message":"not watching"}');
    my $watching = value(sub { $issues->check_subscription(3) });
    is(request(), 'GET /repos/owner/repo/issues/3/subscriptions/check', 'GET /repos/{owner}/{repo}/issues/{index}/subscriptions/check');
    ok(!$watching, 'not watching');

    $io->reset->add(204, '');
    my $subscribed = value(sub { $issues->subscribe(3, 'other') });
    is(request(), 'PUT /repos/owner/repo/issues/3/subscriptions/other', 'PUT /repos/{owner}/{repo}/issues/{index}/subscriptions/{user}');
    ok($subscribed, 'subscribe returns true');

    $io->reset->add(204, '');
    my $unsubscribed = value(sub { $issues->unsubscribe(3, 'other') });
    is(request(), 'DELETE /repos/owner/repo/issues/3/subscriptions/other', 'DELETE /repos/{owner}/{repo}/issues/{index}/subscriptions/{user}');
    ok($unsubscribed, 'unsubscribe returns true');
};

# ---------------------------------------------------------------------------
# The timeline of an issue
# ---------------------------------------------------------------------------

subtest 'the timeline of an issue' => sub {
    $io->reset->add(200, '[{"id":1}]');
    my $timeline = value(sub { $issues->timeline(3) });
    is(request(), 'GET /repos/owner/repo/issues/3/timeline', 'GET /repos/{owner}/{repo}/issues/{index}/timeline');
    is(ref $timeline, 'ARRAY', 'the timeline is the decoded response');
};

# ---------------------------------------------------------------------------
# The tracked times of an issue
# ---------------------------------------------------------------------------

subtest 'the tracked times of an issue' => sub {
    $io->reset->add(200, '[{"id":5,"time":3600}]');
    my $times = value(sub { $issues->list_times(3) });
    is(request(), 'GET /repos/owner/repo/issues/3/times', 'GET /repos/{owner}/{repo}/issues/{index}/times');
    is(ref $times, 'ARRAY', 'list_times returns an arrayref') or return;

    $io->reset->add(200, '{"id":5}');
    value(sub { $issues->add_time(3, time => 3600) });
    is(request(), 'POST /repos/owner/repo/issues/3/times', 'POST /repos/{owner}/{repo}/issues/{index}/times');
    is_deeply(body(), { time => 3600 }, 'the time is the body of the request');

    $io->reset->add(204, '');
    my $deleted = value(sub { $issues->delete_times(3) });
    is(request(), 'DELETE /repos/owner/repo/issues/3/times', 'DELETE /repos/{owner}/{repo}/issues/{index}/times');
    ok($deleted, 'delete_times returns true');

    $io->reset->add(204, '');
    my $one = value(sub { $issues->delete_time(3, 5) });
    is(request(), 'DELETE /repos/owner/repo/issues/3/times/5', 'DELETE /repos/{owner}/{repo}/issues/{index}/times/{id}');
    ok($one, 'delete_time returns true');
};

# ---------------------------------------------------------------------------
# The issue search across all repositories
# ---------------------------------------------------------------------------

subtest 'the issue search across all repositories' => sub {
    $io->reset->add(200, '{"ok":true,"data":[{"number":1}]}');
    value(sub { $client->repos->search_issues(q => 'forgejo') });
    is(request(), 'GET /repos/issues/search?q=forgejo', 'GET /repos/issues/search');

    $io->reset->add(200, '{"ok":true,"data":[]}');
    value(sub { $client->repos->search_issues('forgejo') });
    is(request(), 'GET /repos/issues/search?q=forgejo', 'a single argument is the search term');
};

# ---------------------------------------------------------------------------
# The names of the paths are escaped
# ---------------------------------------------------------------------------

subtest 'the names of the paths are escaped' => sub {
    $io->reset->add(200, '{}');
    value(sub { $issues->get_repo_comment('a b/c') });
    is(request(), 'GET /repos/owner/repo/issues/comments/a%20b%2Fc', 'the parts of the path are escaped');
};

done_testing;
