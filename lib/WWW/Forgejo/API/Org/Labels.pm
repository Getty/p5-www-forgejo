# ABSTRACT: Forgejo Organization Labels API
# PODNAME: WWW::Forgejo::API::Org::Labels

use strict;
use warnings;

package WWW::Forgejo::API::Org::Labels;

use Moo;
use Log::Any qw($log);
use URI::Escape;
use Carp qw(croak);

has client => (is => 'ro', init_arg => 'client');
has owner  => (is => 'ro', init_arg => 'owner', predicate => 'has_owner');

=method list

    my $labels = $api->list($org);
    my $labels = $org->labels->list;  # when called from org entity

List all labels for an organization.

=cut

sub list {
    my ($self, $org) = @_;
    $org ||= $self->owner if $self->has_owner;
    croak "Organization name required" unless $org;
    return $self->{client}->get("/orgs/" . uri_escape($org) . "/labels");
}

=method get

    my $label = $api->get($org, $label_id);

Get a specific label by ID.

=cut

sub get {
    my ($self, $org, $label_id) = @_;
    croak "Organization name required" unless $org;
    croak "Label ID required" unless $label_id;
    return $self->{client}->get("/orgs/" . uri_escape($org) . "/labels/" . uri_escape($label_id));
}

=method create

    my $label = $api->create($org,
        name => 'bug',
        color => 'ff0000',
        description => 'Bug reports',
    );

Create a new label.

=cut

sub create {
    my ($self, $org, %params) = @_;
    croak "Organization name required" unless $org;
    croak "Label name required" unless $params{name};
    croak "Label color required" unless $params{color};
    return $self->{client}->post("/orgs/" . uri_escape($org) . "/labels", \%params);
}

=method edit

    my $label = $api->edit($org, $label_id,
        name => 'enhancement',
        color => '00ff00',
    );

Edit a label.

=cut

sub edit {
    my ($self, $org, $label_id, %params) = @_;
    croak "Organization name required" unless $org;
    croak "Label ID required" unless $label_id;
    return $self->{client}->post("/orgs/" . uri_escape($org) . "/labels/" . uri_escape($label_id), \%params);
}

=method delete

    $api->delete($org, $label_id);

Delete a label.

=cut

sub delete {
    my ($self, $org, $label_id) = @_;
    croak "Organization name required" unless $org;
    croak "Label ID required" unless $label_id;
    return $self->{client}->delete("/orgs/" . uri_escape($org) . "/labels/" . uri_escape($label_id));
}

1;