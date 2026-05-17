package WWW::Forgejo::Role::IO;

# ABSTRACT: Interface role for pluggable HTTP backends

use Moo::Role;

our $VERSION = '0.001';

requires 'call';

1;

__END__

=head1 SYNOPSIS

    package My::AsyncIO;
    use Moo;
    with 'WWW::Forgejo::Role::IO';

    sub call {
        my ($self, $req) = @_;
        # Execute HTTP request, return WWW::Forgejo::HTTPResponse
        ...
    }

=head1 DESCRIPTION

This role defines the interface that HTTP backends must implement.
L<WWW::Forgejo::Role::HTTP> delegates all HTTP communication through this
interface, making it possible to swap out the transport layer.

The default backend is L<WWW::Forgejo::LWPIO> (synchronous, using
L<LWP::UserAgent>). To use an async event loop, implement this role
with e.g. L<Net::Async::HTTP> or L<Mojo::UserAgent>.

=head1 REQUIRED METHODS

=head2 call($req)

Execute an HTTP request. Receives a L<WWW::Forgejo::HTTPRequest> with
C<method>, C<url>, C<headers>, and optionally C<content> already set.

Must return a L<WWW::Forgejo::HTTPResponse> with C<status> and C<content>.

=head1 SEE ALSO

L<WWW::Forgejo::LWPIO>, L<WWW::Forgejo::Role::HTTP>

=cut