package WWW::Forgejo::API::Admin::Hooks;
# ABSTRACT: Forgejo Admin API - Hooks
# PODNAME: WWW::Forgejo::API::Admin::Hooks

use Moo;
use Log::Any qw($log);
use URI::Escape;
use Carp qw(croak);

has client => (
    is       => 'ro',
    init_arg => 'client',
);

=method list

    my $hooks = $self->list;

List all system-wide hooks.

=cut

sub list {
    my ($self) = @_;
    return $self->{client}->get('/admin/hooks');
}

=method get

    my $hook = $self->get($id);

Get a specific hook by ID.

=cut

sub get {
    my ($self, $id) = @_;
    return $self->{client}->get("/admin/hooks/" . uri_escape($id));
}

=method create

    my $hook = $self->create(
        type => 'web',
        url => 'https://example.com/hook',
    );

Create a new system hook.

=cut

sub create {
    my ($self, %params) = @_;
    return $self->{client}->post('/admin/hooks', \%params);
}

=method edit

    my $hook = $self->edit($id, url => 'https://example.com/new-hook');

Edit an existing hook.

=cut

sub edit {
    my ($self, $id, %params) = @_;
    return $self->{client}->put("/admin/hooks/" . uri_escape($id), \%params);
}

=method delete

    $self->delete($id);

Delete a hook.

=cut

sub delete {
    my ($self, $id) = @_;
    return $self->{client}->delete("/admin/hooks/" . uri_escape($id));
}

=method list_repos

    my $repos = $self->list_repos($id);

List repositories attached to a hook.

=cut

sub list_repos {
    my ($self, $id) = @_;
    return $self->{client}->get("/admin/hooks/" . uri_escape($id) . "/repos");
}

=method list_orgs

    my $orgs = $self->list_orgs($id);

List organizations attached to a hook.

=cut

sub list_orgs {
    my ($self, $id) = @_;
    return $self->{client}->get("/admin/hooks/" . uri_escape($id) . "/orgs");
}

1;