package WWW::Forgejo::Role::HTTP;

# ABSTRACT: HTTP client role for Forgejo API clients

use Moo::Role;
use WWW::Forgejo::HTTPRequest;
use WWW::Forgejo::HTTPResponse;
use WWW::Forgejo::LWPIO;
use JSON::MaybeXS qw(decode_json encode_json);
use Encode ();
use HTTP::Request::Common ();
use WWW::Forgejo::URL qw( escape_component );
use Carp qw(croak);
use Log::Any qw($log);
use constant DEFAULT_MAX_PAGES => 100;
use namespace::clean;

our $VERSION = '0.001';

=head1 SYNOPSIS

    package My::Forgejo::Client;
    use Moo;

    has token    => ( is => 'ro' );
    has base_url => ( is => 'ro', default => 'https://forgejo.example/api/v1' );

    with 'WWW::Forgejo::Role::HTTP';

    package main;

    my $client = My::Forgejo::Client->new(token => $ENV{FORGEJO_TOKEN});
    my $user   = $client->get('/user');
    my $repo   = $client->post('/user/repos', { name => 'new-repo' });

=head1 DESCRIPTION

This role provides the HTTP verb methods (GET, POST, PUT, PATCH, DELETE) for
Forgejo API clients. It handles JSON encoding/decoding, authentication, and
error handling. L<WWW::Forgejo> consumes it; the C<WWW::Forgejo::API::*>
controllers send all their requests through these methods.

Paths are relative to C<base_url>, e.g. C</user> or C</repos/owner/name>.
Requests are authenticated with an C<Authorization: token ...> header and carry
C<Content-Type: application/json>.

Path segments and query keys and values are percent-encoded by
L<WWW::Forgejo::URL>, which encodes the text as UTF-8 before escaping it. The
contract is: callers pass decoded text - characters, not percent-encoded text -
and encode every part exactly once. The controllers escape each part of the
path they build, and the request builder passes the finished path on unchanged.

