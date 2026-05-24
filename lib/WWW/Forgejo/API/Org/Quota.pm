# ABSTRACT: Forgejo Organization Quota API
# PODNAME: WWW::Forgejo::API::Org::Quota

use strict;
use warnings;

package WWW::Forgejo::API::Org::Quota;

use Moo;
use Log::Any qw($log);
use Carp qw(croak);

has client => (is => 'ro', init_arg => 'client');
has owner  => (is => 'ro', init_arg => 'owner', predicate => 'has_owner');

=method get

    my $quota = $api->get($org);
    my $quota = $org->quota->get;  # when called from org entity

Get organization quota information.

=cut

sub get {
    my ($self, $org) = @_;
    $org ||= $self->owner if $self->has_owner;
    croak "Organization name required" unless $org;
    return $self->{client}->get("/orgs/$org/quota");
}

=method set

    my $quota = $api->set($org,
        max_queue_size => 10,
    );

Set organization quota.

=cut

sub set {
    my ($self, $org, %params) = @_;
    croak "Organization name required" unless $org;
    return $self->{client}->post("/orgs/$org/quota", \%params);
}

1;