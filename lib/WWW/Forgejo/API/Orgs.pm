# ABSTRACT: Forgejo Organizations API
# PODNAME: WWW::Forgejo::API::Orgs

use strict;
use warnings;

package WWW::Forgejo::API::Orgs;

use Moo;
use Carp qw(croak);
use URI::Escape qw(uri_escape);
use WWW::Forgejo::Entity::Org;
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

sub _org {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::Org->new(client => $self->client, data => $data);
}

=method list

    my $orgs = $forgejo->orgs->list;
    my $orgs = $forgejo->orgs->list(limit => 50);

List the organizations of the instance (C<GET /orgs>). Named arguments are sent
as the query string of the request. Returns an arrayref of
L<WWW::Forgejo::Entity::Org> objects.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get('/orgs', params => \%params);
    return [ map { $self->_org($_) } @{$data} ];
}

=method get

    my $org = $forgejo->orgs->get($org_name);

Get a specific organization by name. Returns a L<WWW::Forgejo::Entity::Org>.

=cut

sub get {
    my ($self, $org) = @_;
    croak "Organization name required" unless defined $org && length $org;
    return $self->_org($self->client->get("/orgs/" . uri_escape($org)));
}

=method create

    my $org = $forgejo->orgs->create(
        username    => 'my-org',
        description => 'My organization',
    );

Create a new organization (C<POST /orgs>). The key/value pairs are sent as the
JSON body; C<username>, the name of the organization, is required. Returns a
L<WWW::Forgejo::Entity::Org>.

=cut

sub create {
    my ($self, %params) = @_;
    croak "Organization username required" unless $params{username};
    return $self->_org($self->client->post('/orgs', \%params));
}

=method edit

    my $org = $forgejo->orgs->edit($org_name, description => 'Updated description');

Edit an organization (C<PATCH /orgs/{org}>). The key/value pairs are sent as the
JSON body. Returns a L<WWW::Forgejo::Entity::Org>.

=cut

sub edit {
    my ($self, $org, %params) = @_;
    croak "Organization name required" unless $org;
    return $self->_org($self->client->patch("/orgs/" . uri_escape($org), \%params));
}

=method delete

    $forgejo->orgs->delete($org_name);

Delete an organization.

=cut

sub delete {
    my ($self, $org) = @_;
    croak "Organization name required" unless $org;
    return $self->client->delete("/orgs/" . uri_escape($org));
}

=method rename

    $forgejo->orgs->rename($org_name, new_name => 'new-org-name');

Rename an organization (C<POST /orgs/{org}/rename>). C<new_name> is required.
Returns the decoded response.

=cut

sub rename {
    my ($self, $org, %params) = @_;
    croak "Organization name required" unless $org;
    croak "New name required" unless $params{new_name};
    return $self->client->post("/orgs/" . uri_escape($org) . "/rename", \%params);
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $org  = $forgejo->orgs->get('my-org');
    my $orgs = $forgejo->orgs->list;
    my $new  = $forgejo->orgs->create(username => 'another-org');

=head1 DESCRIPTION

The C</orgs> endpoints. Available as C<< $forgejo->orgs >>.

Organizations are returned as L<WWW::Forgejo::Entity::Org> objects (L</list>
returns an arrayref of them), which in turn give access to the
per-organization controllers (members, teams, hooks, labels, ...).

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Org>, L<WWW::Forgejo>

=cut