A response body that is a JSON object or array is decoded and returned as Perl
data. Any other non-empty body (rendered HTML, an armored key) is returned as a
string: decoded to characters when it is C<text/*> with a C<charset>, else as
the bytes that came. An empty body yields C<undef>. With the C<raw> option (see
L</get>) the body is returned exactly as it came, as bytes, never decoded.

A response status outside the 2xx range makes the verb methods croak with
C<Forgejo API error: ...>, followed by the C<message> of the JSON error body if
there is a non-empty one, else the body itself when it is one short line of
plain text (such as C<404 page not found> for a route the instance does not
have), else the status code. Calling a verb method without a token croaks with
C<No API token configured>.

HTTP transport is delegated to a pluggable L<WWW::Forgejo::Role::IO> backend
(default: L<WWW::Forgejo::LWPIO>), making it possible to use async HTTP
clients.

Uses L<Log::Any> for logging HTTP requests and responses.

=head1 REQUIRED ATTRIBUTES

Classes consuming this role must provide:

=over 4

=item * C<token> - API authentication token (personal access token)

=item * C<base_url> - Base URL for the API

=back

=cut

requires 'token';
requires 'base_url';

has io => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::LWPIO->new },
);

=attr io

Pluggable HTTP backend implementing L<WWW::Forgejo::Role::IO>.
Defaults to L<WWW::Forgejo::LWPIO>.

    # Use a custom IO backend
    my $forgejo = WWW::Forgejo->new(
        url   => $url,
        token => $token,
        io    => My::IO->new,
    );

=cut

sub get {
    my ($self, $path, %opts) = @_;

    my $page_size = delete $opts{page_size};
    my $max_pages = delete $opts{max_pages} // DEFAULT_MAX_PAGES;

    my $pinned = $opts{params} && defined $opts{params}{page};

    # An explicit page_size must apply to the first request too, so every
    # fetched page uses the same limit and Forgejo's (page-1)*limit offsets
    # stay contiguous. Without one we leave the first request untouched and
    # adopt the server's own page size below.
    if (defined $page_size && !$pinned) {
        $opts{params} = { %{ $opts{params} || {} }, limit => $page_size };
    }

    my ($data, $response) = $self->_request_with_response('GET', $path, %opts);

    # Locate the collection this response paginates over: a bare JSON array, or
    # the arrayref inside an envelope ({ ok => ..., data => [...] } for search,
    # { workflow_runs => [...], total_count => N } for Actions runs).
    # Auto-paginate only when the server reports the collection as truncated
    # (X-Total-Count header, else the body's total_count), and only when the
    # caller has not pinned a specific page. Plain objects (no collection
    # arrayref), collections without a total, and explicitly-paged requests are
    # returned unchanged with no extra HTTP calls.
    my $items = $self->_collection_ref($data);
    return $data unless $items;
    return $data if $pinned;

    my $total = $self->_collection_total($data, $response->headers);
    return $data unless defined $total;
    return $data unless $total > scalar @$items;

    # Keep the per-page limit consistent across every fetched page so offsets
    # stay aligned. With no explicit page_size the server's page size is exactly
    # the number of items the first page returned, so reuse that: page N then
    # starts at (N-1)*limit, contiguous with no skipped or duplicated items.
    my $limit = defined $page_size ? $page_size : scalar @$items;
    return $data unless $limit;

    my @collected = @$items;
    my $page  = 1;
    while (@collected < $total && $page < $max_pages) {
        $page++;
        my %page_opts = %opts;
        $page_opts{params} = {
            %{ $opts{params} || {} },
            page  => $page,
            limit => $limit,
        };
        my ($page_data) = $self->_request_with_response('GET', $path, %page_opts);
        my $page_items = $self->_collection_ref($page_data);
        last unless $page_items && @$page_items;
        push @collected, @$page_items;
    }

    # Return the same shape we received: a bare array as the merged arrayref,
    # an envelope with only its collection key (`data` / `workflow_runs`)
    # replaced by the merged collection so callers keep the object they consume.
    my $key = $self->_collection_key($data);
    return { %$data, $key => \@collected } if defined $key;
    return \@collected;
}

sub _collection_key {
    my ($self, $data) = @_;
    return unless ref $data eq 'HASH';
    for my $key (qw( data workflow_runs )) {
        return $key if ref $data->{$key} eq 'ARRAY';
    }
    return;
}

=method _collection_key

    my $key = $self->_collection_key($data);

Returns the name of the key holding the collection when C<$data> is a
paginatable envelope - C<data> (search) or C<workflow_runs> (Actions runs) -
and nothing for a bare array, a plain object, or an envelope whose value is not
an arrayref. Has no HTTP state; the async sibling can call it as is.

=cut

sub _collection_ref {
    my ($self, $data) = @_;
    return $data if ref $data eq 'ARRAY';
    my $key = $self->_collection_key($data);
    return $data->{$key} if defined $key;
    return;
}

=method _collection_ref

    my $items = $self->_collection_ref($data);

Returns the paginatable collection inside a decoded GET body, or nothing when
there is none: the arrayref itself for a bare JSON array, or the C<data>
arrayref for a Forgejo search envelope (C<< { ok => ..., data => [...] } >>) or
the C<workflow_runs> arrayref of an Actions runs envelope. Any other shape - a
plain object, or an envelope whose collection is not an arrayref - yields
nothing, so L</get> leaves it untouched. See L</_collection_key>.

=cut

sub _collection_total {
    my ($self, $data, $headers) = @_;
    my $total = $headers && $headers->{'x-total-count'};
    $total = $data->{total_count} if !defined $total && ref $data eq 'HASH';
    return unless defined $total && !ref $total && $total =~ /^[0-9]+$/;
    return $total;
}

=method _collection_total

    my $total = $self->_collection_total($data, $response->headers);

Returns the total number of items the server reports for a collection, or
nothing when it reports none (or a non-numeric one). The C<X-Total-Count>
header (looked up lower-cased in the C<$headers> hashref) wins; without it the
C<total_count> of an envelope body is used, which is all the Actions runs
endpoint sends. Has no HTTP state; the async sibling can call it as is.

=cut

=method get

    my $data = $self->get('/path', params => { key => 'value' });

Perform a GET request.

When the response is a paginatable collection and the server reports more
results than were returned on the first page, C<get> transparently collects the
remaining pages and returns them combined (in order). The total is the
C<X-Total-Count> header, or - when absent - the C<total_count> of an envelope
body (see L</_collection_total>). Three collection shapes are recognised: a
bare JSON array (returned as the merged arrayref), a Forgejo search envelope
C<< { ok => ..., data => [...] } >> and an Actions runs envelope
C<< { workflow_runs => [...], total_count => N } >> (both returned as the same
object, other keys kept, with only C<data> / C<workflow_runs> replaced by the
merged collection). This happens only when the caller has not pinned a page (no
C<< params->{page} >>); plain objects (no collection arrayref), collections
without a total, and explicitly-paged requests are returned as-is with no extra
HTTP calls.

The header is read from L<WWW::Forgejo::HTTPResponse/headers>, so an L</io>
backend has to pass the response headers on for this to work;
L<WWW::Forgejo::LWPIO> does.

The per-page C<limit> is kept consistent across every fetched page so that
Forgejo's C<(page - 1) * limit> offsets stay contiguous - no items are skipped
or duplicated between pages.

Two top-level options (alongside C<params>) tune the pagination:

=over 4

=item * C<page_size> - an optional per-page C<limit>. When given it is sent on
B<every> request (including the first) so all pages share the same size. When
omitted, no C<limit> is forced: the server's own page size is used, and
subsequent pages reuse the item count returned by the first page to keep
offsets aligned.

=item * C<max_pages> - the maximum number of pages fetched, a safety cap
against unbounded loops. Defaults to 100.

=back

    # collect all repos, 100 per page, at most 20 pages
    my $repos = $self->get('/user/repos', page_size => 100, max_pages => 20);

The C<list> methods of the controllers send their named arguments as query
parameters, so there C<< limit => 100 >> has the effect of C<page_size> and
C<< page => 2 >> pins a page.

Query parameters with an undefined value are left out of the request.

C<< raw => 1 >> returns the response body exactly as it came, as bytes: no
JSON decoding, no charset decoding, no pagination. The file endpoints
(L<WWW::Forgejo::API::Repo::Contents/raw> and its siblings) use it.

    my $bytes = $self->get('/repos/o/r/raw/data.json', raw => 1);

=cut

sub post {
    my ($self, $path, $data, %opts) = @_;
    return $self->_request('POST', $path, %opts, body => $data);
}

=method post

    my $data = $self->post('/path', { key => 'value' });
    my $data = $self->post('/path', undef, params => { name => 'file.txt' },
        upload => { file => '/path/to/file.txt' });

Perform a POST request with JSON body. C<params> adds a query string.

With C<upload> the request is sent as C<multipart/form-data> instead: the
hashref names the form C<field> (default C<attachment>) and either a C<file> on
disk or the raw C<content>, plus an optional C<filename> (required with
C<content>, defaulting to the base name of C<file> otherwise).

=cut

sub put {
    my ($self, $path, $data, %opts) = @_;
    return $self->_request('PUT', $path, %opts, body => $data);
}

=method put

    my $data = $self->put('/path', { key => 'value' });
    my $data = $self->put('/path', undef, params => { key => 'value' });

Perform a PUT request with JSON body. C<params> adds a query string.

=cut

sub delete {
    my ($self, $path, $data, %opts) = @_;
    return $self->_request('DELETE', $path, %opts, body => $data);
}

=method delete

    my $data = $self->delete('/path');
    my $data = $self->delete('/path', { key => 'value' });

Perform a DELETE request. The optional data is sent as JSON body, for the
endpoints that take one. C<params> adds a query string.

=cut

sub patch {
    my ($self, $path, $data, %opts) = @_;
    return $self->_request('PATCH', $path, %opts, body => $data);
}

=method patch

    my $data = $self->patch('/path', { key => 'value' });

Perform a PATCH request with JSON body. C<params> adds a query string.

=cut

sub check {
    my ($self, $path, %opts) = @_;

    croak "No API token configured" unless $self->token;

    my $req      = $self->_build_request('GET', $path, %opts);
    my $response = $self->io->call($req);

    # A 404 is the "no" of the question - unless it is the plain-text 404 of
    # a route this instance does not have (an older Forgejo, a feature that
    # is switched off): that one croaks like any other error.
    my $route_missing = ($response->headers->{'content-type'} // '') =~ m{\A\s*text/plain\b}i
        && ($response->content // '') =~ /\A\s*404 page not found/;
    return 0 if $response->status == 404 && !$route_missing;
    $self->_parse_response($response, 'GET', $path);
    return 1;
}

=method check

    my $bool = $self->check('/repos/owner/name/collaborators/username');

Perform a GET request against an endpoint that answers a yes/no question with
its status code. Returns true for a 2xx response and false for C<404>; any other
status croaks like the verb methods do. So does the plain-text
C<404 page not found> of a route the instance does not have (an older Forgejo,
a feature that is switched off), which would otherwise read as "no".

Forgejo answers some questions about a thing that does not exist with the same
C<404> as the "no" (C<is_merged> of a pull request that does not exist, a member
check in an organization that does not exist): C<check> cannot tell them apart.

=cut

sub _set_auth {
    my ($self, $headers) = @_;
    $headers->{Authorization} = 'token ' . $self->token;
}

=method _set_auth

Sets authentication headers using token authentication:

    sub _set_auth {
        my ($self, $headers) = @_;
        $headers->{Authorization} = 'token ' . $self->token;
    }

=cut

sub _build_request {
    my ($self, $method, $path, %opts) = @_;

    my $url = $self->base_url . $path;

    # Query string, in sorted key order so the URL is deterministic.
    if ($opts{params}) {
        my @pairs;
        for my $k (sort keys %{$opts{params}}) {
            my $v = $opts{params}{$k};
            next unless defined $v;
            push @pairs, escape_component($k) . '=' . escape_component($v);
        }
        $url .= '?' . join('&', @pairs) if @pairs;
    }

    $log->debug("$method $url");

    my %headers;
    $self->_set_auth(\%headers);
    $headers{'Content-Type'} = 'application/json';

    my %req_args = (
        method  => $method,
        url     => $url,
        headers => \%headers,
    );

    if (my $upload = $opts{upload}) {
        my ($content_type, $content) = $self->_multipart($upload);
        $headers{'Content-Type'} = $content_type;
        $req_args{content} = $content;
        $log->debugf("Body: multipart upload, %d bytes", length $content);
    }
    elsif ($opts{body}) {
        $req_args{content} = encode_json($opts{body});
        $log->debugf("Body: %s", $req_args{content});
    }

    return WWW::Forgejo::HTTPRequest->new(%req_args);
}

=method _build_request

    my $req = $self->_build_request('GET', '/user', params => { page => 1 });

Builds a L<WWW::Forgejo::HTTPRequest> without executing it. Useful for
async workflows where request creation and execution are separate steps.

C<params> (a hashref) becomes the query string; C<body> (a hashref or arrayref)
is encoded as the JSON request content; C<upload> (see L</post>) produces a
C<multipart/form-data> request instead.

=cut

# Encode one file as multipart/form-data. Returns the Content-Type header
# (carrying the boundary) and the encoded body.
sub _multipart {
    my ($self, $upload) = @_;

    my $field = $upload->{field} // 'attachment';
    my $part;
    if (defined $upload->{content}) {
        croak "upload: filename required with content" unless defined $upload->{filename};
        $part = [ undef, $upload->{filename}, Content => $upload->{content} ];
    }
    elsif (defined $upload->{file}) {
        croak "upload: cannot read file $upload->{file}" unless -r $upload->{file};
        $part = [ $upload->{file}, $upload->{filename} ];
    }
    else {
        croak "upload: file or content required";
    }

    my $form = HTTP::Request::Common::POST(
        'http://localhost/',
        Content_Type => 'form-data',
        Content      => [ $field => $part ],
    );
    return ($form->header('Content-Type'), $form->content);
}

sub _parse_response {
    my ($self, $response, $method, $path, %opts) = @_;

    $log->debugf("Response: %s", $response->status);

    my $ok      = $response->status >= 200 && $response->status < 300;
    my $content = $response->content;
    my $data;
    if (defined $content && length $content) {
        if ($opts{raw} && $ok) {
            # A file as stored: no decoding of any kind.
            $data = $content;
        }
        elsif ($content =~ /^\s*[\{\[]/) {
            # Looks like JSON. A body may start the same way without being
            # JSON; then it is handed back like any other.
            $data = eval { decode_json($content) };
            $data = $self->_decode_text($response, $content) unless ref $data;
        }
        else {
            $data = $self->_decode_text($response, $content);
        }
    }

    unless ($ok) {
        my $error = $response->status;
        if (ref $data eq 'HASH' && defined $data->{message} && length $data->{message}) {
            $error = $data->{message};
        }
        elsif (defined $data && !ref $data
            && ($response->headers->{'content-type'} // '') =~ m{\A\s*text/plain\b}i
            && $data =~ /\A\s*([^\n]{1,200}?)\s*\z/) {
            # One short line of plain text, like the "404 page not found" of
            # a route the instance does not have.
            $error = $1;
        }
        $log->errorf("API error: %s", $error);
        croak "Forgejo API error: $error";
    }

    $log->infof("%s %s -> %s", $method, $path, $response->status);
    return $data;
}

=method _parse_response

    my $data = $self->_parse_response($response, 'GET', '/user');

    my $bytes = $self->_parse_response($response, 'GET', $path, raw => 1);

Parses a L<WWW::Forgejo::HTTPResponse>: decodes JSON, decodes a C<text/*> body
from its C<charset>, checks for errors. With C<< raw => 1 >> a successful body
is returned as it is. Useful for async workflows where response parsing happens
after transport.

The response content is expected as the bytes of the body (see
L<WWW::Forgejo::HTTPResponse/content>); a text body that a transport already
decoded to characters is accepted as well and left alone.

=cut

# A text/* body with a charset becomes characters; anything else stays as it is.
sub _decode_text {
    my ($self, $response, $content) = @_;
    my $type = $response->headers->{'content-type'} // '';
    return $content unless $type =~ m{\A\s*text/}i;
    my ($charset) = $type =~ /;\s*charset\s*=\s*"?([\w.:-]+)/i;
    return $content unless $charset;
    # Characters already: a transport decoded the text on its own.
    return $content if utf8::is_utf8($content);
    my $text = eval { Encode::decode($charset, $content, Encode::FB_CROAK() | Encode::LEAVE_SRC()) };
    return defined $text ? $text : $content;
}

=method _decode_text

    my $text = $self->_decode_text($response, $content);

Decodes C<$content> to characters when the C<Content-Type> of C<$response> is
C<text/*> and names a C<charset>. Any other body, a body that is not valid in
its charset, and a body that is characters already are returned unchanged.

=cut

sub _request {
    my ($self, $method, $path, %opts) = @_;
    my ($data) = $self->_request_with_response($method, $path, %opts);
    return $data;
}

sub _request_with_response {
    my ($self, $method, $path, %opts) = @_;

    croak "No API token configured" unless $self->token;

    my $req = $self->_build_request($method, $path, %opts);
    my $response = $self->io->call($req);
    my $data = $self->_parse_response($response, $method, $path, raw => $opts{raw});
    return ($data, $response);
}

=method _request_with_response

    my ($data, $response) = $self->_request_with_response('GET', '/orgs');

Runs a request like the internal path used by the verb methods, but returns
both the parsed data B<and> the L<WWW::Forgejo::HTTPResponse>, so callers (such
as the auto-pagination logic in L</get>) can read response headers like
C<X-Total-Count>. The public verb methods (C<post>/C<put>/C<patch>/C<delete>)
still return only the parsed data.

=cut

=head1 SEE ALSO

L<WWW::Forgejo>, L<WWW::Forgejo::Role::IO>, L<WWW::Forgejo::LWPIO>,
L<WWW::Forgejo::HTTPRequest>, L<WWW::Forgejo::HTTPResponse>, L<Log::Any>

=cut

1;
