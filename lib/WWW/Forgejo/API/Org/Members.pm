# ABSTRACT: Forgejo Organization Members API
# PODNAME: WWW::Forgejo::API::Org::Members

use strict;
use warnings;

package WWW::Forgejo::API::Org::Members;

use Moo;
use Carp qw(croak);
use WWW::Forgejo::URL qw( escape_component );
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);
has owner  => (is => 'ro', predicate => 'has_owner');

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=attr owner

Name of the organization this controller addresses. It is the
L<name|WWW::Forgejo::Entity::Org/name> of the organization the controller was
obtained from, and every method sends its request to it. A controller without
an owner croaks with C<Organization name required> when a method is called.
L</has_owner> tells whether it was passed to the constructor.

=method has_owner

    my $bool = $controller->has_owner;

True when an L</owner> was passed to the constructor.

=cut

# /orgs/{org}/... for the organization this controller is bound to.
sub _org_path {
    my ($self, @path) = @_;
    my $org = $self->owner;
    croak "Organization name required" unless defined $org && length $org;
    return join '/', '/orgs', escape_component($org), @path;
}

=method list

    my $members = $org->members->list;

List all members of an organization. Further named arguments are sent as the
query string of the request.

=cut

sub list {
    my ($self, %params) = @_;
    return $self->client->get($self->_org_path('members'), params => \%params);
}

=method check

    my $is_member = $org->members->check($username);

Check whether a user is a member of the organization (C<GET
/orgs/{org}/members/{username}>). Returns true or false.

=cut

sub check {
    my ($self, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->check($self->_org_path('members', escape_component($username)));
}

=method remove

    $org->members->remove($username);

Remove a member from the organization.

=cut

sub remove {
    my ($self, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->delete($self->_org_path('members', escape_component($username)));
}

=method list_public

    my $members = $org->members->list_public;

List the public members of an organization. Further named arguments are sent
as the query string of the request.

=cut

sub list_public {
    my ($self, %params) = @_;
    return $self->client->get($self->_org_path('public_members'), params => \%params);
}

=method check_public

    my $is_public = $org->members->check_public($username);

Check whether a user is a public member of the organization (C<GET
/orgs/{org}/public_members/{username}>). Returns true or false.

=cut

sub check_public {
    my ($self, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->check($self->_org_path('public_members', escape_component($username)));
}

=method publicize

    $org->members->publicize($username);

Make the membership of a user public.

=cut

sub publicize {
    my ($self, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->put($self->_org_path('public_members', escape_component($username)));
}

=method conceal

    $org->members->conceal($username);

Make the membership of a user private.

=cut

sub conceal {
    my ($self, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->delete($self->_org_path('public_members', escape_component($username)));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo  = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $org_name = 'my-org';
    my $org      = $forgejo->orgs->get($org_name);

    my $members = $org->members->list;

    my $is_member = $org->members->check($username);

    $org->members->remove($username);

=head1 DESCRIPTION

Controller for the C</orgs/{org}/members> and C</orgs/{org}/public_members> endpoints. It is obtained
through L<WWW::Forgejo::Entity::Org/members>.

The controller is bound to one organization: every method sends its request to
the organization the controller was obtained from (L</owner>). There is no
organization argument to pass.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Org>, L<WWW::Forgejo::API::Orgs>, L<WWW::Forgejo>

=cut
