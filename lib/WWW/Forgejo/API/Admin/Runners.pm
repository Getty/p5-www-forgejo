package WWW::Forgejo::API::Admin::Runners;
# ABSTRACT: Forgejo Admin API - Runners
# PODNAME: WWW::Forgejo::API::Admin::Runners

use Moo;
use Log::Any qw($log);
use URI::Escape;
use Carp qw(croak);

has client => (
    is       => 'ro',
    init_arg => 'client',
);

=method list

    my $runners = $self->list;

List all runners.

=cut

sub list {
    my ($self) = @_;
    return $self->{client}->get('/admin/runners');
}

=method get

    my $runner = $self->get($token);

Get a specific runner by token.

=cut

sub get {
    my ($self, $token) = @_;
    return $self->{client}->get("/admin/runners/" . uri_escape($token));
}

=method delete

    $self->delete($token);

Delete a runner by token.

=cut

sub delete {
    my ($self, $token) = @_;
    return $self->{client}->delete("/admin/runners/" . uri_escape($token));
}

=method update

    my $runner = $self->update($token, name => 'newname');

Update a runner.

=cut

sub update {
    my ($self, $token, %params) = @_;
    return $self->{client}->patch("/admin/runners/" . uri_escape($token), \%params);
}

1;