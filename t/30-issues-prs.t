use strict;
use warnings;
use Test::More;
use lib 'lib';
use HTTP::Response;
use WWW::Forgejo;
use WWW::Forgejo::HTTPResponse;
use WWW::Forgejo::Role::IO;
use WWW::Forgejo::API::Repo::PullRequests;
use WWW::Forgejo::API::Repo::Issues;
use WWW::Forgejo::Entity::PullRequest;
use WWW::Forgejo::Entity::PullRequestReview;
use WWW::Forgejo::Entity::Issue;
use WWW::Forgejo::Entity::IssueComment;

# ---------------------------------------------------------------------------
# In-memory mock IO backend (mirrors t/02-http-mock.t). Records the built
# HTTPRequest objects and hands back queued responses so we can assert on the
# HTTP method, URL path and JSON body the controllers actually produced.
# ---------------------------------------------------------------------------
{
    package Test::MockIO;
    use Moo;
    with 'WWW::Forgejo::Role::IO';

    our @responses;
    our @requests;

    sub call {
        my ($self, $req) = @_;
        push @requests, $req;
        my $res = shift @responses // HTTP::Response->new(500, 'No mock response');
        return WWW::Forgejo::HTTPResponse->new(
            status  => $res->code,
            content => $res->decoded_content // '',
            headers => { $res->headers->flatten },
        );
    }
}

my $mock_io = Test::MockIO->new;
# strong ref kept for the life of the test so entities' weak client stays live
my $client = WWW::Forgejo->new(
    url   => 'https://test.example',
    token => 'test-token',
    io    => $mock_io,
);

sub add_response {
    my ($code, $content, %headers) = @_;
    push @Test::MockIO::responses, HTTP::Response->new(
        $code, 'OK', ['Content-Type' => 'application/json', %headers],
        $content
    );
}

sub clear_responses {
    @Test::MockIO::responses = ();
    @Test::MockIO::requests  = ();
}

sub last_req { $Test::MockIO::requests[-1] }

# Controllers built directly - avoids a repos->get round-trip per test and
# targets the PullRequests / Issues code paths exactly.
my $pulls = WWW::Forgejo::API::Repo::PullRequests->new(
    client => $client, owner => 'testorg', repo => 'test-repo',
);
my $issues = WWW::Forgejo::API::Repo::Issues->new(
    client => $client, owner => 'testorg', repo => 'test-repo',
);

# ===========================================================================
# Pull Requests - the coverage gap (t/02 has zero PR coverage)
# ===========================================================================

subtest 'pulls list' => sub {
    clear_responses;
    add_response(200,
        '[{"id":10,"number":1,"title":"First PR","state":"open"},'
      . '{"id":11,"number":2,"title":"Second PR","state":"closed"}]');

    my @prs = $pulls->list;
    is(scalar @prs, 2, 'two pull requests returned as a list');
    is(scalar @Test::MockIO::requests, 1, 'single-page list => one HTTP call');
    isa_ok($prs[0], 'WWW::Forgejo::Entity::PullRequest');
    is($prs[0]->number, 1, 'first PR number');
    is($prs[0]->title, 'First PR', 'first PR title');
    is($prs[1]->state, 'closed', 'second PR state');

    my $req = last_req;
    is($req->method, 'GET', 'list => GET');
    like($req->url, qr{/repos/testorg/test-repo/pulls}, 'list path');
};

subtest 'pulls list forwards filter params to the query string' => sub {
    clear_responses;
    add_response(200, '[{"id":10,"number":1,"title":"First PR","state":"open"}]');

    my @prs = $pulls->list(state => 'open');
    is(scalar @prs, 1, 'one PR returned');

    my $req = last_req;
    is($req->method, 'GET', 'filtered list => GET');
    like($req->url, qr{[?&]state=open(?:&|$)}, 'state filter reaches the query string');
};

