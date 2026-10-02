# ABSTRACT: Forgejo Organization Labels API
# PODNAME: WWW::Forgejo::API::Org::Labels

use strict;
use warnings;

package WWW::Forgejo::API::Org::Labels;

use Moo;
use Carp qw(croak);
use URI::Escape qw(uri_escape);
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);
has owner  => (is => 'ro', predicate => 'has_owner');

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=attr owner

Name of the organization this controller was created for. Optional; when the
controller comes from a L<WWW::Forgejo::Entity::Org> it is the
L<name|WWW::Forgejo::Entity::Org/name> of that organization. It is used whenever a method is called without an
organization name (C<undef> as first argument, or no arguments at all).
L</has_owner> tells whether it was passed to the constructor.

=method has_owner

    my $bool = $controller->has_owner;

True when an L</owner> was passed to the constructor.

=cut

# /orgs/{org}/... for the given organization, falling back to the owner.
sub _org_path {
    my ($self, $org, @path) = @_;
    $org = $self->owner unless defined $org && length $org;
    croak "Organization name required" unless defined $org && length $org;
    return join '/', '/orgs', uri_escape($org), @path;
}

=method list

    my $labels = $org->labels->list($org_name);
    my $labels = $org->labels->list;    # organization taken from $org

List all labels of an organization. Further named arguments are sent as the
query string of the request.

=cut

sub list {
    my ($self, $org, %params) = @_;
    return $self->client->get($self->_org_path($org, 'labels'), params => \%params);
}

=method get

    my $label = $org->labels->get($org_name, $label_id);

Get a specific label by ID.

=cut

sub get {
    my ($self, $org, $label_id) = @_;
    croak "Label ID required" unless defined $label_id && length $label_id;
    return $self->client->get($self->_org_path($org, 'labels', uri_escape($label_id)));
}

=method create

    my $label = $org->labels->create($org_name,
        name        => 'bug',
        color       => 'ff0000',
        description => 'Bug reports',
    );

Create a new label; the API requires C<name> and C<color>. The key/value
pairs are sent as the JSON body.

=cut

sub create {
    my ($self, $org, %params) = @_;
    return $self->client->post($self->_org_path($org, 'labels'), \%params);
}

=method edit

    my $label = $org->labels->edit($org_name, $label_id, color => '00ff00');

Edit a label (C<PATCH /orgs/{org}/labels/{id}>). The key/value pairs are
sent as the JSON body.

=cut

sub edit {
    my ($self, $org, $label_id, %params) = @_;
    croak "Label ID required" unless defined $label_id && length $label_id;
    return $self->client->patch($self->_org_path($org, 'labels', uri_escape($label_id)), \%params);
}

=method delete

    $org->labels->delete($org_name, $label_id);

Delete a label.

=cut

sub delete {
    my ($self, $org, $label_id) = @_;
    croak "Label ID required" unless defined $label_id && length $label_id;
    return $self->client->delete($self->_org_path($org, 'labels', uri_escape($label_id)));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo  = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $org_name = 'my-org';
    my $org      = $forgejo->orgs->get($org_name);

    my $labels = $org->labels->list($org_name);
    $labels = $org->labels->list;    # organization taken from $org

    my $label = $org->labels->get($org_name, $label_id);

    $label = $org->labels->create($org_name,
        name        => 'bug',
        color       => 'ff0000',
        description => 'Bug reports',
    );

=head1 DESCRIPTION

Controller for the C</orgs/{org}/labels> endpoints. It is obtained
through L<WWW::Forgejo::Entity::Org/labels>.

The methods take the organization name as their first argument. When it is
left out or undefined, the organization the controller was obtained from
(L</owner>) is used.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Org>, L<WWW::Forgejo::API::Orgs>, L<WWW::Forgejo>

=cut
