# ABSTRACT: Forgejo Repo Actions API
# PODNAME: WWW::Forgejo::API::Repo::Actions

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Actions;

use Moo;
use WWW::Forgejo::URL qw( escape_component );
use WWW::Forgejo::Entity::WorkflowRun;
use WWW::Forgejo::Entity::WorkflowJob;
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);
has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=attr owner

Owner (user or organization name) of the repository this controller works on.
Required.

=attr repo

Name of the repository this controller works on. Required.

=cut

sub _path_for {
    my ($self, @path) = @_;
    return join '/', '/repos', escape_component($self->owner), escape_component($self->repo), 'actions', @path;
}

sub _run {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::WorkflowRun->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method list_runs

    my $runs = $repo->actions->list_runs;
    my $runs = $repo->actions->list_runs(status => 'success', page => 2);

List workflow runs as L<WWW::Forgejo::Entity::WorkflowRun> objects, in an
arrayref. Named arguments are sent as the query string (C<event>, C<status>,
C<run_number>, C<head_sha>, C<ref>, C<workflow_id>, C<page>, C<limit>).

The API answers with an object holding the runs under C<workflow_runs>; the
client auto-paginates that shape using the C<total_count> of the body (Forgejo 15
sends no C<X-Total-Count> here), unless a C<page> is given, in which case only
that page is returned. The server honours C<limit> only together with C<page>:
without a C<page> all runs come back.

=cut

sub list_runs {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for('runs'), params => \%params);
    return [ map { $self->_run($_) } @{ $data->{workflow_runs} || [] } ];
}

=method get_run

    my $run = $repo->actions->get_run($run_id);

Get a workflow run by ID as a L<WWW::Forgejo::Entity::WorkflowRun>.

=cut

sub get_run {
    my ($self, $run_id) = @_;
    return $self->_run($self->client->get($self->_path_for('runs', escape_component($run_id))));
}

=method get_run_jobs

    my $jobs = $repo->actions->get_run_jobs($run_id);

Get the jobs of a workflow run as L<WWW::Forgejo::Entity::WorkflowJob> objects,
in an arrayref. An operation of Forgejo 16; Forgejo 15 has no such route and
croaks with C<Forgejo API error: 404 page not found>.

=cut

sub get_run_jobs {
    my ($self, $run_id) = @_;
    my $data = $self->client->get($self->_path_for('runs', escape_component($run_id), 'jobs'));
    return [ map { WWW::Forgejo::Entity::WorkflowJob->new(client => $self->client, data => $_) } @$data ];
}

=method cancel_run

    $repo->actions->cancel_run($run_id);

Cancel a workflow run. Returns true. An operation of Forgejo 16; Forgejo 15 has
no such route and croaks with C<Forgejo API error: 404 page not found>.

=cut

sub cancel_run {
    my ($self, $run_id) = @_;
    $self->client->post($self->_path_for('runs', escape_component($run_id), 'cancel'));
    return 1;
}

=method delete_run

    $repo->actions->delete_run($run_id);

Delete a workflow run. Returns true. An operation of Forgejo 16; Forgejo 15
croaks with C<Forgejo API error: 405> (the path exists there for C<GET> only).

=cut

sub delete_run {
    my ($self, $run_id) = @_;
    $self->client->delete($self->_path_for('runs', escape_component($run_id)));
    return 1;
}

=method list_secrets

    my $secrets = $repo->actions->list_secrets;

List the secrets of the repository (names only; the API never returns the
values). Named arguments are sent as the query string.

=cut

sub list_secrets {
    my ($self, %params) = @_;
    return $self->client->get($self->_path_for('secrets'), params => \%params);
}

=method set_secret

    $repo->actions->set_secret('DEPLOY_KEY', data => $value);

Create or update a secret; the API requires C<data>, the value of the secret.
The named arguments are sent as the JSON body.

=cut

