#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use WWW::Forgejo;
use WWW::Forgejo::HTTPResponse;
use WWW::Forgejo::Role::IO;

# In-memory mock IO backend: a queue of responses, recording every request.
{
    package Test::MockIO;
    use Moo;
    with 'WWW::Forgejo::Role::IO';

    our @responses;
    our @requests;

    sub call {
        my ($self, $req) = @_;
        push @requests, $req;
        my $spec = shift @responses
            // { status => 500, content => 'No mock response', headers => {} };
        return WWW::Forgejo::HTTPResponse->new(
            status  => $spec->{status},
            content => $spec->{content} // '',
            headers => $spec->{headers} // {},
        );
    }
}

my $mock_io = Test::MockIO->new;
my $client  = WWW::Forgejo->new(
    url   => 'https://test.example',
    token => 'test-token',
    io    => $mock_io,
);

# Queue a 200 JSON response; extra args become response headers.
sub queue {
    my ($content, %headers) = @_;
    push @Test::MockIO::responses, {
        status  => 200,
        content => $content,
        headers => { 'Content-Type' => 'application/json', %headers },
    };
}

sub reset_mock {
    @Test::MockIO::responses = ();
    @Test::MockIO::requests  = ();
}

# get() is the transport primitive every list controller calls, so exercising
# it directly tests the centralized auto-pagination without entity-wrapping
# noise. A truncated array + X-Total-Count is exactly what a list endpoint
# returns.

# (a) auto-collect a truncated array across pages, in order, right # of calls.
# Default (no page_size): first request sends NO limit, and pages 2+ reuse the
# first page's item count as the limit so offsets stay contiguous.
subtest 'auto-paginates a truncated array (default: server page size)' => sub {
    reset_mock();
    queue('[{"id":1},{"id":2}]', 'X-Total-Count' => 3);
    queue('[{"id":3}]',          'X-Total-Count' => 3);

    my $items = $client->get('/things');

    is(ref $items, 'ARRAY', 'array returned');
    is(scalar @$items, 3, 'all 3 items collected across pages');
    is_deeply([ map { $_->{id} } @$items ], [ 1, 2, 3 ], 'items contiguous and in order');
    is(scalar @Test::MockIO::requests, 2, 'exactly two HTTP calls');

    unlike($Test::MockIO::requests[0]->url, qr/limit=/, 'first request sends no limit (server page size)');
    like($Test::MockIO::requests[1]->url, qr/\bpage=2\b/,  'second call requests page 2');
    like($Test::MockIO::requests[1]->url, qr/\blimit=2\b/, 'second call limit = first-page item count (offset-aligned)');
};

# (b) max_pages caps the number of pages fetched
subtest 'max_pages caps the number of pages fetched' => sub {
    reset_mock();
    # Server claims 10 total; each page returns 2. Without a cap this collects
    # everything; max_pages => 2 must stop after two pages.
    queue('[{"id":1},{"id":2}]', 'X-Total-Count' => 10);
    queue('[{"id":3},{"id":4}]', 'X-Total-Count' => 10);
    queue('[{"id":5},{"id":6}]', 'X-Total-Count' => 10);

    my $items = $client->get('/things', max_pages => 2);

    is(scalar @Test::MockIO::requests, 2, 'stopped after 2 pages');
    is(scalar @$items, 4, 'only the first two pages collected');
};

# (c) explicit page_size sets limit=page_size on EVERY request (first included)
# so all pages share one size and offsets stay aligned.
subtest 'explicit page_size sets limit on the first AND subsequent requests' => sub {
    reset_mock();
    queue('[{"id":1},{"id":2}]', 'X-Total-Count' => 3);
    queue('[{"id":3}]',          'X-Total-Count' => 3);

    my $items = $client->get('/things', page_size => 25);

    is(scalar @$items, 3, 'all items collected');
    is(scalar @Test::MockIO::requests, 2, 'two calls');
    like($Test::MockIO::requests[0]->url, qr/\blimit=25\b/, 'first request carries limit=page_size');
    like($Test::MockIO::requests[1]->url, qr/\blimit=25\b/, 'subsequent page carries limit=page_size');
};

