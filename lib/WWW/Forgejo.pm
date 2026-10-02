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
use WWW::Forgejo::API::ActivityPub;
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

=method misc

L<WWW::Forgejo::API::Misc> controller: instance information (version, nodeinfo, settings, templates) and markdown/markup rendering.

=cut

sub misc { WWW::Forgejo::API::Misc->new(client => $_[0]) }

=method users

L<WWW::Forgejo::API::Users> controller: look up and search users.

=cut

sub users { WWW::Forgejo::API::Users->new(client => $_[0]) }

=method orgs

L<WWW::Forgejo::API::Orgs> controller: organizations; returns L<WWW::Forgejo::Entity::Org> objects.

=cut

sub orgs { WWW::Forgejo::API::Orgs->new(client => $_[0]) }

=method teams

L<WWW::Forgejo::API::Teams> controller: teams addressed by ID; returns L<WWW::Forgejo::Entity::Team> objects.

=cut

sub teams { WWW::Forgejo::API::Teams->new(client => $_[0]) }

=method notifications

L<WWW::Forgejo::API::Notifications> controller: notifications of the authenticated user.

=cut

sub notifications { WWW::Forgejo::API::Notifications->new(client => $_[0]) }

=method packages

L<WWW::Forgejo::API::Packages> controller: packages.

=cut

sub packages { WWW::Forgejo::API::Packages->new(client => $_[0]) }

=method repos

L<WWW::Forgejo::API::Repos> controller: repositories; returns L<WWW::Forgejo::Entity::Repo> objects, the entry point to issues, pull requests, branches, releases and the other per-repository controllers.

=cut

sub repos { WWW::Forgejo::API::Repos->new(client => $_[0]) }

=method current_user

L<WWW::Forgejo::API::CurrentUser> controller: the user the token belongs to (C</user/...>).

=cut

sub current_user { WWW::Forgejo::API::CurrentUser->new(client => $_[0]) }

=method admin

L<WWW::Forgejo::API::Admin> controller: site administration (C</admin/...>).

=cut

sub admin { WWW::Forgejo::API::Admin->new(client => $_[0]) }

=method activitypub

L<WWW::Forgejo::API::ActivityPub> controller: the ActivityPub endpoints for users (C</activitypub/user-id/...>).

=cut

sub activitypub { WWW::Forgejo::API::ActivityPub->new(client => $_[0]) }

1;
__END__

=head1 SYNOPSIS

  use WWW::Forgejo;

  my $forgejo = WWW::Forgejo->new(
    url   => 'https://forgejo.example.com',   # instance root, /api/v1 is appended
    token => $ENV{FORGEJO_TOKEN},             # personal access token
  );

  # Instance and current user: plain decoded JSON
  my $version = $forgejo->misc->version;
  my $me      = $forgejo->current_user->get;
  print "logged in as $me->{login}\n";

  # A repository is an entity object and the door to everything inside it
  my $repo = $forgejo->repos->get('owner', 'repo-name');
  print $repo->data->{full_name}, "\n";

  # Issues
  for my $issue ($repo->issues->list(state => 'open')) {
    printf "#%d %s\n", $issue->number, $issue->title;
  }
  my $issue = $repo->issues->create({ title => 'Something is broken', body => '...' });
  $repo->issues->add_comment($issue->number, { body => 'On it.' });
  $repo->issues->edit($issue->number, { title => 'Something was broken' });

  # Pull requests
  my $pr = $repo->pulls->create({
    title => 'Add the thing', head => 'feature-branch', base => 'main',
  });
  $repo->pulls->merge($pr->number, \%merge_options);

  # Organizations
  my $org   = $forgejo->orgs->get('my-org');
  my $repos = $forgejo->repos->list_for_org('my-org');

  # Anything without a dedicated method: the raw verbs
  my $data = $forgejo->get('/user/repos', params => { limit => 10 });

=head1 DESCRIPTION

Synchronous client for the REST API (C</api/v1>) of a
L<Forgejo|https://forgejo.org> instance.

The client object itself only knows the instance URL and the access token and
consumes L<WWW::Forgejo::Role::HTTP>, which provides the raw verbs C<get>,
C<post>, C<put>, C<patch> and C<delete> (JSON in, decoded JSON out, C<croak> on
a non-2xx response). On top of that the API is split into controllers, reached
through the methods below:

  $forgejo->misc            WWW::Forgejo::API::Misc
  $forgejo->users           WWW::Forgejo::API::Users
  $forgejo->current_user    WWW::Forgejo::API::CurrentUser
  $forgejo->repos           WWW::Forgejo::API::Repos
  $forgejo->orgs            WWW::Forgejo::API::Orgs
  $forgejo->teams           WWW::Forgejo::API::Teams
  $forgejo->notifications   WWW::Forgejo::API::Notifications
  $forgejo->packages        WWW::Forgejo::API::Packages
  $forgejo->admin           WWW::Forgejo::API::Admin
  $forgejo->activitypub     WWW::Forgejo::API::ActivityPub

Everything that lives inside a repository or an organization hangs off the
entity returned for it: C<< $forgejo->repos->get($owner, $name) >> returns a
L<WWW::Forgejo::Entity::Repo> whose attributes (C<issues>, C<pulls>,
C<branches>, C<releases>, C<contents>, C<hooks>, ...) are the
C<WWW::Forgejo::API::Repo::*> controllers for that repository, and
C<< $forgejo->orgs->get($name) >> returns a L<WWW::Forgejo::Entity::Org> with
the C<WWW::Forgejo::API::Org::*> controllers.

Depending on the method, results are either C<WWW::Forgejo::Entity::*> objects
or the decoded JSON response as plain Perl data; the documentation of each
controller says which. An entity always keeps the complete decoded structure
in its C<data> attribute.

Controllers and entities keep a reference to the client they came from, so
they stay usable for as long as they live, also when the client variable itself
has gone out of scope. The client keeps no reference back; every call of a
controller method above returns a new, cheap controller object.

The HTTP transport is pluggable: the C<io> attribute (from
L<WWW::Forgejo::Role::HTTP>) takes any object consuming
L<WWW::Forgejo::Role::IO> and defaults to L<WWW::Forgejo::LWPIO>. That default
uses L<LWP::UserAgent>, which needs L<LWP::Protocol::https> for C<https> URLs;
it is a recommended, not a required prerequisite, because many instances are
reached over plain HTTP inside a private network.
C<Net::Async::Forgejo> builds its asynchronous client on the same request
building and response parsing.

=head1 ENVIRONMENT

=over 4

=item C<FORGEJO_URL>

Instance URL, used when no C<url> is passed to the constructor.

=item C<FORGEJO_TOKEN>

Access token, used when no C<token> is passed to the constructor.

=back

=head1 SEE ALSO

L<WWW::Forgejo::Role::HTTP>, L<WWW::Forgejo::Entity>,
L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::Org>,
L<https://forgejo.org>

=cut
