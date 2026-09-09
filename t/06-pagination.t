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

done_testing;