subtest 'pulls get + entity accessors' => sub {
    clear_responses;
    add_response(200,
        '{"id":10,"number":5,"title":"Fix bug","body":"the description",'
      . '"state":"open","merged":false,"merged_at":null,'
      . '"head":{"ref":"feature"},"base":{"ref":"main"},'
      . '"user":{"login":"dev"},"comments":3,"commits":2,'
      . '"additions":10,"deletions":4,"changed_files":2}');

    my $pr = $pulls->get(5);
    isa_ok($pr, 'WWW::Forgejo::Entity::PullRequest');
    is($pr->id, 10, 'id');
    is($pr->number, 5, 'number');
    is($pr->title, 'Fix bug', 'title');
    is($pr->body, 'the description', 'body');
    is($pr->state, 'open', 'state');
    ok(!$pr->merged, 'merged is false');
    is($pr->head->{ref}, 'feature', 'head ref');
    is($pr->base->{ref}, 'main', 'base ref');
    is($pr->user->{login}, 'dev', 'user login');
    is($pr->comments, 3, 'comments count');
    is($pr->commits, 2, 'commits count');
    is($pr->additions, 10, 'additions');
    is($pr->deletions, 4, 'deletions');
    is($pr->changed_files, 2, 'changed_files');

    my $req = last_req;
    is($req->method, 'GET', 'get => GET');
    like($req->url, qr{/repos/testorg/test-repo/pulls/5$}, 'get path with index');
};

subtest 'pulls create' => sub {
    clear_responses;
    add_response(201,
        '{"id":20,"number":7,"title":"New feature","state":"open",'
      . '"head":{"ref":"feat"},"base":{"ref":"main"}}');

    my $pr = $pulls->create({
        title => 'New feature',
        head  => 'feat',
        base  => 'main',
        body  => 'please review',
    });
    isa_ok($pr, 'WWW::Forgejo::Entity::PullRequest');
    is($pr->number, 7, 'created PR number');
    is($pr->title, 'New feature', 'created PR title');

    my $req = last_req;
    is($req->method, 'POST', 'create => POST');
    like($req->url, qr{/repos/testorg/test-repo/pulls}, 'create path');
    like($req->content, qr{"title"}, 'body carries title key');
    like($req->content, qr{New feature}, 'body carries title value');
    like($req->content, qr{"base"}, 'body carries base');
};

subtest 'pulls edit' => sub {
    clear_responses;
    add_response(200, '{"id":20,"number":7,"title":"Updated title","state":"open"}');

    my $pr = $pulls->edit(7, { title => 'Updated title' });
    isa_ok($pr, 'WWW::Forgejo::Entity::PullRequest');
    is($pr->title, 'Updated title', 'edited title');

    my $req = last_req;
    is($req->method, 'PATCH', 'edit => PATCH');
    like($req->url, qr{/repos/testorg/test-repo/pulls/7$}, 'edit path with index');
    like($req->content, qr{Updated title}, 'body carries new title');
};

subtest 'pulls update (alias of edit)' => sub {
    clear_responses;
    add_response(200, '{"id":20,"number":7,"title":"Via update","state":"open"}');

    my $pr = $pulls->update(7, { title => 'Via update' });
    is($pr->title, 'Via update', 'update aliases edit');

    my $req = last_req;
    is($req->method, 'PATCH', 'update => PATCH');
    like($req->url, qr{/repos/testorg/test-repo/pulls/7$}, 'update path');
};

subtest 'pulls merge' => sub {
    clear_responses;
    add_response(200, '{}');

    my $r = $pulls->merge(7, { Do => 'merge' });
    is(ref $r, 'HASH', 'merge returns raw decoded data');

    my $req = last_req;
    is($req->method, 'POST', 'merge => POST');
    like($req->url, qr{/repos/testorg/test-repo/pulls/7/merge$}, 'merge path');
    like($req->content, qr{merge}, 'merge body forwarded');
};

subtest 'pulls is_merged' => sub {
    clear_responses;
    add_response(204, '');

    $pulls->is_merged(7);
    my $req = last_req;
    is($req->method, 'GET', 'is_merged => GET');
    like($req->url, qr{/repos/testorg/test-repo/pulls/7/merged$}, 'merged path');
};

subtest 'pulls delete' => sub {
    clear_responses;
    add_response(204, '');

    my $ok = $pulls->delete(7);
    is($ok, 1, 'delete returns 1');

    my $req = last_req;
    is($req->method, 'DELETE', 'delete => DELETE');
    like($req->url, qr{/repos/testorg/test-repo/pulls/7$}, 'delete path');
};

