#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);
use WWW::Forgejo::API::Repo::PullRequests;

# The pull request endpoints the client did not cover yet: the pinned pull
# requests, the comparison of two branches, the diff and the patch, the commits
# and the files of a pull request, the single review with its comments, the
# dismissal of a review and the update of the branch.
#
# Every call is made in an eval, so a method that does not exist shows up as a
# failed test instead of a dead file.

my ($client, $io) = mock_client();
my $base = 'https://forgejo.test/api/v1';

my $pulls = WWW::Forgejo::API::Repo::PullRequests->new(
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
# The pinned pull requests
# ---------------------------------------------------------------------------

subtest 'the pinned pull requests of the repository' => sub {
    $io->reset->add(200, '[{"number":1,"title":"Pinned"}]');
    my $pinned = value(sub { $pulls->list_pinned });
    is(request(), 'GET /repos/owner/repo/pulls/pinned', 'GET /repos/{owner}/{repo}/pulls/pinned');
    is(ref $pinned, 'ARRAY', 'list_pinned returns an arrayref') or return;
    isa_ok($pinned->[0], 'WWW::Forgejo::Entity::PullRequest');
    is(value(sub { $pinned->[0]->title }), 'Pinned', 'the title of the pinned pull request');
};

# ---------------------------------------------------------------------------
# The comparison of two branches
# ---------------------------------------------------------------------------

subtest 'the comparison of two branches' => sub {
    $io->reset->add(200, '{"commits":[],"files":[]}');
    my $comparison = value(sub { $pulls->compare('main', 'feature') });
    is(request(), 'GET /repos/owner/repo/pulls/main/feature',
        'GET /repos/{owner}/{repo}/pulls/{base}/{head}');
    is(ref $comparison, 'HASH', 'compare returns the plain comparison structure');
};

# ---------------------------------------------------------------------------
# The diff and the patch of a pull request
# ---------------------------------------------------------------------------

subtest 'the diff and the patch of a pull request' => sub {
    $io->reset->add(200, 'diff --git a/lib/Foo.pm b/lib/Foo.pm');
    my $diff = value(sub { $pulls->diff(3, 'diff') });
    is(request(), 'GET /repos/owner/repo/pulls/3.diff',
        'GET /repos/{owner}/{repo}/pulls/{index}.{diffType}');
    is($diff, 'diff --git a/lib/Foo.pm b/lib/Foo.pm', 'the diff is the body of the response');

    $io->reset->add(200, 'From 0000 Mon Sep 17 00:00:00 2001');
    my $patch = value(sub { $pulls->diff(3, 'patch') });
    is(request(), 'GET /repos/owner/repo/pulls/3.patch', 'the patch of the same pull request');
    like($patch, qr/^From 0000/, 'the patch is the body of the response');
};

# ---------------------------------------------------------------------------
# The commits and the files of a pull request
# ---------------------------------------------------------------------------

subtest 'the commits of a pull request' => sub {
    $io->reset->add(200, '[{"sha":"abc123"}]');
    my $commits = value(sub { $pulls->list_commits(3) });
    is(request(), 'GET /repos/owner/repo/pulls/3/commits',
        'GET /repos/{owner}/{repo}/pulls/{index}/commits');
    is(ref $commits, 'ARRAY', 'list_commits returns an arrayref') or return;
    is($commits->[0]{sha}, 'abc123', 'the commit');
};

subtest 'the files of a pull request' => sub {
    $io->reset->add(200, '[{"filename":"lib/Foo.pm"}]');
    my $files = value(sub { $pulls->list_files(3) });
    is(request(), 'GET /repos/owner/repo/pulls/3/files',
        'GET /repos/{owner}/{repo}/pulls/{index}/files');
    is(ref $files, 'ARRAY', 'list_files returns an arrayref') or return;
    is($files->[0]{filename}, 'lib/Foo.pm', 'the file');
};

# ---------------------------------------------------------------------------
# The merge of a pull request
# ---------------------------------------------------------------------------

subtest 'the merge of a pull request can be taken back' => sub {
    $io->reset->add(204, '');
    my $unmerged = value(sub { $pulls->unmerge(3) });
    is(request(), 'DELETE /repos/owner/repo/pulls/3/merge',
        'DELETE /repos/{owner}/{repo}/pulls/{index}/merge');
    ok($unmerged, 'unmerge returns true');
};

# ---------------------------------------------------------------------------
# One review of a pull request
# ---------------------------------------------------------------------------

subtest 'one review of a pull request' => sub {
    $io->reset->add(200, '{"id":9,"state":"APPROVED"}');
    my $review = value(sub { $pulls->get_review(3, 9) });
    is(request(), 'GET /repos/owner/repo/pulls/3/reviews/9',
        'GET /repos/{owner}/{repo}/pulls/{index}/reviews/{id}');
    isa_ok($review, 'WWW::Forgejo::Entity::PullRequestReview');
    is(value(sub { $review->state }), 'APPROVED', 'the state of the review');

    $io->reset->add(200, '{"id":9,"state":"APPROVED"}');
    my $submitted = value(sub { $pulls->submit_review(3, 9, event => 'APPROVED') });
    is(request(), 'POST /repos/owner/repo/pulls/3/reviews/9',
        'POST /repos/{owner}/{repo}/pulls/{index}/reviews/{id}');
    is_deeply(body(), { event => 'APPROVED' }, 'the event is the body of the request');
    isa_ok($submitted, 'WWW::Forgejo::Entity::PullRequestReview');

    $io->reset->add(204, '');
    my $deleted = value(sub { $pulls->delete_review(3, 9) });
    is(request(), 'DELETE /repos/owner/repo/pulls/3/reviews/9',
        'DELETE /repos/{owner}/{repo}/pulls/{index}/reviews/{id}');
    ok($deleted, 'delete_review returns true');
};

# ---------------------------------------------------------------------------
# The comments of a review
# ---------------------------------------------------------------------------

subtest 'the comments of a review' => sub {
    $io->reset->add(200, '[{"id":4,"body":"Please fix this"}]');
    my $comments = value(sub { $pulls->list_review_comments(3, 9) });
    is(request(), 'GET /repos/owner/repo/pulls/3/reviews/9/comments',
        'GET /repos/{owner}/{repo}/pulls/{index}/reviews/{id}/comments');
    is(ref $comments, 'ARRAY', 'list_review_comments returns an arrayref') or return;
    is($comments->[0]{body}, 'Please fix this', 'the comment');

    $io->reset->add(201, '{"id":5,"body":"Please fix this"}');
    value(sub { $pulls->create_review_comment(3, 9, body => 'Please fix this', path => 'lib/Foo.pm') });
    is(request(), 'POST /repos/owner/repo/pulls/3/reviews/9/comments',
        'POST /repos/{owner}/{repo}/pulls/{index}/reviews/{id}/comments');
    is_deeply(body(), { body => 'Please fix this', path => 'lib/Foo.pm' },
        'the comment is the body of the request');

    $io->reset->add(200, '{"id":5,"body":"Please fix this"}');
    value(sub { $pulls->get_review_comment(3, 9, 5) });
    is(request(), 'GET /repos/owner/repo/pulls/3/reviews/9/comments/5',
        'GET /repos/{owner}/{repo}/pulls/{index}/reviews/{id}/comments/{comment}');

    $io->reset->add(204, '');
    my $deleted = value(sub { $pulls->delete_review_comment(3, 9, 5) });
    is(request(), 'DELETE /repos/owner/repo/pulls/3/reviews/9/comments/5',
        'DELETE /repos/{owner}/{repo}/pulls/{index}/reviews/{id}/comments/{comment}');
    ok($deleted, 'delete_review_comment returns true');
};

# ---------------------------------------------------------------------------
# The dismissal of a review
# ---------------------------------------------------------------------------

subtest 'the dismissal of a review' => sub {
    $io->reset->add(200, '{"id":9,"state":"DISMISSED"}');
    my $dismissed = value(sub { $pulls->dismiss_review(3, 9, message => 'Outdated') });
    is(request(), 'POST /repos/owner/repo/pulls/3/reviews/9/dismissals',
        'POST /repos/{owner}/{repo}/pulls/{index}/reviews/{id}/dismissals');
    is_deeply(body(), { message => 'Outdated' }, 'the message is the body of the request');
    isa_ok($dismissed, 'WWW::Forgejo::Entity::PullRequestReview');

    $io->reset->add(200, '{"id":9,"state":"APPROVED"}');
    my $undismissed = value(sub { $pulls->undismiss_review(3, 9) });
    is(request(), 'POST /repos/owner/repo/pulls/3/reviews/9/undismissals',
        'POST /repos/{owner}/{repo}/pulls/{index}/reviews/{id}/undismissals');
    isa_ok($undismissed, 'WWW::Forgejo::Entity::PullRequestReview');
};

# ---------------------------------------------------------------------------
# The update of the branch of a pull request
# ---------------------------------------------------------------------------

subtest 'the update of the branch of a pull request' => sub {
    $io->reset->add(200, '{"number":3}');
    my $pr = value(sub { $pulls->update_branch(3, style => 'rebase') });
    is(request(), 'POST /repos/owner/repo/pulls/3/update',
        'POST /repos/{owner}/{repo}/pulls/{index}/update');
    is_deeply(body(), { style => 'rebase' }, 'the style is the body of the request');
    isa_ok($pr, 'WWW::Forgejo::Entity::PullRequest');
};

# ---------------------------------------------------------------------------
# The names of the paths are escaped
# ---------------------------------------------------------------------------

subtest 'the names of the paths are escaped' => sub {
    $io->reset->add(200, '{}');
    value(sub { $pulls->get_review(3, 'a b') });
    is(request(), 'GET /repos/owner/repo/pulls/3/reviews/a%20b',
        'the parts of the path are escaped');
};

done_testing;
