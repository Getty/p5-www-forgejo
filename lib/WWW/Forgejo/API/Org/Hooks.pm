# ABSTRACT: Forgejo Organization Hooks API
# PODNAME: WWW::Forgejo::API::Org::Hooks

use strict;
use warnings;

package WWW::Forgejo::API::Org::Hooks;

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

    my $hooks = $org->hooks->list;

List all organization hooks. Further named arguments are sent as the query
string of the request.

=cut

sub list {
    my ($self, %params) = @_;
    return $self->client->get($self->_org_path('hooks'), params => \%params);
}

=method get

    my $hook = $org->hooks->get($hook_id);

Get a specific hook by ID.

=cut

sub get {
    my ($self, $hook_id) = @_;
    croak "Hook ID required" unless defined $hook_id && length $hook_id;
    return $self->client->get($self->_org_path('hooks', escape_component($hook_id)));
}

=method create

    my $hook = $org->hooks->create(
        type   => 'forgejo',
        config => { url => 'https://example.com/hook', content_type => 'json' },
        events => ['push'],
    );

Create a new organization hook; the API requires C<type> and C<config>. The
key/value pairs are sent as the JSON body.

=cut

sub create {
    my ($self, %params) = @_;
    return $self->client->post($self->_org_path('hooks'), \%params);
}

=method edit

    my $hook = $org->hooks->edit($hook_id, active => \0);

Edit an organization hook (C<PATCH /orgs/{org}/hooks/{id}>). The key/value
pairs are sent as the JSON body.

=cut

sub edit {
    my ($self, $hook_id, %params) = @_;
    croak "Hook ID required" unless defined $hook_id && length $hook_id;
    return $self->client->patch($self->_org_path('hooks', escape_component($hook_id)), \%params);
}

=method delete

    $org->hooks->delete($hook_id);

Delete an organization hook.

=cut

sub delete {
    my ($self, $hook_id) = @_;
    croak "Hook ID required" unless defined $hook_id && length $hook_id;
    return $self->client->delete($self->_org_path('hooks', escape_component($hook_id)));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo  = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $org_name = 'my-org';
    my $org      = $forgejo->orgs->get($org_name);

    my $hooks = $org->hooks->list;

    my $hook = $org->hooks->get($hook_id);

    $hook = $org->hooks->create(
        type   => 'forgejo',
        config => { url => 'https://example.com/hook', content_type => 'json' },
        events => ['push'],
    );

=head1 DESCRIPTION

Controller for the C</orgs/{org}/hooks> endpoints. It is obtained
through L<WWW::Forgejo::Entity::Org/hooks>.

The controller is bound to one organization: every method sends its request to
the organization the controller was obtained from (L</owner>). There is no
organization argument to pass.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Org>, L<WWW::Forgejo::API::Orgs>, L<WWW::Forgejo>

=cut
