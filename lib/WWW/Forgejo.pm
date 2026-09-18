# ABSTRACT: Perl client for the Forgejo API v1
# PODNAME: WWW::Forgejo

use strict;
use warnings;

package WWW::Forgejo;

use Moo;
use Carp qw(croak);
use WWW::Forgejo::Role::HTTP;
use WWW::Forgejo::API::Misc;
use WWW::Forgejo::API::Users;
use WWW::Forgejo::API::Orgs;
use WWW::Forgejo::API::Teams;
use WWW::Forgejo::API::Notifications;
use WWW::Forgejo::API::Packages;
use WWW::Forgejo::API::Repos;
use WWW::Forgejo::API::CurrentUser;
use WWW::Forgejo::API::Admin;
use namespace::clean;

our $VERSION = '0.001';

=attr url

Raw base URL of your Forgejo instance as given, e.g. C<https://src.ci>
(without the C</api/v1> suffix). Resolved at construction from the C<url>
option, else the C<FORGEJO_URL> environment variable; if neither is set the
constructor croaks with a helpful message. Any trailing slash is stripped.
The normalised API base is available via L</base_url>.

=cut

has url => (
    is => 'ro',
);

=attr base_url

The API base URL: L</url> normalised to end in C</api/v1> (idempotent: an
already-suffixed URL is left unchanged). Derived from L</url> at construction;
this is the URL requests are built against.

=cut

has base_url => (
    is => 'ro',
);

=attr token

Your Forgejo personal access token. Resolved at construction from the C<token>
option, else the C<FORGEJO_TOKEN> environment variable, else the empty string.
A missing token does not croak at construction; a request made without one
croaks at call time.

=cut

has token => (
    is      => 'ro',
    default => sub { '' },
);

around BUILDARGS => sub {
    my ( $orig, $class, @args ) = @_;
    my $args = $class->$orig(@args);

    # Resolve the instance URL: explicit url option, else FORGEJO_URL, else
    # croak with help naming both. Matches the Net::Async::Forgejo sibling.
    my $url = defined $args->{url} ? $args->{url} : $ENV{FORGEJO_URL};
    croak
          "No Forgejo URL configured.\n\n"
        . "Set url via:\n"
        . "  Environment: FORGEJO_URL\n"
        . "  Option:      url => \$url\n\n"
        . "Example: https://src.ci"
        unless defined $url && length $url;

    # Strip trailing slashes; the result is the raw instance URL as given.
    $url =~ s{/+$}{};
    $args->{url} = $url;

    # base_url is url normalised to end in /api/v1, idempotently: append only
    # when it is not already suffixed (no double-append).
    my $base_url = $url;
    $base_url .= '/api/v1' unless $base_url =~ m{/api/v1$};
    $args->{base_url} = $base_url;

    # Token: explicit token option, else FORGEJO_TOKEN; the attribute default
    # supplies '' when neither is set.
    $args->{token} = $ENV{FORGEJO_TOKEN}
        if !defined $args->{token} && defined $ENV{FORGEJO_TOKEN};

    return $args;
};

with 'WWW::Forgejo::Role::HTTP';

has misc => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::Misc->new(client => shift) },
);

has users => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::Users->new(client => shift) },
);

has orgs => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::Orgs->new(client => shift) },
);

has teams => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::Teams->new(client => shift) },
);

has notifications => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::Notifications->new(client => shift) },
);

has packages => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::Packages->new(client => shift) },
);

has repos => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::Repos->new(client => shift) },
);

has current_user => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::CurrentUser->new(client => shift) },
);

has admin => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::Admin->new(client => shift) },
);

1;
__END__

=head1 SYNOPSIS

  use WWW::Forgejo;

  my $client = WWW::Forgejo->new(
    url   => 'https://src.ci',
    token => $ENV{FORGEJO_TOKEN},
  );

=cut