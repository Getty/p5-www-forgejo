# ABSTRACT: Forgejo Organization Teams API
# PODNAME: WWW::Forgejo::API::Org::Teams

use strict;
use warnings;

package WWW::Forgejo::API::Org::Teams;

use Moo;
use Log::Any qw($log);
use Carp qw(croak);

has client => (is => 'ro', init_arg => 'client');
has owner  => (is => 'ro', init_arg => 'owner', predicate => 'has_owner');

=method list

    my $teams = $api->list($org);
    my $teams = $org->teams->list;  # when called from org entity

List all teams for an organization.

=cut

sub list {
    my ($self, $org) = @_;
    $org ||= $self->owner if $self->has_owner;
    croak "Organization name required" unless $org;
    return $self->{client}->get("/orgs/$org/teams");
}

=method get

    my $team = $api->get($org, $team_id);

Get a specific team by ID.

=cut

sub get {
    my ($self, $org, $team_id) = @_;
    croak "Organization name required" unless $org;
    croak "Team ID required" unless $team_id;
    return $self->{client}->get("/orgs/$org/teams/$team_id");
}

=method search

    my $teams = $api->search($query);

Search teams across the Forgejo instance.

=cut

sub search {
    my ($self, %params) = @_;
    croak "Organization name required" unless $params{org};
    return $self->{client}->get("/orgs/$params{org}/teams/search", params => \%params);
}

=method create

    my $team = $api->create($org, name => 'Developers', permission => 'push');

Create a new team.

=cut

sub create {
    my ($self, $org, %params) = @_;
    croak "Organization name required" unless $org;
    croak "Team name required" unless $params{name};
    return $self->{client}->post("/orgs/$org/teams", \%params);
}

=method edit

    my $team = $api->edit($org, $team_id, permission => 'admin');

Edit a team.

=cut

sub edit {
    my ($self, $org, $team_id, %params) = @_;
    croak "Organization name required" unless $org;
    croak "Team ID required" unless $team_id;
    return $self->{client}->patch("/orgs/$org/teams/$team_id", \%params);
}

=method delete

    $api->delete($org, $team_id);

Delete a team.

=cut

sub delete {
    my ($self, $org, $team_id) = @_;
    croak "Organization name required" unless $org;
    croak "Team ID required" unless $team_id;
    return $self->{client}->delete("/orgs/$org/teams/$team_id");
}

=method list_members

    my $members = $api->list_members($org, $team_id);

List all members of a team.

=cut

sub list_members {
    my ($self, $org, $team_id) = @_;
    croak "Organization name required" unless $org;
    croak "Team ID required" unless $team_id;
    return $self->{client}->get("/orgs/$org/teams/$team_id/members");
}

=method add_member

    $api->add_member($org, $team_id, $username);

Add a member to a team.

=cut

sub add_member {
    my ($self, $org, $team_id, $username) = @_;
    croak "Organization name required" unless $org;
    croak "Team ID required" unless $team_id;
    croak "Username required" unless $username;
    return $self->{client}->put("/orgs/$org/teams/$team_id/members/$username", {});
}

=method remove_member

    $api->remove_member($org, $team_id, $username);

Remove a member from a team.

=cut

sub remove_member {
    my ($self, $org, $team_id, $username) = @_;
    croak "Organization name required" unless $org;
    croak "Team ID required" unless $team_id;
    croak "Username required" unless $username;
    return $self->{client}->delete("/orgs/$org/teams/$team_id/members/$username");
}

=method list_repos

    my $repos = $api->list_repos($org, $team_id);

List all repositories a team has access to.

=cut

sub list_repos {
    my ($self, $org, $team_id) = @_;
    croak "Organization name required" unless $org;
    croak "Team ID required" unless $team_id;
    return $self->{client}->get("/orgs/$org/teams/$team_id/repos");
}

=method add_repo

    $api->add_repo($org, $team_id, $repo);

Add a repository to a team.

=cut

sub add_repo {
    my ($self, $org, $team_id, $repo) = @_;
    croak "Organization name required" unless $org;
    croak "Team ID required" unless $team_id;
    croak "Repository name required" unless $repo;
    return $self->{client}->put("/orgs/$org/teams/$team_id/repos/$repo", {});
}

=method remove_repo

    $api->remove_repo($org, $team_id, $repo);

Remove a repository from a team.

=cut

sub remove_repo {
    my ($self, $org, $team_id, $repo) = @_;
    croak "Organization name required" unless $org;
    croak "Team ID required" unless $team_id;
    croak "Repository name required" unless $repo;
    return $self->{client}->delete("/orgs/$org/teams/$team_id/repos/$repo");
}

1;