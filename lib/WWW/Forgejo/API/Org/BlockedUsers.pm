# ABSTRACT: Forgejo Organization Blocked Users API
# PODNAME: WWW::Forgejo::API::Org::BlockedUsers

use strict;
use warnings;

package WWW::Forgejo::API::Org::BlockedUsers;

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

    my $blocked = $org->blocked_users->list($org_name);
    my $blocked = $org->blocked_users->list;    # organization taken from $org

List the users blocked by an organization (C<GET /orgs/{org}/list_blocked>).
Further named arguments are sent as the query string of the request.

=cut

sub list {
    my ($self, $org, %params) = @_;
    return $self->client->get($self->_org_path($org, 'list_blocked'), params => \%params);
}

=method block

    $org->blocked_users->block($org_name, $username);

Block a user from the organization (C<PUT /orgs/{org}/block/{username}>).

=cut

sub block {
    my ($self, $org, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->put($self->_org_path($org, 'block', uri_escape($username)));
}

=method unblock

    $org->blocked_users->unblock($org_name, $username);

Unblock a user (C<PUT /orgs/{org}/unblock/{username}>).

=cut

sub unblock {
    my ($self, $org, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->put($self->_org_path($org, 'unblock', uri_escape($username)));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo  = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $org_name = 'my-org';
    my $org      = $forgejo->orgs->get($org_name);

    my $blocked = $org->blocked_users->list($org_name);
    $blocked = $org->blocked_users->list;    # organization taken from $org

    $org->blocked_users->block($org_name, $username);

    $org->blocked_users->unblock($org_name, $username);

=head1 DESCRIPTION

Controller for the C</orgs/{org}/list_blocked>, C</orgs/{org}/block> and C</orgs/{org}/unblock> endpoints. It is obtained
through L<WWW::Forgejo::Entity::Org/blocked_users>.

The methods take the organization name as their first argument. When it is
left out or undefined, the organization the controller was obtained from
(L</owner>) is used.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Org>, L<WWW::Forgejo::API::Orgs>, L<WWW::Forgejo>

=cut
