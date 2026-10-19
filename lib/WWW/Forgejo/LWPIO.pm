package WWW::Forgejo::LWPIO;

# ABSTRACT: Synchronous HTTP backend using LWP::UserAgent

use Moo;
use Carp qw( croak );
use LWP::UserAgent;
use HTTP::Request;
use WWW::Forgejo::HTTPResponse;
use namespace::clean;

with 'WWW::Forgejo::Role::IO';

our $VERSION = '0.001';

=head1 SYNOPSIS

    use WWW::Forgejo::LWPIO;

    my $io = WWW::Forgejo::LWPIO->new(timeout => 60);

=head1 DESCRIPTION

Default synchronous HTTP backend using L<LWP::UserAgent>. Implements
L<WWW::Forgejo::Role::IO>.

For C<https> URLs L<LWP::UserAgent> needs L<LWP::Protocol::https>, which is
only a recommended prerequisite of this distribution, because Forgejo often
runs without TLS inside a private network: install it when your instance is
served over TLS.

=cut

has timeout => (is => 'ro', default => 30);

=attr timeout

Timeout in seconds for HTTP requests. Defaults to 30.

=cut

has ua => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        LWP::UserAgent->new(
            agent   => 'WWW-Forgejo/' . $VERSION,
            timeout => $self->timeout,
        );
    },
);

=attr ua

L<LWP::UserAgent> instance. Built lazily.

=cut

sub call {
    my ($self, $req) = @_;

    my $http_req = HTTP::Request->new($req->method => $req->url);

    my $headers = $req->headers;
    for my $header (keys %$headers) {
        $http_req->header($header => $headers->{$header});
    }

    $http_req->content($req->content) if $req->has_content;

    my $response = $self->ua->request($http_req);

    # A request that never reached the server: LWP answers it with its own
    # internal response - status 500 and the reason in the message. The
    # reason is what the caller needs: a refused connection, an unknown host
    # or a timeout are not the same as an error of the server.
    if (my $reason = $self->_internal_reason($response)) {
        croak "Forgejo API error: $reason";
    }

    # Hand the response headers on (X-Total-Count drives the pagination in
    # Role::HTTP). A header that occurs more than once is joined with ", ".
    my %res_headers;
    $response->headers->scan(sub {
        my ($name, $value) = @_;
        my $key = lc $name;
        $res_headers{$key} = exists $res_headers{$key} ? "$res_headers{$key}, $value" : $value;
    });

    return WWW::Forgejo::HTTPResponse->new(
        status  => $response->code,
        # The body bytes: a Content-Encoding (gzip) is undone, a charset is
        # not - which of the bodies are text is up to Role::HTTP.
        content => $response->decoded_content(charset => 'none') // '',
        headers => \%res_headers,
    );
}

# The reason of a request that never reached the server, if this response is
# LWP's internal answer to one: the header "Client-Warning: Internal
# response", or the "X-Died" header of a protocol handler that died. Returns
# undef for a response the server sent.
sub _internal_reason {
    my ($self, $response) = @_;

    my $headers = $response->headers;
    my $died    = $headers->header('X-Died');
    my $warning = $headers->header('Client-Warning') // '';

    return undef unless $warning =~ m{\binternal response\b}i
        || (defined $died && length $died);

    # What the protocol handler died of, else the message of the internal
    # response: "Can't connect to 127.0.0.1:9 (Connection refused)".
    my $reason = $died;
    $reason = $response->message unless defined $reason && length $reason;
    $reason = '' unless defined $reason;

    # The reason is one line; the rest is the trace LWP appends.
    my ($line) = split /\n/, $reason;
    $line = '' unless defined $line;
    $line =~ s/\s+\z//;

    return length $line ? $line : undef;
}

=method call

    my $res = $io->call($req);

Execute an L<WWW::Forgejo::HTTPRequest> via LWP and return a
L<WWW::Forgejo::HTTPResponse> built from the status code, the body and the
response headers. The body is handed on as bytes: a C<Content-Encoding> such as
gzip is undone, but text is not decoded from its charset, so a file read
through L<WWW::Forgejo::API::Repo::Contents/raw> arrives exactly as stored.

A request that never reached the server - a refused connection, an unknown
host, a timeout - croaks with the reason LWP gives, e.g. C<Forgejo API error:
Can't connect to 127.0.0.1:9 (Connection refused)>. A response the server sent
is returned as it is, a C<500> of the server included.

=cut

=head1 HTTP DEBUGGING

Load L<LWP::ConsoleLogger::Everywhere> to see full HTTP traffic (headers,
bodies, status codes) without changing your code:

    perl -MLWP::ConsoleLogger::Everywhere your_script.pl

=head1 SEE ALSO

L<WWW::Forgejo::Role::IO>, L<WWW::Forgejo::Role::HTTP>,
L<LWP::ConsoleLogger::Everywhere>

=cut

1;