# ABSTRACT: Forgejo Organization Teams API
# PODNAME: WWW::Forgejo::API::Org::Teams

use strict;
use warnings;

package WWW::Forgejo::API::Org::Teams;

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

    my $teams = $org->teams->list;

List all teams of an organization. Further named arguments are sent as the
query string of the request.

=cut

sub list {
    my ($self, %params) = @_;
    return $self->client->get($self->_org_path('teams'), params => \%params);
}

=method search

    my $result = $org->teams->search(q => 'dev');

Search the teams of an organization (C<GET /orgs/{org}/teams/search>); C<q>
is the search term. Returns the decoded response. Further named arguments
are sent as the query string of the request.

=cut

sub search {
    my ($self, %params) = @_;
    return $self->client->get($self->_org_path('teams', 'search'), params => \%params);
}

=method create

    my $team = $org->teams->create(name => 'Developers');

Create a new team in the organization; the API requires C<name>. The
key/value pairs are sent as the JSON body.

=cut

sub create {
    my ($self, %params) = @_;
    return $self->client->post($self->_org_path('teams'), \%params);
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo  = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $org_name = 'my-org';
    my $org      = $forgejo->orgs->get($org_name);

    my $teams = $org->teams->list;

    my $result = $org->teams->search(q => 'dev');

    my $team = $org->teams->create(name => 'Developers');

=head1 DESCRIPTION

Controller for the C</orgs/{org}/teams> endpoints. It is obtained
through L<WWW::Forgejo::Entity::Org/teams>.

The controller is bound to one organization: every method sends its request to
the organization the controller was obtained from (L</owner>). There is no
organization argument to pass.

A single team is addressed by its numeric ID, independent of the organization:
see L<WWW::Forgejo::API::Teams> for reading, editing and deleting a team and for
its members and repositories.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Org>, L<WWW::Forgejo::API::Orgs>,
L<WWW::Forgejo::API::Teams>, L<WWW::Forgejo>

=cut
