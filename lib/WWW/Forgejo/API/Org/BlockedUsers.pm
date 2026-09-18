# ABSTRACT: Forgejo Organization Blocked Users API
# PODNAME: WWW::Forgejo::API::Org::BlockedUsers

use strict;
use warnings;

package WWW::Forgejo::API::Org::BlockedUsers;

use Moo;
use Log::Any qw($log);
use URI::Escape;
use Carp qw(croak);

has client => (is => 'ro', init_arg => 'client');
has owner  => (is => 'ro', init_arg => 'owner', predicate => 'has_owner');

=method list

    my $blocked = $api->list($org);
    my $blocked = $org->blocked_users->list;  # when called from org entity

List all blocked users for an organization.

=cut

sub list {
    my ($self, $org) = @_;
    $org ||= $self->owner if $self->has_owner;
    croak "Organization name required" unless $org;
    return $self->{client}->get("/orgs/" . uri_escape($org) . "/blocked_users");
}

=method block

    $api->block($org, $username);

Block a user from the organization.

=cut

sub block {
    my ($self, $org, $username) = @_;
    croak "Organization name required" unless $org;
    croak "Username required" unless $username;
    return $self->{client}->put("/orgs/" . uri_escape($org) . "/blocked_users/" . uri_escape($username), {});
}

=method unblock

    $api->unblock($org, $username);

Unblock a user from the organization.

=cut

sub unblock {
    my ($self, $org, $username) = @_;
    croak "Organization name required" unless $org;
    croak "Username required" unless $username;
    return $self->{client}->delete("/orgs/" . uri_escape($org) . "/blocked_users/" . uri_escape($username));
}

=method check

    my $result = $api->check($org, $username);

Check if a user is blocked.

=cut

sub check {
    my ($self, $org, $username) = @_;
    croak "Organization name required" unless $org;
    croak "Username required" unless $username;
    return $self->{client}->get("/orgs/" . uri_escape($org) . "/blocked_users/" . uri_escape($username));
}

1;