sub set_secret {
    my ($self, $name, %params) = @_;
    return $self->client->put($self->_path_for('secrets', escape_component($name)), \%params);
}

=method delete_secret

    $repo->actions->delete_secret('DEPLOY_KEY');

Delete a secret.

=cut

sub delete_secret {
    my ($self, $name) = @_;
    $self->client->delete($self->_path_for('secrets', escape_component($name)));
    return;
}

=method list_variables

    my $variables = $repo->actions->list_variables;

List the action variables of the repository. Named arguments are sent as the
query string.

=cut

sub list_variables {
    my ($self, %params) = @_;
    return $self->client->get($self->_path_for('variables'), params => \%params);
}

=method get_variable

    my $variable = $repo->actions->get_variable('STAGE');

Get an action variable by name.

=cut

sub get_variable {
    my ($self, $name) = @_;
    return $self->client->get($self->_path_for('variables', escape_component($name)));
}

=method create_variable

    $repo->actions->create_variable('STAGE', value => 'prod');

Create an action variable; the API requires C<value>. The named arguments are
sent as the JSON body.

=cut

sub create_variable {
    my ($self, $name, %params) = @_;
    return $self->client->post($self->_path_for('variables', escape_component($name)), \%params);
}

=method set_variable

    $repo->actions->set_variable('STAGE', value => 'test');
    $repo->actions->set_variable('STAGE', value => 'test', name => 'ENV');

Update an existing action variable; the API requires C<value>, and C<name>
renames it. The named arguments are sent as the JSON body.

=cut

sub set_variable {
    my ($self, $name, %params) = @_;
    return $self->client->put($self->_path_for('variables', escape_component($name)), \%params);
}

=method delete_variable

    $repo->actions->delete_variable('STAGE');

Delete an action variable.

=cut

sub delete_variable {
    my ($self, $name) = @_;
    $self->client->delete($self->_path_for('variables', escape_component($name)));
    return;
}

=method list_runners

    my $runners = $repo->actions->list_runners;

List the runners of the repository, in an arrayref. Named arguments are sent as
the query string.

=cut

sub list_runners {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for('runners'), params => \%params);
    return [@$data];
}

=method list_artifacts

    my $artifacts = $repo->actions->list_artifacts;
    my $artifacts = $repo->actions->list_artifacts(name => 'build');

List the artifacts of the repository, as plain structures in an arrayref. Named
arguments are sent as the query string (C<name>, C<page>, C<limit>).

=cut

sub list_artifacts {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for('artifacts'), params => \%params);
    return [@$data];
}

=method get_artifact

    my $artifact = $repo->actions->get_artifact($artifact_id);

Get one artifact of the repository.

=cut

sub get_artifact {
    my ($self, $artifact_id) = @_;
    return $self->client->get($self->_path_for('artifacts', escape_component($artifact_id)));
}

=method delete_artifact

    $repo->actions->delete_artifact($artifact_id);

Delete an artifact of the repository. Returns true.

=cut

sub delete_artifact {
    my ($self, $artifact_id) = @_;
    $self->client->delete($self->_path_for('artifacts', escape_component($artifact_id)));
    return 1;
}

=method download_artifacts

    my $zip = $repo->actions->download_artifacts($artifact_id);

Download the archive (a ZIP file) with the content of an artifact
(C<GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip>). Returns the
body of the response as it is, as bytes.

=cut

sub download_artifacts {
    my ($self, $artifact_id) = @_;
    return $self->client->get(
        $self->_path_for('artifacts', escape_component($artifact_id), 'zip'), raw => 1);
}

=method get_job_logs

    my $log = $repo->actions->get_job_logs($job_id);

Get the log of a job
(C<GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs>). Returns the body of
the response as it is, as bytes. Named arguments are sent as the query string
(C<attempt>).

=cut

sub get_job_logs {
    my ($self, $job_id, %params) = @_;
    return $self->client->get(
        $self->_path_for('jobs', escape_component($job_id), 'logs'), params => \%params, raw => 1);
}

