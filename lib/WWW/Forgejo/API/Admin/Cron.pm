package WWW::Forgejo::API::Admin::Cron;
# ABSTRACT: Forgejo Admin API - Cron
# PODNAME: WWW::Forgejo::API::Admin::Cron

use Moo;
use Log::Any qw($log);
use Carp qw(croak);

has client => (
    is       => 'ro',
    init_arg => 'client',
);

=method list

    my $tasks = $self->list;

List all cron tasks.

=cut

sub list {
    my ($self) = @_;
    return $self->{client}->get('/admin/cron');
}

=method get

    my $task = $self->get($task_name);

Get a specific cron task by name.

=cut

sub get {
    my ($self, $task) = @_;
    return $self->{client}->get("/admin/cron/$task");
}

=method run

    my $result = $self->run($task_name);

Run a cron task.

=cut

sub run {
    my ($self, $task) = @_;
    return $self->{client}->post("/admin/cron/$task");
}

1;