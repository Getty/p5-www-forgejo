# ABSTRACT: Forgejo Organization Entity
# PODNAME: WWW::Forgejo::Entity::Org

use strict;
use warnings;

package WWW::Forgejo::Entity::Org;

use Moo;
use Log::Any qw($log);
use Carp qw(croak);
use WWW::Forgejo::API::Org::Members;
use WWW::Forgejo::API::Org::Teams;
use WWW::Forgejo::API::Org::Hooks;
use WWW::Forgejo::API::Org::Labels;
use WWW::Forgejo::API::Org::Actions;
use WWW::Forgejo::API::Org::Quota;
use WWW::Forgejo::API::Org::BlockedUsers;

=attr client

The WWW::Forgejo client instance (weaker_ref to avoid cycles).

=cut

has client => (
    is       => 'ro',
    weak_ref => 1,
    required => 1,
);

=attr data

The raw data hashref from the API response.

=cut

has data => (
    is       => 'ro',
    required => 1,
);

=method name

    my $name = $org->name;

Get the organization name.

=cut

sub name { shift->data->{name} }

=method update

    $org->update(description => 'New description');

Update the organization data.

=cut

sub update {
    my ($self, %params) = @_;
    my $name = $self->name;
    croak "Organization name required for update" unless $name;
    my $new_data = $self->client->orgs->edit($name, %params);
    $self->{data} = $new_data->{data} // $new_data;
    return $self;
}

=method delete

    $org->delete;

Delete the organization.

=cut

sub delete {
    my ($self) = @_;
    my $name = $self->name;
    croak "Organization name required for delete" unless $name;
    return $self->client->orgs->delete($name);
}

=method members

    my $members_api = $org->members;

Get the members API for this organization.

=cut

sub members {
    my ($self) = @_;
    return WWW::Forgejo::API::Org::Members->new(
        client => $self->client,
        owner  => $self->data->{username},
    );
}

=method public_members

    my $public_members_api = $org->public_members;

Get the public members API for this organization.

=cut

sub public_members {
    my ($self) = @_;
    return $self->members;  # Uses same endpoint, username determines public vs all
}

=method teams

    my $teams_api = $org->teams;

Get the teams API for this organization.

=cut

sub teams {
    my ($self) = @_;
    return WWW::Forgejo::API::Org::Teams->new(
        client => $self->client,
        owner  => $self->data->{username},
    );
}

=method repos

    my $repos = $org->repos;

Get repositories in this organization.
Note: This returns the raw API response. Repos entity may be added later.

=cut

sub repos {
    my ($self) = @_;
    my $name = $self->name;
    croak "Organization name required" unless $name;
    require WWW::Forgejo::API::Repos;
    return WWW::Forgejo::API::Repos->new(client => $self->client)->list_for_org($name);
}

=method hooks

    my $hooks_api = $org->hooks;

Get the hooks API for this organization.

=cut

sub hooks {
    my ($self) = @_;
    return WWW::Forgejo::API::Org::Hooks->new(
        client => $self->client,
        owner  => $self->data->{username},
    );
}

=method labels

    my $labels_api = $org->labels;

Get the labels API for this organization.

=cut

sub labels {
    my ($self) = @_;
    return WWW::Forgejo::API::Org::Labels->new(
        client => $self->client,
        owner  => $self->data->{username},
    );
}

=method quota

    my $quota_api = $org->quota;

Get the quota API for this organization.

=cut

sub quota {
    my ($self) = @_;
    return WWW::Forgejo::API::Org::Quota->new(
        client => $self->client,
        owner  => $self->data->{username},
    );
}

=method actions

    my $actions_api = $org->actions;

Get the actions API for this organization.

=cut

sub actions {
    my ($self) = @_;
    return WWW::Forgejo::API::Org::Actions->new(
        client => $self->client,
        owner  => $self->data->{username},
    );
}

=method blocked_users

    my $blocked_api = $org->blocked_users;

Get the blocked users API for this organization.

=cut

sub blocked_users {
    my ($self) = @_;
    return WWW::Forgejo::API::Org::BlockedUsers->new(
        client => $self->client,
        owner  => $self->data->{username},
    );
}

1;