=method list_runner_jobs

    my $jobs = $repo->actions->list_runner_jobs;

List the jobs of all runners of the repository, as plain structures in an
arrayref. Named arguments are sent as the query string (C<labels>).

=cut

sub list_runner_jobs {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for('runners', 'jobs'), params => \%params);
    return [@$data];
}

=method get_runner_registration_token

    my $token = $repo->actions->get_runner_registration_token;

Get the registration token of the runners of the repository. The token is
returned as the plain structure of the API.

=cut

sub get_runner_registration_token {
    my ($self) = @_;
    return $self->client->get($self->_path_for('runners', 'registration-token'));
}

=method get_runner

    my $runner = $repo->actions->get_runner($runner_id);

Get one runner of the repository.

=cut

sub get_runner {
    my ($self, $runner_id) = @_;
    return $self->client->get($self->_path_for('runners', escape_component($runner_id)));
}

=method create_runner

    $repo->actions->create_runner(name => 'runner-1', description => 'A runner');

Register a runner for the repository. The named arguments are sent as the JSON
body; the API takes C<name> and takes C<description> and C<ephemeral> as well.

=cut

sub create_runner {
    my ($self, %params) = @_;
    return $self->client->post($self->_path_for('runners'), \%params);
}

=method delete_runner

    $repo->actions->delete_runner($runner_id);

Delete a runner of the repository. Returns true.

=cut

sub delete_runner {
    my ($self, $runner_id) = @_;
    $self->client->delete($self->_path_for('runners', escape_component($runner_id)));
    return 1;
}

=method list_run_artifacts

    my $artifacts = $repo->actions->list_run_artifacts($run_id);

List the artifacts of a workflow run, as plain structures in an arrayref. Named
arguments are sent as the query string (C<name>, C<page>, C<limit>).

=cut

sub list_run_artifacts {
    my ($self, $run_id, %params) = @_;
    my $data = $self->client->get(
        $self->_path_for('runs', escape_component($run_id), 'artifacts'), params => \%params);
    return [@$data];
}

=method get_run_logs

    my $log = $repo->actions->get_run_logs($run_id);

Get the logs of a workflow run
(C<GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs>). Returns the body of
the response as it is, as bytes.

=cut

sub get_run_logs {
    my ($self, $run_id) = @_;
    return $self->client->get($self->_path_for('runs', escape_component($run_id), 'logs'), raw => 1);
}

=method list_tasks

    my $tasks = $repo->actions->list_tasks;

List the tasks of the repository, as plain structures in an arrayref. Named
arguments are sent as the query string (C<status>, C<page>, C<limit>).

=cut

sub list_tasks {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for('tasks'), params => \%params);
    return [@$data];
}

=method dispatch_workflow

    $repo->actions->dispatch_workflow('ci.yaml', ref => 'main');

Trigger a workflow of the repository
(C<POST /repos/{owner}/{repo}/actions/workflows/{workflowfilename}/dispatches>).
The named arguments are sent as the JSON body; the API takes C<ref> (the branch
or the tag to run on), C<inputs> and C<return_run_info>.

=cut

sub dispatch_workflow {
    my ($self, $workflow, %params) = @_;
    return $self->client->post(
        $self->_path_for('workflows', escape_component($workflow), 'dispatches'), \%params);
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my $runs = $repo->actions->list_runs;

    my $run = $repo->actions->get_run($run_id);

    my $jobs = $repo->actions->get_run_jobs($run_id);

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/actions> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/actions>, which binds it to
that repository; every method then addresses that repository.

Depending on the method, results are L<WWW::Forgejo::Entity::WorkflowRun> and L<WWW::Forgejo::Entity::WorkflowJob>
objects or the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::WorkflowRun>, L<WWW::Forgejo::Entity::WorkflowJob>, L<WWW::Forgejo>

=cut
