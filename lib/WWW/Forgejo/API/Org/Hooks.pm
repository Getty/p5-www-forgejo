# ABSTRACT: Forgejo Organization Hooks API
# PODNAME: WWW::Forgejo::API::Org::Hooks

use strict;
use warnings;

package WWW::Forgejo::API::Org::Hooks;

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

    my $hooks = $org->hooks->list($org_name);
    my $hooks = $org->hooks->list;    # organization taken from $org

List all organization hooks. Further named arguments are sent as the query
string of the request.

=cut

sub list {
    my ($self, $org, %params) = @_;
    return $self->client->get($self->_org_path($org, 'hooks'), params => \%params);
}

=method get

    my $hook = $org->hooks->get($org_name, $hook_id);

Get a specific hook by ID.

=cut

sub get {
    my ($self, $org, $hook_id) = @_;
    croak "Hook ID required" unless defined $hook_id && length $hook_id;
    return $self->client->get($self->_org_path($org, 'hooks', uri_escape($hook_id)));
}

=method create

    my $hook = $org->hooks->create($org_name,
        type   => 'forgejo',
        config => { url => 'https://example.com/hook', content_type => 'json' },
        events => ['push'],
    );

Create a new organization hook; the API requires C<type> and C<config>. The
key/value pairs are sent as the JSON body.

=cut

sub create {
    my ($self, $org, %params) = @_;
    return $self->client->post($self->_org_path($org, 'hooks'), \%params);
}

=method edit

    my $hook = $org->hooks->edit($org_name, $hook_id, active => \0);

Edit an organization hook (C<PATCH /orgs/{org}/hooks/{id}>). The key/value
pairs are sent as the JSON body.

=cut

sub edit {
    my ($self, $org, $hook_id, %params) = @_;
    croak "Hook ID required" unless defined $hook_id && length $hook_id;
    return $self->client->patch($self->_org_path($org, 'hooks', uri_escape($hook_id)), \%params);
}

=method delete

    $org->hooks->delete($org_name, $hook_id);

Delete an organization hook.

=cut

sub delete {
    my ($self, $org, $hook_id) = @_;
    croak "Hook ID required" unless defined $hook_id && length $hook_id;
    return $self->client->delete($self->_org_path($org, 'hooks', uri_escape($hook_id)));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo  = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $org_name = 'my-org';
    my $org      = $forgejo->orgs->get($org_name);

    my $hooks = $org->hooks->list($org_name);
    $hooks = $org->hooks->list;    # organization taken from $org

    my $hook = $org->hooks->get($org_name, $hook_id);

    $hook = $org->hooks->create($org_name,
        type   => 'forgejo',
        config => { url => 'https://example.com/hook', content_type => 'json' },
        events => ['push'],
    );

=head1 DESCRIPTION

Controller for the C</orgs/{org}/hooks> endpoints. It is obtained
through L<WWW::Forgejo::Entity::Org/hooks>.

The methods take the organization name as their first argument. When it is
left out or undefined, the organization the controller was obtained from
(L</owner>) is used.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Org>, L<WWW::Forgejo::API::Orgs>, L<WWW::Forgejo>

=cut