# (d) single-page array (count == items) returns as-is with exactly one call
subtest 'single page (count == items) returns as-is, one call' => sub {
    reset_mock();
    queue('[{"id":1},{"id":2}]', 'X-Total-Count' => 2);

    my $items = $client->get('/things');

    is(scalar @Test::MockIO::requests, 1, 'exactly one call');
    is(scalar @$items, 2, 'both items returned');
};

# (d') array without X-Total-Count returns as-is with exactly one call
subtest 'array without X-Total-Count returns as-is, one call' => sub {
    reset_mock();
    queue('[{"id":1},{"id":2}]');

    my $items = $client->get('/things');

    is(scalar @Test::MockIO::requests, 1, 'exactly one call');
    is(scalar @$items, 2, 'both items returned');
};

# (e) single-object (non-array) GET is unchanged with one call, even if the
# server happens to send an X-Total-Count header
subtest 'single-object GET is unchanged, one call' => sub {
    reset_mock();
    queue('{"id":1,"login":"x"}', 'X-Total-Count' => 99);

    my $obj = $client->get('/user');

    is(ref $obj, 'HASH', 'hash returned unchanged');
    is($obj->{id}, 1, 'object content intact');
    is(scalar @Test::MockIO::requests, 1, 'exactly one call, objects never paginate');
};

# Explicitly-paged calls are never auto-paginated (design constraint)
subtest 'explicitly-paged call is not auto-paginated' => sub {
    reset_mock();
    queue('[{"id":1},{"id":2}]', 'X-Total-Count' => 10);

    my $items = $client->get('/things', params => { page => 1 });

    is(scalar @Test::MockIO::requests, 1, 'caller pinned a page => single call');
    is(scalar @$items, 2, 'returned page as-is');
};

# (f) Forgejo search endpoints wrap the collection in an envelope object,
# { ok => true, data => [ ... ] }, still with X-Total-Count. That shape must
# paginate exactly like a bare array: fetch the remaining pages, concatenate
# each page's `data`, and return the SAME envelope with the merged `data` so
# search callers (e.g. repos->search, admin->users->search_emails) keep the
# object they consume.
subtest 'auto-paginates a search-object envelope, merging data across pages' => sub {
    reset_mock();
    queue('{"ok":true,"data":[{"id":1},{"id":2}]}', 'X-Total-Count' => 3);
    queue('{"ok":true,"data":[{"id":3}]}',          'X-Total-Count' => 3);

    my $result = $client->get('/repos/search');

    is(ref $result, 'HASH', 'envelope hashref returned (shape preserved)');
    ok($result->{ok}, 'envelope ok flag preserved');
    is(ref $result->{data}, 'ARRAY', 'data is an arrayref');
    is(scalar @{ $result->{data} }, 3, 'all 3 items collected across pages');
    is_deeply([ map { $_->{id} } @{ $result->{data} } ], [ 1, 2, 3 ], 'data merged in order');
    is(scalar @Test::MockIO::requests, 2, 'exactly two HTTP calls');
    like($Test::MockIO::requests[1]->url, qr/\bpage=2\b/,  'second call requests page 2');
    like($Test::MockIO::requests[1]->url, qr/\blimit=2\b/, 'second call limit = first-page data count');
};

# (g) The trigger is TIGHT: an object with a `data` arrayref but NO
# X-Total-Count is an ordinary response, not a paginated collection, and must
# be handed back untouched with no extra HTTP calls. (Test (e) covers the other
# half: an object carrying X-Total-Count but no `data` arrayref.)
subtest 'object with data key but no X-Total-Count is returned intact' => sub {
    reset_mock();
    queue('{"id":7,"data":[{"id":1}]}');

    my $obj = $client->get('/some/object');

    is(ref $obj, 'HASH', 'hash returned unchanged');
    is($obj->{id}, 7, 'object content intact');
    is_deeply($obj->{data}, [ { id => 1 } ], 'data key left exactly as received');
    is(scalar @Test::MockIO::requests, 1, 'exactly one call, non-envelope never paginates');
};

