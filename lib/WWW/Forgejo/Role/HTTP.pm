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
    my ($self, $path, %params) = @_;
    return $self->_request('GET', $path, %params);
}

=method get

    my $data = $self->get('/path', params => { key => 'value' });

Perform a GET request.

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

    croak "No API token configured" unless $self->token;

    my $req = $self->_build_request($method, $path, %opts);
    my $response = $self->io->call($req);
    return $self->_parse_response($response, $method, $path);
}

=head1 SEE ALSO

L<WWW::Forgejo::API>, L<WWW::Forgejo::Role::IO>, L<WWW::Forgejo::LWPIO>,
L<Log::Any>

=cut

1;