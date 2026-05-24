# ABSTRACT: Forgejo Organization Members API
# PODNAME: WWW::Forgejo::API::Org::Members

use strict;
use warnings;

package WWW::Forgejo::API::Org::Members;

use Moo;
use Log::Any qw($log);
use Carp qw(croak);

has client => (is => 'ro', init_arg => 'client');
has owner  => (is => 'ro', init_arg => 'owner', predicate => 'has_owner');

=method list

    my $members = $api->list($org);
    my $members = $org->members->list;  # when called from org entity

List all members of an organization.

=cut

sub list {
    my ($self, $org) = @_;
    $org ||= $self->owner if $self->has_owner;
    croak "Organization name required" unless $org;
    return $self->{client}->get("/orgs/$org/members");
}

=method get

    my $user = $api->get($org, $username);

Check if a user is a member of the organization.

=cut

sub get {
    my ($self, $org, $username) = @_;
    croak "Organization name required" unless $org;
    croak "Username required" unless $username;
    return $self->{client}->get("/orgs/$org/members/$username");
}

=method remove

    $api->remove($org, $username);

Remove a member from the organization.

=cut

sub remove {
    my ($self, $org, $username) = @_;
    croak "Organization name required" unless $org;
    croak "Username required" unless $username;
    return $self->{client}->delete("/orgs/$org/members/$username");
}

=method public

    my $user = $api->public($org, $username);

List all public members of an organization.

=cut

sub public {
    my ($self, $org, $username) = @_;
    croak "Organization name required" unless $org;
    croak "Username required" unless $username;
    return $self->{client}->get("/orgs/$org/public_members/$username");
}

=method publicize

    $api->publicize($org, $username);

Make a member's membership public.

=cut

sub publicize {
    my ($self, $org, $username) = @_;
    croak "Organization name required" unless $org;
    croak "Username required" unless $username;
    return $self->{client}->put("/orgs/$org/public_members/$username", {});
}

=method conceal

    $api->conceal($org, $username);

Make a member's membership private.

=cut

sub conceal {
    my ($self, $org, $username) = @_;
    croak "Organization name required" unless $org;
    croak "Username required" unless $username;
    return $self->{client}->delete("/orgs/$org/public_members/$username");
}

1;