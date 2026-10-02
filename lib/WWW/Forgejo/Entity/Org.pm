# ABSTRACT: Forgejo Organization Entity
# PODNAME: WWW::Forgejo::Entity::Org

use strict;
use warnings;

package WWW::Forgejo::Entity::Org;

use Moo;
extends 'WWW::Forgejo::Entity';
use Carp qw(croak);
use WWW::Forgejo::API::Org::Members;
use WWW::Forgejo::API::Org::Teams;
use WWW::Forgejo::API::Org::Hooks;
use WWW::Forgejo::API::Org::Labels;
use WWW::Forgejo::API::Org::Actions;
use WWW::Forgejo::API::Org::Quota;
use WWW::Forgejo::API::Org::BlockedUsers;
use namespace::clean;

our $VERSION = '0.001';

=method name

    my $name = $org->name;

The name of the organization: the C<name> field of the organization data, or
its deprecated twin C<username> when C<name> is missing. L</update>,
L</delete>, L</repos> and the per-organization controllers address the
organization by this name.

=cut

sub name { $_[0]->data->{name} // $_[0]->data->{username} }

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
        owner  => $self->name,
    );
}

=method teams

    my $teams_api = $org->teams;

Get the teams API for this organization.

=cut

sub teams {
    my ($self) = @_;
    return WWW::Forgejo::API::Org::Teams->new(
        client => $self->client,
        owner  => $self->name,
    );
}

=method repos

    my $repos = $org->repos;

List the repositories of this organization. Returns an arrayref of
L<WWW::Forgejo::Entity::Repo> objects, see
L<WWW::Forgejo::API::Repos/list_for_org>. Croaks if the organization data
has no C<name>.

=cut

sub repos {
    my ($self) = @_;
    my $name = $self->name;
    croak "Organization name required" unless $name;
    return $self->client->repos->list_for_org($name);
}

=method hooks

    my $hooks_api = $org->hooks;

Get the hooks API for this organization.

=cut

sub hooks {
    my ($self) = @_;
    return WWW::Forgejo::API::Org::Hooks->new(
        client => $self->client,
        owner  => $self->name,
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
        owner  => $self->name,
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
        owner  => $self->name,
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
        owner  => $self->name,
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
        owner  => $self->name,
    );
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $org     = $forgejo->orgs->get('my-org');

    print $org->name, "\n";

    my $teams = $org->teams->list;
    my $repos = $org->repos;

    $org->update(description => 'New description');

=head1 DESCRIPTION

An organization as returned by L<WWW::Forgejo::API::Orgs>. Besides the decoded
organization data (L<data|WWW::Forgejo::Entity/data>) it gives access to the
per-organization controllers (C<WWW::Forgejo::API::Org::*>).

Those controllers are created with the L</name> of the organization as their
C<owner>.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Orgs>, L<WWW::Forgejo::API::Org::Actions>, L<WWW::Forgejo::API::Org::BlockedUsers>, L<WWW::Forgejo::API::Org::Hooks>, L<WWW::Forgejo::API::Org::Labels>, L<WWW::Forgejo::API::Org::Members>, L<WWW::Forgejo::API::Org::Quota>, L<WWW::Forgejo::API::Org::Teams>, L<WWW::Forgejo::Entity>

=cut
