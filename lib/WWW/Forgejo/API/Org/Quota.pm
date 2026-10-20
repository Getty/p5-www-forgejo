# ABSTRACT: Forgejo Organization Quota API
# PODNAME: WWW::Forgejo::API::Org::Quota

use strict;
use warnings;

package WWW::Forgejo::API::Org::Quota;

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

=method get

    my $quota = $org->quota->get;

Get the quota information of an organization.

=cut

sub get {
    my ($self) = @_;
    return $self->client->get($self->_org_path('quota'));
}

=method artifacts

    my $artifacts = $org->quota->artifacts;

List the artifacts of the organization that count against the quota
(C<GET /orgs/{org}/quota/artifacts>). Further named arguments are sent as the
query string of the request (C<page>, C<limit>).

=cut

sub artifacts {
    my ($self, %params) = @_;
    return $self->client->get($self->_org_path('quota', 'artifacts'), params => \%params);
}

=method attachments

    my $attachments = $org->quota->attachments;

List the attachments of the organization that count against the quota
(C<GET /orgs/{org}/quota/attachments>). Further named arguments are sent as the
query string of the request (C<page>, C<limit>).

=cut

sub attachments {
    my ($self, %params) = @_;
    return $self->client->get($self->_org_path('quota', 'attachments'), params => \%params);
}

=method packages

    my $packages = $org->quota->packages;

List the packages of the organization that count against the quota
(C<GET /orgs/{org}/quota/packages>). Further named arguments are sent as the
query string of the request (C<page>, C<limit>).

=cut

sub packages {
    my ($self, %params) = @_;
    return $self->client->get($self->_org_path('quota', 'packages'), params => \%params);
}

=method check

    my $ok = $org->quota->check(subject => 'size:repos:all');

Check whether the organization has quota left for a subject
(C<GET /orgs/{org}/quota/check>). The named arguments are sent as the query
string; the API requires the C<subject> to check. Returns true or false.

=cut

sub check {
    my ($self, %params) = @_;
    croak "Quota subject required" unless defined $params{subject} && length $params{subject};
    return $self->client->get($self->_org_path('quota', 'check'), params => \%params);
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo  = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $org_name = 'my-org';
    my $org      = $forgejo->orgs->get($org_name);

    my $quota = $org->quota->get;

=head1 DESCRIPTION

Controller for the C</orgs/{org}/quota> endpoints. It is obtained
through L<WWW::Forgejo::Entity::Org/quota>.

The controller is bound to one organization: every method sends its request to
the organization the controller was obtained from (L</owner>). There is no
organization argument to pass.

The API offers no call to change the quota of an organization here; quota
groups are managed through L<WWW::Forgejo::API::Admin::Quota>.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Org>, L<WWW::Forgejo::API::Orgs>,
L<WWW::Forgejo::API::Admin::Quota>, L<WWW::Forgejo>

=cut
