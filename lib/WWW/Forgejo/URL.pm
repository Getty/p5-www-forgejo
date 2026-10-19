package WWW::Forgejo::URL;

# ABSTRACT: Percent-encoding of the parts of a Forgejo API URL
# PODNAME: WWW::Forgejo::URL

use strict;
use warnings;

use Exporter 'import';
use URI::Escape ();

our $VERSION = '0.001';

our @EXPORT_OK = qw( escape_component );

=func escape_component

    my $encoded = escape_component('Buecher');

Percent-encodes one part of a URL: a path segment, a query key or a query
value.

The text is encoded as UTF-8 before it is escaped. A character between
U+0080 and U+00FF therefore goes out as the two bytes of its UTF-8 form
(C<%C3%BC> for U+00FC), the same way the JSON body sends it, and a character
above U+00FF is encoded as well instead of making the escaping croak.

=cut

sub escape_component {
    my ($text) = @_;
    return undef unless defined $text;
    return URI::Escape::uri_escape_utf8($text);
}

=head1 SYNOPSIS

    use WWW::Forgejo::URL qw( escape_component );

    my $segment = escape_component('Buecher');

=head1 DESCRIPTION

Percent-encoding of the single parts of a Forgejo API URL. Every path segment
and every query key and value of the client goes through
L</escape_component>, so there is one place that decides how a name is
encoded.

Callers pass decoded text: characters, not percent-encoded text. A name is
encoded exactly once - the controllers escape every part of the path they
build, and the request builder passes the finished path on unchanged.

=head1 SEE ALSO

L<WWW::Forgejo::Role::HTTP>, L<URI::Escape>

=cut

1;
