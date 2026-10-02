# ABSTRACT: Forgejo Organization Quota API
# PODNAME: WWW::Forgejo::API::Org::Quota

use strict;
use warnings;

package WWW::Forgejo::API::Org::Quota;

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

=method get

    my $quota = $org->quota->get($org_name);
    my $quota = $org->quota->get;    # organization taken from $org

Get the quota information of an organization.

=cut

sub get {
    my ($self, $org) = @_;
    return $self->client->get($self->_org_path($org, 'quota'));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo  = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $org_name = 'my-org';
    my $org      = $forgejo->orgs->get($org_name);

    my $quota = $org->quota->get($org_name);
    $quota = $org->quota->get;    # organization taken from $org

=head1 DESCRIPTION

Controller for the C</orgs/{org}/quota> endpoints. It is obtained
through L<WWW::Forgejo::Entity::Org/quota>.

The methods take the organization name as their first argument. When it is
left out or undefined, the organization the controller was obtained from
(L</owner>) is used.

The API offers no call to change the quota of an organization here; quota
groups are managed through L<WWW::Forgejo::API::Admin::Quota>.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Org>, L<WWW::Forgejo::API::Orgs>,
L<WWW::Forgejo::API::Admin::Quota>, L<WWW::Forgejo>

=cut
