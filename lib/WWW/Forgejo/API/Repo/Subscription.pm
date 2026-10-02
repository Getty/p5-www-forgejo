# ABSTRACT: Forgejo Repo Subscription API
# PODNAME: WWW::Forgejo::API::Repo::Subscription

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Subscription;

use Moo;
use URI::Escape qw(uri_escape);
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);
has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=attr owner

Owner (user or organization name) of the repository this controller works on.
Required.

=attr repo

Name of the repository this controller works on. Required.

=cut

# /repos/{owner}/{repo}/... of the repository this controller is bound to.
sub _repo_path {
    my ($self, @path) = @_;
    return join '/', '/repos', uri_escape($self->owner), uri_escape($self->repo), @path;
}

sub _path_for {
    my ($self, @path) = @_;
    return $self->_repo_path('subscription', @path);
}

=method get

    my $sub = $repo->subscription->get;

Get the watch state of the authenticated user for the repository. Croaks when
the user is not watching it, as the API answers that with C<404>.

=cut

sub get {
    my ($self) = @_;
    return $self->client->get($self->_path_for);
}

=method subscribe

    my $sub = $repo->subscription->subscribe;

Watch the repository. Returns the resulting watch state.

=cut

sub subscribe {
    my ($self) = @_;
    return $self->client->put($self->_path_for);
}

=method unsubscribe

    $repo->subscription->unsubscribe;

Stop watching the repository.

=cut

sub unsubscribe {
    my ($self) = @_;
    $self->client->delete($self->_path_for);
    return;
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my $sub = $repo->subscription->get;

    $repo->subscription->subscribe;

    $repo->subscription->unsubscribe;

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/subscription> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/subscription>, which binds it to
that repository; every method then addresses that repository.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo>

=cut
