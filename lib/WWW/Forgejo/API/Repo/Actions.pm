# ABSTRACT: Forgejo Repo Actions API
# PODNAME: WWW::Forgejo::API::Repo::Actions

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Actions;

use Moo;
use Log::Any qw($log);
use URI::Escape;
use WWW::Forgejo::Entity::WorkflowRun;
use WWW::Forgejo::Entity::WorkflowJob;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\uri_escape($self->owner)}/${\uri_escape($self->repo)}/actions/" . join('/', @path);
}

=method list_runs

    my @runs = $self->list_runs;

List workflow runs.

=cut

sub list_runs {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for('runs'), %params);
    return map {
        WWW::Forgejo::Entity::WorkflowRun->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

=method get_run

    my $run = $self->get_run($run_id);

Get a workflow run by ID.

=cut

sub get_run {
    my ($self, $run_id) = @_;
    my $data = $self->{client}->get($self->_path_for('runs', uri_escape($run_id)));
    return WWW::Forgejo::Entity::WorkflowRun->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method get_run_jobs

    my @jobs = $self->get_run_jobs($run_id);

Get jobs for a workflow run.

=cut

sub get_run_jobs {
    my ($self, $run_id) = @_;
    my $data = $self->{client}->get($self->_path_for('runs', uri_escape($run_id), 'jobs'));
    return map {
        WWW::Forgejo::Entity::WorkflowJob->new(
            client => $self->client,
            data   => $_,
        )
    } @$data;
}

=method cancel_run

    $self->cancel_run($run_id);

Cancel a workflow run.

=cut

sub cancel_run {
    my ($self, $run_id) = @_;
    $self->{client}->post($self->_path_for('runs', uri_escape($run_id), 'cancel'));
    return 1;
}

=method rerun

    $self->rerun($run_id);

Re-run a workflow.

=cut

sub rerun {
    my ($self, $run_id) = @_;
    $self->{client}->post($self->_path_for('runs', uri_escape($run_id), 'rerun'));
    return 1;
}

=method delete_run

    $self->delete_run($run_id);

Delete a workflow run.

=cut

sub delete_run {
    my ($self, $run_id) = @_;
    $self->{client}->delete($self->_path_for('runs', uri_escape($run_id)));
    return 1;
}

sub list_secrets {
    my ($self) = @_;
    my $data = $self->{client}->get($self->_path_for('secrets'));
    return $data;
}

=method get_secret

    my $secret = $self->get_secret('MY_SECRET');

Get an action secret.

=cut

sub get_secret {
    my ($self, $name) = @_;
    my $data = $self->{client}->get($self->_path_for("secrets/" . uri_escape($name)));
    return $data;
}

=method create_secret

    $self->create_secret({
        secret_name => 'MY_SECRET',
        data        => 'secret_value',
    });

Create an action secret.

=cut

sub create_secret {
    my ($self, $data) = @_;
    my $secret = $self->{client}->post($self->_path_for('secrets'), $data);
    return $secret;
}

=method delete_secret

    $self->delete_secret('MY_SECRET');

Delete an action secret.

=cut

sub delete_secret {
    my ($self, $name) = @_;
    $self->{client}->delete($self->_path_for("secrets/" . uri_escape($name)));
    return;
}

=method list_variables

    my $vars = $self->list_variables;

List action variables.

=cut

sub list_variables {
    my ($self) = @_;
    my $data = $self->{client}->get($self->_path_for('variables'));
    return $data;
}

=method get_variable

    my $var = $self->get_variable('MY_VAR');

Get an action variable.

=cut

sub get_variable {
    my ($self, $name) = @_;
    my $data = $self->{client}->get($self->_path_for("variables/" . uri_escape($name)));
    return $data;
}

=method create_variable

    $self->create_variable({
        name  => 'MY_VAR',
        value => 'variable_value',
    });

Create an action variable.

=cut

sub create_variable {
    my ($self, $data) = @_;
    my $var = $self->{client}->post($self->_path_for('variables'), $data);
    return $var;
}

=method delete_variable

    $self->delete_variable('MY_VAR');

Delete an action variable.

=cut

sub delete_variable {
    my ($self, $name) = @_;
    $self->{client}->delete($self->_path_for("variables/" . uri_escape($name)));
    return;
}

=method list_runners

    my @runners = $self->list_runners;

List self-hosted runners.

=cut

sub list_runners {
    my ($self) = @_;
    my $data = $self->{client}->get($self->_path_for('runners'));
    return @$data;
}

=method list_workflows

    my $workflows = $self->list_workflows;

List workflow files.

=cut

sub list_workflows {
    my ($self) = @_;
    my $data = $self->{client}->get($self->_path_for('workflows'));
    return $data;
}

1;
__END__

=cut