subtest 'pulls reviews => Entity::PullRequestReview' => sub {
    clear_responses;
    add_response(200,
        '[{"id":100,"body":"Looks good","state":"APPROVED",'
      . '"user":{"login":"reviewer"},"submitted_at":"2024-01-01T00:00:00Z"}]');

    my @reviews = $pulls->reviews(7);
    is(scalar @reviews, 1, 'one review');
    isa_ok($reviews[0], 'WWW::Forgejo::Entity::PullRequestReview');
    is($reviews[0]->id, 100, 'review id');
    is($reviews[0]->body, 'Looks good', 'review body');
    is($reviews[0]->state, 'APPROVED', 'review state');
    is($reviews[0]->user->{login}, 'reviewer', 'review user');
    is($reviews[0]->submitted_at, '2024-01-01T00:00:00Z', 'submitted_at');

    my $req = last_req;
    is($req->method, 'GET', 'reviews => GET');
    like($req->url, qr{/repos/testorg/test-repo/pulls/7/reviews$}, 'reviews path');
};

subtest 'pulls create_review' => sub {
    clear_responses;
    add_response(200, '{"id":101,"body":"nice","state":"COMMENT"}');

    my $r = $pulls->create_review(7, { body => 'nice', event => 'COMMENT' });
    is($r->{id}, 101, 'create_review returns raw data');
    is($r->{state}, 'COMMENT', 'review state in raw data');

    my $req = last_req;
    is($req->method, 'POST', 'create_review => POST');
    like($req->url, qr{/repos/testorg/test-repo/pulls/7/reviews$}, 'create_review path');
    like($req->content, qr{nice}, 'body forwarded');
};

subtest 'pulls comments => Entity::IssueComment' => sub {
    clear_responses;
    add_response(200,
        '[{"id":200,"body":"a PR comment","user":{"login":"u"},'
      . '"created_at":"2024-01-02T00:00:00Z"}]');

    my @comments = $pulls->comments(7);
    is(scalar @comments, 1, 'one comment');
    isa_ok($comments[0], 'WWW::Forgejo::Entity::IssueComment');
    is($comments[0]->id, 200, 'comment id');
    is($comments[0]->body, 'a PR comment', 'comment body');
    is($comments[0]->user->{login}, 'u', 'comment user');

    my $req = last_req;
    is($req->method, 'GET', 'comments => GET');
    like($req->url, qr{/repos/testorg/test-repo/pulls/7/comments$}, 'comments path');
};

subtest 'Entity::PullRequest round-trip (direct construction)' => sub {
    my $pr = WWW::Forgejo::Entity::PullRequest->new(
        client => $client,
        owner  => 'o',
        repo   => 'r',
        data   => {
            id => 42, number => 3, title => 'Direct PR', body => 'b',
            state => 'open', merged => 1, html_url => 'https://x/pulls/3',
            head => { ref => 'h' }, base => { ref => 'b' },
        },
    );
    is($pr->client, $client, 'weak client ref stays populated (strong ref held)');
    is($pr->id, 42, 'id');
    is($pr->number, 3, 'number');
    is($pr->title, 'Direct PR', 'title');
    is($pr->state, 'open', 'state');
    ok($pr->merged, 'merged true');
    is($pr->html_url, 'https://x/pulls/3', 'html_url');
    like($pr->data_json, qr{Direct PR}, 'data_json serializes data');
};

subtest 'Entity::PullRequestReview round-trip (direct construction)' => sub {
    my $rev = WWW::Forgejo::Entity::PullRequestReview->new(
        client => $client,
        owner  => 'o',
        repo   => 'r',
        data   => {
            id => 7, body => 'reviewed', state => 'REQUEST_CHANGES',
            user => { login => 'r1' }, submitted_at => '2024-05-05T00:00:00Z',
        },
    );
    is($rev->id, 7, 'id');
    is($rev->body, 'reviewed', 'body');
    is($rev->state, 'REQUEST_CHANGES', 'state');
    is($rev->user->{login}, 'r1', 'user');
    is($rev->submitted_at, '2024-05-05T00:00:00Z', 'submitted_at');
    like($rev->data_json, qr{REQUEST_CHANGES}, 'data_json');
};

# ===========================================================================
# Issues - beyond t/02's single list smoke
# ===========================================================================

