package WWW::Forgejo::API::Admin::Quota;
# ABSTRACT: Forgejo Admin API - Quota
# PODNAME: WWW::Forgejo::API::Admin::Quota

use Moo;
use Log::Any qw($log);
use URI::Escape;
use Carp qw(croak);

has client => (
    is       => 'ro',
    init_arg => 'client',
);

=method list_groups

    my $groups = $self->list_groups;

List all quota groups.

=cut

sub list_groups {
    my ($self) = @_;
    return $self->{client}->get('/admin/quota/groups');
}

=method get_group

    my $group = $self->get_group($name);

Get a specific quota group by name.

=cut

sub get_group {
    my ($self, $name) = @_;
    return $self->{client}->get("/admin/quota/groups/" . uri_escape($name));
}

=method create_group

    my $group = $self->create_group(name => 'mygroup');

Create a quota group.

=cut

sub create_group {
    my ($self, %params) = @_;
    return $self->{client}->post('/admin/quota/groups', \%params);
}

=method delete_group

    $self->delete_group($name);

Delete a quota group.

=cut

sub delete_group {
    my ($self, $name) = @_;
    return $self->{client}->delete("/admin/quota/groups/" . uri_escape($name));
}

1;