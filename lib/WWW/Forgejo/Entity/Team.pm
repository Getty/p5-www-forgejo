# ABSTRACT: Forgejo Team Entity
# PODNAME: WWW::Forgejo::Entity::Team

use strict;
use warnings;

package WWW::Forgejo::Entity::Team;

use Moo;
extends 'WWW::Forgejo::Entity';
use Log::Any qw($log);
use Carp qw(croak);

=method id

    my $id = $team->id;

Get the team ID.

=cut

sub id { shift->data->{id} }

=method name

    my $name = $team->name;

Get the team name.

=cut

sub name { shift->data->{name} }

=method update

    $team->update(permission => 'admin');

Update the team data.

=cut

sub update {
    my ($self, %params) = @_;
    my $id = $self->id;
    croak "Team ID required for update" unless $id;
    my $new_data = $self->client->teams->edit($id, %params);
    $self->{data} = $new_data->{data} // $new_data;
    return $self;
}

=method delete

    $team->delete;

Delete the team.

=cut

sub delete {
    my ($self) = @_;
    my $id = $self->id;
    croak "Team ID required for delete" unless $id;
    return $self->client->teams->delete($id);
}

=method list_members

    my $members = $team->list_members;

List all members of this team.

=cut

sub list_members {
    my ($self) = @_;
    my $id = $self->id;
    croak "Team ID required" unless $id;
    return $self->client->teams->list_members($id);
}

=method add_member

    $team->add_member($username);

Add a member to this team.

=cut

sub add_member {
    my ($self, $username) = @_;
    my $id = $self->id;
    croak "Team ID required" unless $id;
    croak "Username required" unless $username;
    return $self->client->teams->add_member($id, $username);
}

=method remove_member

    $team->remove_member($username);

Remove a member from this team.

=cut

sub remove_member {
    my ($self, $username) = @_;
    my $id = $self->id;
    croak "Team ID required" unless $id;
    croak "Username required" unless $username;
    return $self->client->teams->remove_member($id, $username);
}

=method list_repos

    my $repos = $team->list_repos;

List all repositories this team has access to.

=cut

sub list_repos {
    my ($self) = @_;
    my $id = $self->id;
    croak "Team ID required" unless $id;
    return $self->client->teams->list_repos($id);
}

=method add_repo

    $team->add_repo($org, $repo);

Add a repository to this team.

=cut

sub add_repo {
    my ($self, $org, $repo) = @_;
    my $id = $self->id;
    croak "Team ID required" unless $id;
    croak "Organization name required" unless $org;
    croak "Repository name required" unless $repo;
    return $self->client->teams->add_repo($id, $org, $repo);
}

=method remove_repo

    $team->remove_repo($org, $repo);

Remove a repository from this team.

=cut

sub remove_repo {
    my ($self, $org, $repo) = @_;
    my $id = $self->id;
    croak "Team ID required" unless $id;
    croak "Organization name required" unless $org;
    croak "Repository name required" unless $repo;
    return $self->client->teams->remove_repo($id, $org, $repo);
}

1;