subtest 'issues list' => sub {
    clear_responses;
    add_response(200,
        '[{"id":1,"number":1,"title":"Bug report","state":"open",'
      . '"labels":[{"id":1,"name":"bug"}]},'
      . '{"id":2,"number":2,"title":"Feature","state":"closed","labels":[]}]');

    my @list = $issues->list;
    is(scalar @list, 2, 'two issues');
    is(scalar @Test::MockIO::requests, 1, 'single-page list => one HTTP call');
    isa_ok($list[0], 'WWW::Forgejo::Entity::Issue');
    is($list[0]->number, 1, 'first issue number');
    is($list[0]->title, 'Bug report', 'first issue title');
    is($list[0]->labels->[0]{name}, 'bug', 'first issue label');
    is($list[1]->state, 'closed', 'second issue state');

    my $req = last_req;
    is($req->method, 'GET', 'list => GET');
    like($req->url, qr{/repos/testorg/test-repo/issues}, 'list path');
};

subtest 'issues list forwards filter params to the query string' => sub {
    clear_responses;
    add_response(200, '[{"id":1,"number":1,"title":"Bug","state":"open","labels":[]}]');

    my @list = $issues->list(state => 'open');
    is(scalar @list, 1, 'one issue returned');

    my $req = last_req;
    is($req->method, 'GET', 'filtered list => GET');
    like($req->url, qr{[?&]state=open(?:&|$)}, 'state filter reaches the query string');
};

subtest 'issues get + entity accessors' => sub {
    clear_responses;
    add_response(200,
        '{"id":50,"number":3,"title":"Broken","body":"it is broken",'
      . '"state":"open","labels":[{"id":9,"name":"urgent"}]}');

    my $issue = $issues->get(3);
    isa_ok($issue, 'WWW::Forgejo::Entity::Issue');
    is($issue->id, 50, 'id');
    is($issue->number, 3, 'number');
    is($issue->title, 'Broken', 'title');
    is($issue->body, 'it is broken', 'body');
    is($issue->state, 'open', 'state');
    is(ref $issue->labels, 'ARRAY', 'labels is arrayref');
    is($issue->labels->[0]{name}, 'urgent', 'label name');

    my $req = last_req;
    is($req->method, 'GET', 'get => GET');
    like($req->url, qr{/repos/testorg/test-repo/issues/3$}, 'get path with index');
};

subtest 'issues create' => sub {
    clear_responses;
    add_response(201, '{"id":51,"number":4,"title":"New issue","state":"open"}');

    my $issue = $issues->create({ title => 'New issue', body => 'text', labels => [1] });
    isa_ok($issue, 'WWW::Forgejo::Entity::Issue');
    is($issue->number, 4, 'created number');
    is($issue->title, 'New issue', 'created title');

    my $req = last_req;
    is($req->method, 'POST', 'create => POST');
    like($req->url, qr{/repos/testorg/test-repo/issues}, 'create path');
    like($req->content, qr{New issue}, 'body carries title');
};

subtest 'issues edit' => sub {
    clear_responses;
    add_response(200, '{"id":51,"number":4,"title":"Edited","state":"closed"}');

    my $issue = $issues->edit(4, { title => 'Edited', state => 'closed' });
    is($issue->title, 'Edited', 'edited title');
    is($issue->state, 'closed', 'edited state');

    my $req = last_req;
    is($req->method, 'PATCH', 'edit => PATCH');
    like($req->url, qr{/repos/testorg/test-repo/issues/4$}, 'edit path with index');
    like($req->content, qr{Edited}, 'body carries new title');
};

subtest 'issues update (alias of edit)' => sub {
    clear_responses;
    add_response(200, '{"id":51,"number":4,"title":"Upd","state":"open"}');

    my $issue = $issues->update(4, { title => 'Upd' });
    is($issue->title, 'Upd', 'update aliases edit');

    my $req = last_req;
    is($req->method, 'PATCH', 'update => PATCH');
    like($req->url, qr{/repos/testorg/test-repo/issues/4$}, 'update path');
};

subtest 'issues list_comments => Entity::IssueComment' => sub {
    clear_responses;
    add_response(200,
        '[{"id":5,"body":"first comment","user":{"login":"a"},'
      . '"created_at":"2024-01-01T00:00:00Z","updated_at":"2024-01-02T00:00:00Z"}]');

    my @comments = $issues->list_comments(4);
    is(scalar @comments, 1, 'one comment');
    isa_ok($comments[0], 'WWW::Forgejo::Entity::IssueComment');
    is($comments[0]->id, 5, 'comment id');
    is($comments[0]->body, 'first comment', 'comment body');
    is($comments[0]->user->{login}, 'a', 'comment user');
    is($comments[0]->created_at, '2024-01-01T00:00:00Z', 'created_at');
    is($comments[0]->updated_at, '2024-01-02T00:00:00Z', 'updated_at');

    my $req = last_req;
    is($req->method, 'GET', 'list_comments => GET');
    like($req->url, qr{/repos/testorg/test-repo/issues/4/comments$}, 'comments path');
};

