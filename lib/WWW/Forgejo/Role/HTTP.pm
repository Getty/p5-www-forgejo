package WWW::Forgejo::Role::HTTP;

# ABSTRACT: HTTP client role for Forgejo API clients

use Moo::Role;
use WWW::Forgejo::HTTPRequest;
use WWW::Forgejo::HTTPResponse;
use WWW::Forgejo::LWPIO;
use JSON::MaybeXS qw(decode_json encode_json);
use URI::Escape qw(uri_escape);
use Carp qw(croak);
use Log::Any qw($log);

our $VERSION = '0.001';

use constant DEFAULT_MAX_PAGES => 100;

=head1 SYNOPSIS

    package WWW::Forgejo::API;
    use Moo;

    has token => ( is => 'ro' );
    has base_url => ( is => 'ro', default => 'https://forgejo.example/api/v1' );

    with 'WWW::Forgejo::Role::HTTP';

=head1 DESCRIPTION

This role provides HTTP methods (GET, POST, PUT, DELETE) for Forgejo API
clients. It handles JSON encoding/decoding, authentication, and error handling.

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
    my $api = WWW::Forgejo::API->new(
        token => $token,
        io    => My::AsyncIO->new,
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

    # Auto-paginate only bare JSON arrays that the server reports as truncated,
    # and only when the caller has not pinned a specific page. Single-object
    # responses, arrays without an X-Total-Count header, and explicitly-paged
    # requests are returned unchanged with no extra HTTP calls.
    return $data unless ref $data eq 'ARRAY';
    return $data if $pinned;

    my $total = $response->headers->{'x-total-count'};
    return $data unless defined $total && $total =~ /^[0-9]+$/;
    return $data unless $total > scalar @$data;

    # Keep the per-page limit consistent across every fetched page so offsets
    # stay aligned. With no explicit page_size the server's page size is exactly
    # the number of items the first page returned, so reuse that: page N then
    # starts at (N-1)*limit, contiguous with no skipped or duplicated items.
    my $limit = defined $page_size ? $page_size : scalar @$data;
    return $data unless $limit;

    my @items = @$data;
    my $page  = 1;
    while (@items < $total && $page < $max_pages) {
        $page++;
        my %page_opts = %opts;
        $page_opts{params} = {
            %{ $opts{params} || {} },
            page  => $page,
            limit => $limit,
        };
        my ($page_data) = $self->_request_with_response('GET', $path, %page_opts);
        last unless ref $page_data eq 'ARRAY' && @$page_data;
        push @items, @$page_data;
    }

    return \@items;
}

=method get

    my $data = $self->get('/path', params => { key => 'value' });

Perform a GET request.

When the response is a JSON array and the server reports more results via the
C<X-Total-Count> header than were returned on the first page, C<get>
transparently collects the remaining pages and returns the combined arrayref
(in order). This happens only when the caller has not pinned a page (no
C<< params->{page} >>); single-object responses, arrays without an
C<X-Total-Count> header, and explicitly-paged requests are returned as-is with
no extra HTTP calls.

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
    my $repos = $self->get('/repos', page_size => 100, max_pages => 20);

List controllers that forward their C<%params> into C<get> expose these to
callers, e.g. C<< $api->list(page_size => 100) >>.

=cut

sub post {
    my ($self, $path, $data) = @_;
    return $self->_request('POST', $path, body => $data);
}

=method post

    my $data = $self->post('/path', { key => 'value' });

Perform a POST request with JSON body.

=cut

sub put {
    my ($self, $path, $data) = @_;
    return $self->_request('PUT', $path, body => $data);
}

=method put

    my $data = $self->put('/path', { key => 'value' });

Perform a PUT request with JSON body.

=cut

sub delete {
    my ($self, $path) = @_;
    return $self->_request('DELETE', $path);
}

=method delete

    my $data = $self->delete('/path');

Perform a DELETE request.

=cut

sub patch {
    my ($self, $path, $data) = @_;
    return $self->_request('PATCH', $path, body => $data);
}

=method patch

    my $data = $self->patch('/path', { key => 'value' });

Perform a PATCH request with JSON body.

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

    # Add query params for GET
    if ($method eq 'GET' && $opts{params}) {
        my @pairs;
        for my $k (keys %{$opts{params}}) {
            my $v = $opts{params}{$k};
            next unless defined $v;
            push @pairs, uri_escape($k) . '=' . uri_escape($v);
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

    if ($opts{body}) {
        $req_args{content} = encode_json($opts{body});
        $log->debugf("Body: %s", $req_args{content});
    }

    return WWW::Forgejo::HTTPRequest->new(%req_args);
}

=method _build_request

    my $req = $self->_build_request('GET', '/user', params => { page => 1 });

Builds a L<WWW::Forgejo::HTTPRequest> without executing it. Useful for
async workflows where request creation and execution are separate steps.

=cut

sub _parse_response {
    my ($self, $response, $method, $path) = @_;

    $log->debugf("Response: %s", $response->status);

    my $data;
    if ($response->content && $response->content =~ /^\s*[\{\[]/) {
        $data = decode_json($response->content);
    }

    unless ($response->status >= 200 && $response->status < 300) {
        my $error = $data->{message} // $response->status;
        $log->errorf("API error: %s", $error);
        croak "Forgejo API error: $error";
    }

    $log->infof("%s %s -> %s", $method, $path, $response->status);
    return $data;
}

=method _parse_response

    my $data = $self->_parse_response($response, 'GET', '/user');

Parses a L<WWW::Forgejo::HTTPResponse>: decodes JSON, checks for errors.
Useful for async workflows where response parsing happens after transport.

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
    my $data = $self->_parse_response($response, $method, $path);
    return ($data, $response);
}

=method _request_with_response

    my ($data, $response) = $self->_request_with_response('GET', '/orgs');

Runs a request like the internal path used by the verb methods, but returns
both the parsed data B<and> the L<WWW::Forgejo::HTTPResponse>, so callers (such
as the auto-pagination logic in L</get>) can read response headers like
C<X-Total-Count>. The public verb methods (C<post>/C<put>/C<patch>/C<delete>)
still return only the parsed data via L</_request>.

=cut

=head1 SEE ALSO

L<WWW::Forgejo::API>, L<WWW::Forgejo::Role::IO>, L<WWW::Forgejo::LWPIO>,
L<Log::Any>

=cut

1;