# (h) The Actions runs endpoint answers { workflow_runs => [...], total_count
# => N } and (live, Forgejo 15) sends NO X-Total-Count header: the total is
# only in the body. It paginates like the search envelope, keeps the other
# keys and replaces only workflow_runs.
subtest 'auto-paginates a workflow_runs envelope via body total_count' => sub {
    reset_mock();
    queue('{"workflow_runs":[{"id":1},{"id":2}],"total_count":3}');
    queue('{"workflow_runs":[{"id":3}],"total_count":3}');

    my $result = $client->get('/repos/o/r/actions/runs');

    is(ref $result, 'HASH', 'envelope hashref returned (shape preserved)');
    is($result->{total_count}, 3, 'total_count key preserved');
    is(ref $result->{workflow_runs}, 'ARRAY', 'workflow_runs is an arrayref');
    is_deeply([ map { $_->{id} } @{ $result->{workflow_runs} } ], [ 1, 2, 3 ], 'runs merged in order');
    ok(!exists $result->{data}, 'no data key invented');
    is(scalar @Test::MockIO::requests, 2, 'exactly two HTTP calls');
    like($Test::MockIO::requests[1]->url, qr/\bpage=2\b/,  'second call requests page 2');
    like($Test::MockIO::requests[1]->url, qr/\blimit=2\b/, 'second call limit = first-page item count');
};

subtest 'workflow_runs envelope with pinned page is not paginated' => sub {
    reset_mock();
    queue('{"workflow_runs":[{"id":1},{"id":2}],"total_count":10}');

    my $result = $client->get('/repos/o/r/actions/runs', params => { page => 1, limit => 2 });

    is(scalar @Test::MockIO::requests, 1, 'caller pinned a page => single call');
    is(scalar @{ $result->{workflow_runs} }, 2, 'page returned as-is');
};

subtest 'workflow_runs envelope with total_count <= items needs no extra request' => sub {
    reset_mock();
    queue('{"workflow_runs":[{"id":1},{"id":2}],"total_count":2}');

    my $result = $client->get('/repos/o/r/actions/runs');

    is(scalar @Test::MockIO::requests, 1, 'exactly one call');
    is(scalar @{ $result->{workflow_runs} }, 2, 'both runs returned');
};

subtest 'X-Total-Count header wins over body total_count' => sub {
    reset_mock();
    # Body claims 2 (nothing to fetch); the header says 3, so page 2 is read.
    queue('{"workflow_runs":[{"id":1},{"id":2}],"total_count":2}', 'X-Total-Count' => 3);
    queue('{"workflow_runs":[{"id":3}],"total_count":2}',          'X-Total-Count' => 3);

    my $result = $client->get('/repos/o/r/actions/runs');

    is(scalar @{ $result->{workflow_runs} }, 3, 'header total drove the pagination');
    is(scalar @Test::MockIO::requests, 2, 'two calls');
};

subtest 'object with total_count but no collection array is unchanged' => sub {
    reset_mock();
    queue('{"id":7,"total_count":99}');

    my $obj = $client->get('/some/object');

    is_deeply($obj, { id => 7, total_count => 99 }, 'object left as received');
    is(scalar @Test::MockIO::requests, 1, 'exactly one call');
};

subtest 'envelope helpers are callable without a request' => sub {
    my $runs = { workflow_runs => [ { id => 1 } ], total_count => 5 };
    is($client->_collection_key($runs), 'workflow_runs', 'workflow_runs key');
    is($client->_collection_key({ ok => 1, data => [] }), 'data', 'data key');
    is($client->_collection_key([]), undef, 'bare array has no key');
    is($client->_collection_key({ id => 1 }), undef, 'plain object has no key');
    is($client->_collection_total($runs, {}), 5, 'body total_count');
    is($client->_collection_total($runs, { 'x-total-count' => 9 }), 9, 'header wins');
    is($client->_collection_total([], {}), undef, 'no total for a bare array');
};

done_testing;
