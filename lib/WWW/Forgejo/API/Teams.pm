# ABSTRACT: Forgejo Teams API
# PODNAME: WWW::Forgejo::API::Teams

use strict;
use warnings;

package WWW::Forgejo::API::Teams;

use Moo;
use Carp qw(croak);
use URI::Escape qw(uri_escape);
use WWW::Forgejo::Entity::Team;
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

sub _team {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::Team->new(client => $self->client, data => $data);
}

sub _team_path {
    my ($self, $team_id, @path) = @_;
    croak "Team ID required" unless $team_id;
    return join '/', '/teams', uri_escape($team_id), @path;
}

=method get

    my $team = $forgejo->teams->get($team_id);

Get a specific team by ID. Returns a L<WWW::Forgejo::Entity::Team>.

=cut

sub get {
    my ($self, $team_id) = @_;
    return $self->_team($self->client->get($self->_team_path($team_id)));
}

=method create

    my $team = $forgejo->teams->create(
        org        => $org_name,
        name       => 'Developers',
        permission => 'write',
    );

Create a new team in an organization (C<POST /orgs/{org}/teams>). C<org> names
the organization and is not part of the request body; the other key/value
pairs are sent as the JSON body, C<name> is required. Returns a
L<WWW::Forgejo::Entity::Team>.

=cut

sub create {
    my ($self, %params) = @_;
    croak "Team name required" unless $params{name};
    my $org = delete $params{org};
    croak "Organization name required" unless $org;
    return $self->_team($self->client->post("/orgs/" . uri_escape($org) . "/teams", \%params));
}

=method edit

    my $team = $forgejo->teams->edit($team_id, permission => 'admin');

Edit a team (C<PATCH /teams/{id}>). The key/value pairs are sent as the JSON
body. Returns a L<WWW::Forgejo::Entity::Team>.

=cut

sub edit {
    my ($self, $team_id, %params) = @_;
    return $self->_team($self->client->patch($self->_team_path($team_id), \%params));
}

=method delete

    $forgejo->teams->delete($team_id);

Delete a team.

=cut

sub delete {
    my ($self, $team_id) = @_;
    return $self->client->delete($self->_team_path($team_id));
}

=method list_members

    my $members = $forgejo->teams->list_members($team_id);

List all members of a team. Further named arguments are sent as the query
string of the request.

=cut

sub list_members {
    my ($self, $team_id, %params) = @_;
    return $self->client->get($self->_team_path($team_id, 'members'), params => \%params);
}

=method add_member

    $forgejo->teams->add_member($team_id, $username);

Add a member to a team.

=cut

sub add_member {
    my ($self, $team_id, $username) = @_;
    croak "Username required" unless $username;
    return $self->client->put($self->_team_path($team_id, 'members', uri_escape($username)));
}

=method remove_member

    $forgejo->teams->remove_member($team_id, $username);

Remove a member from a team.

=cut

sub remove_member {
    my ($self, $team_id, $username) = @_;
    croak "Username required" unless $username;
    return $self->client->delete($self->_team_path($team_id, 'members', uri_escape($username)));
}

=method list_repos

    my $repos = $forgejo->teams->list_repos($team_id);

List all repositories a team has access to. Further named arguments are sent as
the query string of the request.

=cut

sub list_repos {
    my ($self, $team_id, %params) = @_;
    return $self->client->get($self->_team_path($team_id, 'repos'), params => \%params);
}

=method add_repo

    $forgejo->teams->add_repo($team_id, $org, $repo);

Add a repository to a team (C<PUT /teams/{id}/repos/{org}/{repo}>).

=cut

sub add_repo {
    my ($self, $team_id, $org, $repo) = @_;
    croak "Organization name required" unless $org;
    croak "Repository name required" unless $repo;
    return $self->client->put($self->_team_path($team_id, 'repos', uri_escape($org), uri_escape($repo)));
}

=method remove_repo

    $forgejo->teams->remove_repo($team_id, $org, $repo);

Remove a repository from a team.

=cut

sub remove_repo {
    my ($self, $team_id, $org, $repo) = @_;
    croak "Organization name required" unless $org;
    croak "Repository name required" unless $repo;
    return $self->client->delete($self->_team_path($team_id, 'repos', uri_escape($org), uri_escape($repo)));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $team = $forgejo->teams->get($team_id);
    my $new  = $forgejo->teams->create(org => 'my-org', name => 'Developers');

    $forgejo->teams->add_member($team_id, 'username');

=head1 DESCRIPTION

Teams addressed by their numeric ID (C</teams/{id}>), their members and their
repositories. Available as C<< $forgejo->teams >>.

The API has no call that lists all teams of the instance. The teams of one
organization are listed and searched through L<WWW::Forgejo::API::Org::Teams>,
the teams of the authenticated user through
L<WWW::Forgejo::API::CurrentUser/teams>.

Teams are returned as L<WWW::Forgejo::Entity::Team> objects; the member and
repository methods return the decoded JSON response.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Team>, L<WWW::Forgejo::API::Org::Teams>, L<WWW::Forgejo>

=cut