subtest 'issues comments (alias of list_comments)' => sub {
    clear_responses;
    add_response(200, '[{"id":6,"body":"aliased"}]');

    my @comments = $issues->comments(4);
    is(scalar @comments, 1, 'alias works');
    is($comments[0]->body, 'aliased', 'alias returns comment');

    my $req = last_req;
    is($req->method, 'GET', 'comments alias => GET');
    like($req->url, qr{/repos/testorg/test-repo/issues/4/comments$}, 'comments path');
};

subtest 'issues add_comment' => sub {
    clear_responses;
    add_response(201, '{"id":6,"body":"my reply"}');

    my $r = $issues->add_comment(4, { body => 'my reply' });
    is($r->{id}, 6, 'add_comment returns raw data');
    is($r->{body}, 'my reply', 'raw body');

    my $req = last_req;
    is($req->method, 'POST', 'add_comment => POST');
    like($req->url, qr{/repos/testorg/test-repo/issues/4/comments$}, 'add_comment path');
    like($req->content, qr{my reply}, 'body forwarded');
};

subtest 'issues list_labels' => sub {
    clear_responses;
    add_response(200, '[{"id":1,"name":"bug"},{"id":2,"name":"wip"}]');

    my @labels = $issues->list_labels(4);
    is(scalar @labels, 2, 'two labels (returned as plain list)');
    is($labels[0]{name}, 'bug', 'first label');

    my $req = last_req;
    is($req->method, 'GET', 'list_labels => GET');
    like($req->url, qr{/repos/testorg/test-repo/issues/4/labels$}, 'labels path');
};

subtest 'issues add_label' => sub {
    clear_responses;
    add_response(200, '[{"id":1,"name":"bug"}]');

    my $r = $issues->add_label(4, { labels => [1] });
    ok($r, 'add_label returns data');

    my $req = last_req;
    is($req->method, 'POST', 'add_label => POST');
    like($req->url, qr{/repos/testorg/test-repo/issues/4/labels$}, 'add_label path');
};

subtest 'issues remove_label' => sub {
    clear_responses;
    add_response(204, '');

    my $ok = $issues->remove_label(4, 2);
    is($ok, 1, 'remove_label returns 1');

    my $req = last_req;
    is($req->method, 'DELETE', 'remove_label => DELETE');
    like($req->url, qr{/repos/testorg/test-repo/issues/4/labels/2$}, 'remove_label path');
};

subtest 'Entity::Issue round-trip (direct construction)' => sub {
    my $issue = WWW::Forgejo::Entity::Issue->new(
        client => $client,
        owner  => 'o',
        repo   => 'r',
        data   => {
            id => 9, number => 2, title => 'Direct issue', body => 'body',
            state => 'open', labels => [{ id => 1, name => 'bug' }],
        },
    );
    is($issue->client, $client, 'weak client ref stays populated');
    is($issue->id, 9, 'id');
    is($issue->number, 2, 'number');
    is($issue->title, 'Direct issue', 'title');
    is($issue->body, 'body', 'body');
    is($issue->state, 'open', 'state');
    is($issue->labels->[0]{name}, 'bug', 'labels');
    like($issue->data_json, qr{Direct issue}, 'data_json');
};

subtest 'Entity::IssueComment round-trip (direct construction)' => sub {
    my $c = WWW::Forgejo::Entity::IssueComment->new(
        client => $client,
        owner  => 'o',
        repo   => 'r',
        data   => {
            id => 3, body => 'hello', user => { login => 'x' },
            created_at => '2024-06-06T00:00:00Z', updated_at => '2024-06-07T00:00:00Z',
        },
    );
    is($c->id, 3, 'id');
    is($c->body, 'hello', 'body');
    is($c->user->{login}, 'x', 'user');
    is($c->created_at, '2024-06-06T00:00:00Z', 'created_at');
    is($c->updated_at, '2024-06-07T00:00:00Z', 'updated_at');
    like($c->data_json, qr{hello}, 'data_json');
};

done_testing;
