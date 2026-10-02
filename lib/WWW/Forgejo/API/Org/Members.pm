# ABSTRACT: Forgejo Organization Members API
# PODNAME: WWW::Forgejo::API::Org::Members

use strict;
use warnings;

package WWW::Forgejo::API::Org::Members;

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

    my $members = $org->members->list($org_name);
    my $members = $org->members->list;    # organization taken from $org

List all members of an organization. Further named arguments are sent as the
query string of the request.

=cut

sub list {
    my ($self, $org, %params) = @_;
    return $self->client->get($self->_org_path($org, 'members'), params => \%params);
}

=method check

    my $is_member = $org->members->check($org_name, $username);

Check whether a user is a member of the organization (C<GET
/orgs/{org}/members/{username}>). Returns true or false.

=cut

sub check {
    my ($self, $org, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->check($self->_org_path($org, 'members', uri_escape($username)));
}

=method remove

    $org->members->remove($org_name, $username);

Remove a member from the organization.

=cut

sub remove {
    my ($self, $org, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->delete($self->_org_path($org, 'members', uri_escape($username)));
}

=method list_public

    my $members = $org->members->list_public($org_name);

List the public members of an organization. Further named arguments are sent
as the query string of the request.

=cut

sub list_public {
    my ($self, $org, %params) = @_;
    return $self->client->get($self->_org_path($org, 'public_members'), params => \%params);
}

=method check_public

    my $is_public = $org->members->check_public($org_name, $username);

Check whether a user is a public member of the organization (C<GET
/orgs/{org}/public_members/{username}>). Returns true or false.

=cut

sub check_public {
    my ($self, $org, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->check($self->_org_path($org, 'public_members', uri_escape($username)));
}

=method publicize

    $org->members->publicize($org_name, $username);

Make the membership of a user public.

=cut

sub publicize {
    my ($self, $org, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->put($self->_org_path($org, 'public_members', uri_escape($username)));
}

=method conceal

    $org->members->conceal($org_name, $username);

Make the membership of a user private.

=cut

sub conceal {
    my ($self, $org, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->delete($self->_org_path($org, 'public_members', uri_escape($username)));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo  = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $org_name = 'my-org';
    my $org      = $forgejo->orgs->get($org_name);

    my $members = $org->members->list($org_name);
    $members = $org->members->list;    # organization taken from $org

    my $is_member = $org->members->check($org_name, $username);

    $org->members->remove($org_name, $username);

=head1 DESCRIPTION

Controller for the C</orgs/{org}/members> and C</orgs/{org}/public_members> endpoints. It is obtained
through L<WWW::Forgejo::Entity::Org/members>.

The methods take the organization name as their first argument. When it is
left out or undefined, the organization the controller was obtained from
(L</owner>) is used.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Org>, L<WWW::Forgejo::API::Orgs>, L<WWW::Forgejo>

=cut
