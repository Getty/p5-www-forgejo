# ABSTRACT: Forgejo Teams API
# PODNAME: WWW::Forgejo::API::Teams

use strict;
use warnings;

package WWW::Forgejo::API::Teams;

use Moo;
use Log::Any qw($log);
use Carp qw(croak);
use WWW::Forgejo::Entity::Team;

has client => (
    is       => 'ro',
    init_arg => 'client',
);


=method list

    my $teams = $api->list;

List all teams the authenticated user has access to.

=cut

sub list {
    my ($self) = @_;
    my $data = $self->client->get('/teams');
    return [ map { WWW::Forgejo::Entity::Team->new(client => $self->client, data => $_) } @{$data} ];
}

=method get

    my $team = $api->get($team_id);

Get a specific team by ID.

=cut

sub get {
    my ($self, $team_id) = @_;
    croak "Team ID required" unless $team_id;
    my $data = $self->client->get("/teams/$team_id");
    return WWW::Forgejo::Entity::Team->new(client => $self->client, data => $data);
}

=method create

    my $team = $api->create(
        name => $team_name,
        org => $org_name,
        permission => 'push',
    );

Create a new team.

=cut

sub create {
    my ($self, %params) = @_;
    croak "Team name required" unless $params{name};
    croak "Organization name required" unless $params{org};
    my $data = $self->client->post('/teams', \%params);
    return WWW::Forgejo::Entity::Team->new(client => $self->client, data => $data);
}

=method edit

    my $team = $api->edit($team_id, permission => 'admin');

Edit a team.

=cut

sub edit {
    my ($self, $team_id, %params) = @_;
    croak "Team ID required" unless $team_id;
    my $data = $self->client->post("/teams/$team_id", \%params);
    return WWW::Forgejo::Entity::Team->new(client => $self->client, data => $data);
}

=method delete

    $api->delete($team_id);

Delete a team.

=cut

sub delete {
    my ($self, $team_id) = @_;
    croak "Team ID required" unless $team_id;
    return $self->client->delete("/teams/$team_id");
}

=method list_members

    my $members = $api->list_members($team_id);

List all members of a team.

=cut

sub list_members {
    my ($self, $team_id) = @_;
    croak "Team ID required" unless $team_id;
    return $self->client->get("/teams/$team_id/members");
}

=method add_member

    $api->add_member($team_id, $username);

Add a member to a team.

=cut

sub add_member {
    my ($self, $team_id, $username) = @_;
    croak "Team ID required" unless $team_id;
    croak "Username required" unless $username;
    return $self->client->put("/teams/$team_id/members/$username", {});
}

=method remove_member

    $api->remove_member($team_id, $username);

Remove a member from a team.

=cut

sub remove_member {
    my ($self, $team_id, $username) = @_;
    croak "Team ID required" unless $team_id;
    croak "Username required" unless $username;
    return $self->client->delete("/teams/$team_id/members/$username");
}

=method list_repos

    my $repos = $api->list_repos($team_id);

List all repositories a team has access to.

=cut

sub list_repos {
    my ($self, $team_id) = @_;
    croak "Team ID required" unless $team_id;
    return $self->client->get("/teams/$team_id/repos");
}

=method add_repo

    $api->add_repo($team_id, $org, $repo);

Add a repository to a team.

=cut

sub add_repo {
    my ($self, $team_id, $org, $repo) = @_;
    croak "Team ID required" unless $team_id;
    croak "Organization name required" unless $org;
    croak "Repository name required" unless $repo;
    return $self->client->put("/teams/$team_id/repos/$org/$repo", {});
}

=method remove_repo

    $api->remove_repo($team_id, $org, $repo);

Remove a repository from a team.

=cut

sub remove_repo {
    my ($self, $team_id, $org, $repo) = @_;
    croak "Team ID required" unless $team_id;
    croak "Organization name required" unless $org;
    croak "Repository name required" unless $repo;
    return $self->client->delete("/teams/$team_id/repos/$org/$repo");
}

1;