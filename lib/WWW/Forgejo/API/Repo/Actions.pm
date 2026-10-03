# ABSTRACT: Forgejo Repo Actions API
# PODNAME: WWW::Forgejo::API::Repo::Actions

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Actions;

use Moo;
use URI::Escape qw(uri_escape);
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
    return join '/', '/repos', uri_escape($self->owner), uri_escape($self->repo), 'actions', @path;
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

    my @runs = $repo->actions->list_runs;
    my @runs = $repo->actions->list_runs(status => 'success', page => 2);

List workflow runs as L<WWW::Forgejo::Entity::WorkflowRun> objects. Named
arguments are sent as the query string (C<event>, C<status>, C<run_number>,
C<head_sha>, C<ref>, C<workflow_id>, C<page>, C<limit>).

The API answers with an object holding the runs under C<workflow_runs>; that
shape is not auto-paginated, so only the requested page is returned. Forgejo 15
sends no C<X-Total-Count> here (the total is the C<total_count> of the body),
and it honours C<limit> only together with C<page>: without a C<page> all runs
come back.

=cut

sub list_runs {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for('runs'), params => \%params);
    return map { $self->_run($_) } @{ $data->{workflow_runs} || [] };
}

=method get_run

    my $run = $repo->actions->get_run($run_id);

Get a workflow run by ID as a L<WWW::Forgejo::Entity::WorkflowRun>.

=cut

sub get_run {
    my ($self, $run_id) = @_;
    return $self->_run($self->client->get($self->_path_for('runs', uri_escape($run_id))));
}

=method get_run_jobs

    my @jobs = $repo->actions->get_run_jobs($run_id);

Get the jobs of a workflow run as L<WWW::Forgejo::Entity::WorkflowJob> objects.
An operation of Forgejo 16; Forgejo 15 has no such route and croaks with
C<Forgejo API error: 404 page not found>.

=cut

sub get_run_jobs {
    my ($self, $run_id) = @_;
    my $data = $self->client->get($self->_path_for('runs', uri_escape($run_id), 'jobs'));
    return map { WWW::Forgejo::Entity::WorkflowJob->new(client => $self->client, data => $_) } @$data;
}

=method cancel_run

    $repo->actions->cancel_run($run_id);

Cancel a workflow run. Returns true. An operation of Forgejo 16; Forgejo 15 has
no such route and croaks with C<Forgejo API error: 404 page not found>.

=cut

sub cancel_run {
    my ($self, $run_id) = @_;
    $self->client->post($self->_path_for('runs', uri_escape($run_id), 'cancel'));
    return 1;
}

=method delete_run

    $repo->actions->delete_run($run_id);

Delete a workflow run. Returns true. An operation of Forgejo 16; Forgejo 15
croaks with C<Forgejo API error: 405> (the path exists there for C<GET> only).

=cut

sub delete_run {
    my ($self, $run_id) = @_;
    $self->client->delete($self->_path_for('runs', uri_escape($run_id)));
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

    $repo->actions->set_secret('DEPLOY_KEY', { data => $value });

Create or update a secret; the API requires C<data>, the value of the secret.

=cut

sub set_secret {
    my ($self, $name, $data) = @_;
    return $self->client->put($self->_path_for('secrets', uri_escape($name)), $data);
}

=method delete_secret

    $repo->actions->delete_secret('DEPLOY_KEY');

Delete a secret.

=cut

sub delete_secret {
    my ($self, $name) = @_;
    $self->client->delete($self->_path_for('secrets', uri_escape($name)));
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
    return $self->client->get($self->_path_for('variables', uri_escape($name)));
}

=method create_variable

    $repo->actions->create_variable('STAGE', { value => 'prod' });

Create an action variable; the API requires C<value>.

=cut

sub create_variable {
    my ($self, $name, $data) = @_;
    return $self->client->post($self->_path_for('variables', uri_escape($name)), $data);
}

=method set_variable

    $repo->actions->set_variable('STAGE', { value => 'test' });
    $repo->actions->set_variable('STAGE', { value => 'test', name => 'ENV' });

Update an existing action variable; the API requires C<value>, and C<name>
renames it.

=cut

sub set_variable {
    my ($self, $name, $data) = @_;
    return $self->client->put($self->_path_for('variables', uri_escape($name)), $data);
}

=method delete_variable

    $repo->actions->delete_variable('STAGE');

Delete an action variable.

=cut

sub delete_variable {
    my ($self, $name) = @_;
    $self->client->delete($self->_path_for('variables', uri_escape($name)));
    return;
}

=method list_runners

    my @runners = $repo->actions->list_runners;

List the runners of the repository. Named arguments are sent as the query
string.

=cut

sub list_runners {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for('runners'), params => \%params);
    return @$data;
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @runs = $repo->actions->list_runs;

    my $run = $repo->actions->get_run($run_id);

    my @jobs = $repo->actions->get_run_jobs($run_id);

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/actions> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/actions>, which binds it to
that repository; every method then addresses that repository.

Depending on the method, results are L<WWW::Forgejo::Entity::WorkflowRun> and L<WWW::Forgejo::Entity::WorkflowJob>
objects or the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::WorkflowRun>, L<WWW::Forgejo::Entity::WorkflowJob>, L<WWW::Forgejo>

=cut
