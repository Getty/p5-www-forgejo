# ABSTRACT: Forgejo Organizations API
# PODNAME: WWW::Forgejo::API::Orgs

use strict;
use warnings;

package WWW::Forgejo::API::Orgs;

use Moo;
use Log::Any qw($log);
use Carp qw(croak);
use WWW::Forgejo::Entity::Org;

has client => (
    is       => 'ro',
    init_arg => 'client',
);

=method list

    my $orgs = $api->list;

List all organizations the authenticated user has access to.

=cut

sub list {
    my ($self) = @_;
    my $data = $self->{client}->get('/orgs');
    return [ map { WWW::Forgejo::Entity::Org->new(client => $self->client, data => $_) } @{$data} ];
}

=method get

    my $org = $api->get($org_name);

Get a specific organization by name.

=cut

sub get {
    my ($self, $org) = @_;
    croak "Organization name required" unless defined $org;
    my $data = $self->{client}->get("/orgs/$org");
    return WWW::Forgejo::Entity::Org->new(client => $self->client, data => $data);
}

=method create

    my $org = $api->create(
        name => $org_name,
        description => 'My organization',
    );

Create a new organization.

=cut

sub create {
    my ($self, %params) = @_;
    croak "Organization name required" unless $params{name};
    my $data = $self->{client}->post('/orgs', \%params);
    return WWW::Forgejo::Entity::Org->new(client => $self->client, data => $data);
}

=method edit

    my $org = $api->edit($org_name, description => 'Updated description');

Edit an organization.

=cut

sub edit {
    my ($self, $org, %params) = @_;
    croak "Organization name required" unless $org;
    my $data = $self->{client}->post("/orgs/$org", \%params);
    return WWW::Forgejo::Entity::Org->new(client => $self->client, data => $data);
}

=method delete

    $api->delete($org_name);

Delete an organization.

=cut

sub delete {
    my ($self, $org) = @_;
    croak "Organization name required" unless $org;
    return $self->{client}->delete("/orgs/$org");
}

=method rename

    my $org = $api->rename($org_name, new_name => 'new_org_name');

Rename an organization.

=cut

sub rename {
    my ($self, $org, %params) = @_;
    croak "Organization name required" unless $org;
    croak "New name required" unless $params{new_name};
    my $data = $self->{client}->post("/orgs/$org/rename", \%params);
    return WWW::Forgejo::Entity::Org->new(client => $self->client, data => $data);
}

1;