package WWW::Forgejo::HTTPRequest;

# ABSTRACT: HTTP request object for Forgejo API

use Moo;
use namespace::clean;

our $VERSION = '0.001';

=head1 SYNOPSIS

    use WWW::Forgejo::HTTPRequest;

    my $req = WWW::Forgejo::HTTPRequest->new(
        method  => 'GET',
        url     => 'https://forgejo.example/api/v1/user',
        headers => { Authorization => 'token token' },
    );

=head1 DESCRIPTION

Transport-independent HTTP request object. Used by L<WWW::Forgejo::Role::HTTP>
to build requests that are then executed by an L<WWW::Forgejo::Role::IO>
backend.

=cut

has method => (is => 'ro', required => 1);

=attr method

The HTTP method (GET, POST, PUT, PATCH, DELETE).

=cut

has url => (is => 'ro', required => 1);

=attr url

The complete request URL.

=cut

has headers => (is => 'ro', default => sub { {} });

=attr headers

Hashref of HTTP headers.

=cut

has content => (is => 'ro', predicate => 1);

=attr content

The request body content: a JSON string, or the encoded form data of an
upload. Optional; L</has_content> tells whether there is one.

=method has_content

    $http_request->content($req->content) if $req->has_content;

True when the request carries a body.

=cut

=head1 SEE ALSO

L<WWW::Forgejo::HTTPResponse>, L<WWW::Forgejo::Role::IO>

=cut

1;