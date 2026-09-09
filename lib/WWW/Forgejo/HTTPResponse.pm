package WWW::Forgejo::HTTPResponse;

# ABSTRACT: HTTP response object for Forgejo API

use Moo;

our $VERSION = '0.001';

=head1 SYNOPSIS

    use WWW::Forgejo::HTTPResponse;

    my $res = WWW::Forgejo::HTTPResponse->new(
        status  => 200,
        content => '{"ok":true}',
        headers => { 'X-Total-Count' => 42 },
    );

    my $total = $res->headers->{'x-total-count'};

=head1 DESCRIPTION

Transport-independent HTTP response object. Returned by L<WWW::Forgejo::Role::IO>
backends and processed by L<WWW::Forgejo::Role::HTTP>.

=cut

has status => (is => 'ro', required => 1);

=attr status

The HTTP status code (e.g., 200, 404, 500).

=cut

has content => (is => 'ro', default => '');

=attr content

The response body content.

=cut

has headers => (
    is      => 'ro',
    coerce  => sub {
        my $h = shift;
        return {} unless defined $h;
        return { map { lc($_) => $h->{$_} } keys %$h };
    },
    default => sub { {} },
);

=attr headers

The response headers as a hashref. Keys are always lower-cased at
construction, so a header passed as C<X-Total-Count> is retrieved via
C<< $res->headers->{'x-total-count'} >>; values are preserved as-is.
Defaults to an empty hashref when omitted.

=cut

=head1 SEE ALSO

L<WWW::Forgejo::HTTPRequest>, L<WWW::Forgejo::Role::IO>

=cut

1;