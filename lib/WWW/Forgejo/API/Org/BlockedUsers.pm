# ABSTRACT: Forgejo Organization Blocked Users API
# PODNAME: WWW::Forgejo::API::Org::BlockedUsers

use strict;
use warnings;

package WWW::Forgejo::API::Org::BlockedUsers;

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

    my $blocked = $org->blocked_users->list;

List the users blocked by an organization (C<GET /orgs/{org}/list_blocked>).
Further named arguments are sent as the query string of the request.

=cut

sub list {
    my ($self, %params) = @_;
    return $self->client->get($self->_org_path('list_blocked'), params => \%params);
}

=method block

    $org->blocked_users->block($username);

Block a user from the organization (C<PUT /orgs/{org}/block/{username}>).

=cut

sub block {
    my ($self, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->put($self->_org_path('block', escape_component($username)));
}

=method unblock

    $org->blocked_users->unblock($username);

Unblock a user (C<PUT /orgs/{org}/unblock/{username}>).

=cut

sub unblock {
    my ($self, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->put($self->_org_path('unblock', escape_component($username)));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo  = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $org_name = 'my-org';
    my $org      = $forgejo->orgs->get($org_name);

    my $blocked = $org->blocked_users->list;

    $org->blocked_users->block($username);

    $org->blocked_users->unblock($username);

=head1 DESCRIPTION

Controller for the C</orgs/{org}/list_blocked>, C</orgs/{org}/block> and C</orgs/{org}/unblock> endpoints. It is obtained
through L<WWW::Forgejo::Entity::Org/blocked_users>.

The controller is bound to one organization: every method sends its request to
the organization the controller was obtained from (L</owner>). There is no
organization argument to pass.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Org>, L<WWW::Forgejo::API::Orgs>, L<WWW::Forgejo>

=cut
