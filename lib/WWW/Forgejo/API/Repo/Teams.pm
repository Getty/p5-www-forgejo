# ABSTRACT: Forgejo Repo Teams API
# PODNAME: WWW::Forgejo::API::Repo::Teams

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Teams;

use Moo;
use Carp qw(croak);
use WWW::Forgejo::URL qw( escape_component );
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
    return join '/', '/repos', escape_component($self->owner), escape_component($self->repo), @path;
}

sub _path_for {
    my ($self, @path) = @_;
    return $self->_repo_path('teams', @path);
}

=method list

    my $teams = $repo->teams->list;

List the teams that have access to the repository
(C<GET /repos/{owner}/{repo}/teams>). The teams are returned as plain
structures in an arrayref.

=cut

sub list {
    my ($self) = @_;
    my $data = $self->client->get($self->_path_for);
    return [@$data];
}

=method get

    my $team = $repo->teams->get($team_id);

Get one team that has access to the repository
(C<GET /repos/{owner}/{repo}/teams/{team}>). The team is returned as a plain
structure.

=cut

sub get {
    my ($self, $team_id) = @_;
    croak "Team ID required" unless defined $team_id && length $team_id;
    return $self->client->get($self->_path_for(escape_component($team_id)));
}

=method add

    $repo->teams->add($team_id);

Give a team access to the repository
(C<PUT /repos/{owner}/{repo}/teams/{team}>). Returns true.

=cut

sub add {
    my ($self, $team_id) = @_;
    croak "Team ID required" unless defined $team_id && length $team_id;
    $self->client->put($self->_path_for(escape_component($team_id)));
    return 1;
}

=method remove

    $repo->teams->remove($team_id);

Take the access of a team to the repository away
(C<DELETE /repos/{owner}/{repo}/teams/{team}>). Returns true.

=cut

sub remove {
    my ($self, $team_id) = @_;
    croak "Team ID required" unless defined $team_id && length $team_id;
    $self->client->delete($self->_path_for(escape_component($team_id)));
    return 1;
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my $teams = $repo->teams->list;

    $repo->teams->add($team_id);

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/teams> endpoints of one repository:
the teams that have access to it. It is obtained through
L<WWW::Forgejo::Entity::Repo/teams>, which binds it to that repository; every
method then addresses that repository.

Methods return the decoded JSON response as plain Perl data; the list of the
teams is returned as an arrayref.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo>

=cut
