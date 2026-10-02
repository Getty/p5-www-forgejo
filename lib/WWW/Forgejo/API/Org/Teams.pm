# ABSTRACT: Forgejo Organization Teams API
# PODNAME: WWW::Forgejo::API::Org::Teams

use strict;
use warnings;

package WWW::Forgejo::API::Org::Teams;

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

    my $teams = $org->teams->list($org_name);
    my $teams = $org->teams->list;    # organization taken from $org

List all teams of an organization. Further named arguments are sent as the
query string of the request.

=cut

sub list {
    my ($self, $org, %params) = @_;
    return $self->client->get($self->_org_path($org, 'teams'), params => \%params);
}

=method search

    my $result = $org->teams->search($org_name, q => 'dev');

Search the teams of an organization (C<GET /orgs/{org}/teams/search>); C<q>
is the search term. Returns the decoded response. Further named arguments
are sent as the query string of the request.

=cut

sub search {
    my ($self, $org, %params) = @_;
    return $self->client->get($self->_org_path($org, 'teams', 'search'), params => \%params);
}

=method create

    my $team = $org->teams->create($org_name, name => 'Developers');

Create a new team in the organization; the API requires C<name>. The
key/value pairs are sent as the JSON body.

=cut

sub create {
    my ($self, $org, %params) = @_;
    return $self->client->post($self->_org_path($org, 'teams'), \%params);
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo  = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $org_name = 'my-org';
    my $org      = $forgejo->orgs->get($org_name);

    my $teams = $org->teams->list($org_name);
    $teams = $org->teams->list;    # organization taken from $org

    my $result = $org->teams->search($org_name, q => 'dev');

    my $team = $org->teams->create($org_name, name => 'Developers');

=head1 DESCRIPTION

Controller for the C</orgs/{org}/teams> endpoints. It is obtained
through L<WWW::Forgejo::Entity::Org/teams>.

The methods take the organization name as their first argument. When it is
left out or undefined, the organization the controller was obtained from
(L</owner>) is used.

A single team is addressed by its numeric ID, independent of the organization:
see L<WWW::Forgejo::API::Teams> for reading, editing and deleting a team and for
its members and repositories.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Org>, L<WWW::Forgejo::API::Orgs>,
L<WWW::Forgejo::API::Teams>, L<WWW::Forgejo>

=cut
