# ABSTRACT: Forgejo Organization Actions API
# PODNAME: WWW::Forgejo::API::Org::Actions

use strict;
use warnings;

package WWW::Forgejo::API::Org::Actions;

use Moo;
use Log::Any qw($log);
use URI::Escape;
use Carp qw(croak);

has client => (is => 'ro', init_arg => 'client');
has owner  => (is => 'ro', init_arg => 'owner', predicate => 'has_owner');

=method list

    my $runs = $api->list($org);
    my $runs = $org->actions->list;  # when called from org entity

List all workflow runs for an organization.

=cut

sub list {
    my ($self, $org, %params) = @_;
    $org ||= $self->owner if $self->has_owner;
    croak "Organization name required" unless $org;
    return $self->{client}->get("/orgs/" . uri_escape($org) . "/actions/runs", params => \%params);
}

=method get

    my $run = $api->get($org, $run_id);

Get a specific workflow run.

=cut

sub get {
    my ($self, $org, $run_id) = @_;
    return $self->{client}->get("/orgs/" . uri_escape($org) . "/actions/runs/" . uri_escape($run_id));
}

=method list_workflows

    my $workflows = $api->list_workflows($org);

List all workflows for an organization.

=cut

sub list_workflows {
    my ($self, $org) = @_;
    return $self->{client}->get("/orgs/" . uri_escape($org) . "/actions/workflows");
}

=method get_workflow

    my $workflow = $api->get_workflow($org, $workflow_id);

Get a specific workflow.

=cut

sub get_workflow {
    my ($self, $org, $workflow_id) = @_;
    return $self->{client}->get("/orgs/" . uri_escape($org) . "/actions/workflows/" . uri_escape($workflow_id));
}

=method list_secrets

    my $secrets = $api->list_secrets($org);

List all secrets for an organization.

=cut

sub list_secrets {
    my ($self, $org) = @_;
    return $self->{client}->get("/orgs/" . uri_escape($org) . "/actions/secrets");
}

=method get_secret

    my $secret = $api->get_secret($org, $secret_name);

Get a specific secret.

=cut

sub get_secret {
    my ($self, $org, $secret_name) = @_;
    return $self->{client}->get("/orgs/" . uri_escape($org) . "/actions/secrets/" . uri_escape($secret_name));
}

=method set_secret

    $api->set_secret($org, $secret_name, $data);

Set a secret.

=cut

sub set_secret {
    my ($self, $org, $secret_name, $data) = @_;
    return $self->{client}->put("/orgs/" . uri_escape($org) . "/actions/secrets/" . uri_escape($secret_name), $data);
}

=method delete_secret

    $api->delete_secret($org, $secret_name);

Delete a secret.

=cut

sub delete_secret {
    my ($self, $org, $secret_name) = @_;
    return $self->{client}->delete("/orgs/" . uri_escape($org) . "/actions/secrets/" . uri_escape($secret_name));
}

=method list_variables

    my $vars = $api->list_variables($org);

List all variables for an organization.

=cut

sub list_variables {
    my ($self, $org) = @_;
    return $self->{client}->get("/orgs/" . uri_escape($org) . "/actions/variables");
}

=method get_variable

    my $var = $api->get_variable($org, $var_name);

Get a specific variable.

=cut

sub get_variable {
    my ($self, $org, $var_name) = @_;
    return $self->{client}->get("/orgs/" . uri_escape($org) . "/actions/variables/" . uri_escape($var_name));
}

=method set_variable

    $api->set_variable($org, $var_name, $data);

Set a variable.

=cut

sub set_variable {
    my ($self, $org, $var_name, $data) = @_;
    return $self->{client}->put("/orgs/" . uri_escape($org) . "/actions/variables/" . uri_escape($var_name), $data);
}

=method delete_variable

    $api->delete_variable($org, $var_name);

Delete a variable.

=cut

sub delete_variable {
    my ($self, $org, $var_name) = @_;
    return $self->{client}->delete("/orgs/" . uri_escape($org) . "/actions/variables/" . uri_escape($var_name));
}

=method list_runners

    my $runners = $api->list_runners($org);

List all organization runners.

=cut

sub list_runners {
    my ($self, $org) = @_;
    return $self->{client}->get("/orgs/" . uri_escape($org) . "/actions/runners");
}

=method get_runner

    my $runner = $api->get_runner($org, $runner_id);

Get a specific runner.

=cut

sub get_runner {
    my ($self, $org, $runner_id) = @_;
    return $self->{client}->get("/orgs/" . uri_escape($org) . "/actions/runners/" . uri_escape($runner_id));
}

=method delete_runner

    $api->delete_runner($org, $runner_id);

Delete a runner.

=cut

sub delete_runner {
    my ($self, $org, $runner_id) = @_;
    return $self->{client}->delete("/orgs/" . uri_escape($org) . "/actions/runners/" . uri_escape($runner_id));
}

=method regenerate_runner_token

    my $token = $api->regenerate_runner_token($org, $runner_id);

Regenerate a runner token.

=cut

sub regenerate_runner_token {
    my ($self, $org, $runner_id) = @_;
    return $self->{client}->post("/orgs/" . uri_escape($org) . "/actions/runners/" . uri_escape($runner_id) . " regeneration");
}

1;