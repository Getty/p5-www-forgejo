# ABSTRACT: Forgejo Organization Hooks API
# PODNAME: WWW::Forgejo::API::Org::Hooks

use strict;
use warnings;

package WWW::Forgejo::API::Org::Hooks;

use Moo;
use Log::Any qw($log);
use URI::Escape;
use Carp qw(croak);

has client => (is => 'ro', init_arg => 'client');
has owner  => (is => 'ro', init_arg => 'owner', predicate => 'has_owner');

=method list

    my $hooks = $api->list($org);
    my $hooks = $org->hooks->list;  # when called from org entity

List all organization hooks.

=cut

sub list {
    my ($self, $org) = @_;
    $org ||= $self->owner if $self->has_owner;
    croak "Organization name required" unless $org;
    return $self->{client}->get("/orgs/" . uri_escape($org) . "/hooks");
}

=method get

    my $hook = $api->get($org, $hook_id);

Get a specific hook by ID.

=cut

sub get {
    my ($self, $org, $hook_id) = @_;
    croak "Organization name required" unless $org;
    croak "Hook ID required" unless $hook_id;
    return $self->{client}->get("/orgs/" . uri_escape($org) . "/hooks/" . uri_escape($hook_id));
}

=method create

    my $hook = $api->create($org,
        type => 'web',
        config => { url => 'https://example.com/hook' },
        events => ['push', 'issues'],
    );

Create a new organization hook.

=cut

sub create {
    my ($self, $org, %params) = @_;
    croak "Organization name required" unless $org;
    croak "Hook type required" unless $params{type};
    croak "Hook config required" unless $params{config};
    return $self->{client}->post("/orgs/" . uri_escape($org) . "/hooks", \%params);
}

=method edit

    my $hook = $api->edit($org, $hook_id,
        config => { url => 'https://example.com/hook' },
    );

Edit an organization hook.

=cut

sub edit {
    my ($self, $org, $hook_id, %params) = @_;
    croak "Organization name required" unless $org;
    croak "Hook ID required" unless $hook_id;
    return $self->{client}->post("/orgs/" . uri_escape($org) . "/hooks/" . uri_escape($hook_id), \%params);
}

=method delete

    $api->delete($org, $hook_id);

Delete an organization hook.

=cut

sub delete {
    my ($self, $org, $hook_id) = @_;
    croak "Organization name required" unless $org;
    croak "Hook ID required" unless $hook_id;
    return $self->{client}->delete("/orgs/" . uri_escape($org) . "/hooks/" . uri_escape($hook_id));
}

=method test

    $api->test($org, $hook_id);

Test an organization hook.

=cut

sub test {
    my ($self, $org, $hook_id) = @_;
    croak "Organization name required" unless $org;
    croak "Hook ID required" unless $hook_id;
    return $self->{client}->post("/orgs/" . uri_escape($org) . "/hooks/" . uri_escape($hook_id) . "/tests", {});
}

1;