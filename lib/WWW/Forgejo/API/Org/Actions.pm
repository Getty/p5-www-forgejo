# ABSTRACT: Forgejo Organization Actions API
# PODNAME: WWW::Forgejo::API::Org::Actions

use strict;
use warnings;

package WWW::Forgejo::API::Org::Actions;

use Moo;
use Carp qw(croak);
use WWW::Forgejo::URL qw( escape_component );
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);
has owner  => (is => 'ro', predicate => 'has_owner');

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=attr owner

Name of the organization this controller addresses. It is the
L<name|WWW::Forgejo::Entity::Org/name> of the organization the controller was
obtained from, and every method sends its request to it. A controller without
an owner croaks with C<Organization name required> when a method is called.
L</has_owner> tells whether it was passed to the constructor.

=method has_owner

    my $bool = $controller->has_owner;

True when an L</owner> was passed to the constructor.

=cut

# /orgs/{org}/... for the organization this controller is bound to.
sub _org_path {
    my ($self, @path) = @_;
    my $org = $self->owner;
    croak "Organization name required" unless defined $org && length $org;
    return join '/', '/orgs', escape_component($org), @path;
}

=method list_secrets

    my $secrets = $org->actions->list_secrets;

List the Actions secrets of an organization. The API returns their names,
not their values. Further named arguments are sent as the query string of
the request.

=cut

sub list_secrets {
    my ($self, %params) = @_;
    return $self->client->get($self->_org_path('actions', 'secrets'), params => \%params);
}

=method set_secret

    $org->actions->set_secret('MY_SECRET', data => 'secret value');

Create or update a secret (C<PUT /orgs/{org}/actions/secrets/{secretname}>).
The named arguments are sent as the JSON body; the API expects the value in
C<data>.

=cut

sub set_secret {
    my ($self, $secret_name, %params) = @_;
    croak "Secret name required" unless defined $secret_name && length $secret_name;
    return $self->client->put($self->_org_path('actions', 'secrets', escape_component($secret_name)), \%params);
}

=method delete_secret

    $org->actions->delete_secret('MY_SECRET');

Delete a secret.

=cut

sub delete_secret {
    my ($self, $secret_name) = @_;
    croak "Secret name required" unless defined $secret_name && length $secret_name;
    return $self->client->delete($self->_org_path('actions', 'secrets', escape_component($secret_name)));
}

=method list_variables

    my $vars = $org->actions->list_variables;

List the Actions variables of an organization. Further named arguments are
sent as the query string of the request.

=cut

sub list_variables {
    my ($self, %params) = @_;
    return $self->client->get($self->_org_path('actions', 'variables'), params => \%params);
}

=method get_variable

    my $var = $org->actions->get_variable('MY_VAR');

Get a specific variable.

=cut

sub get_variable {
    my ($self, $var_name) = @_;
    croak "Var name required" unless defined $var_name && length $var_name;
    return $self->client->get($self->_org_path('actions', 'variables', escape_component($var_name)));
}

=method create_variable

    $org->actions->create_variable('MY_VAR', value => 'some value');

Create a variable (C<POST /orgs/{org}/actions/variables/{variablename}>).
The named arguments are sent as the JSON body; the API expects the value in
C<value>.

=cut

sub create_variable {
    my ($self, $var_name, %params) = @_;
    croak "Var name required" unless defined $var_name && length $var_name;
    return $self->client->post($self->_org_path('actions', 'variables', escape_component($var_name)), \%params);
}

=method set_variable

    $org->actions->set_variable('MY_VAR', value => 'new value');

Update an existing variable (C<PUT
/orgs/{org}/actions/variables/{variablename}>). The named arguments are sent
as the JSON body.

=cut

sub set_variable {
    my ($self, $var_name, %params) = @_;
    croak "Var name required" unless defined $var_name && length $var_name;
    return $self->client->put($self->_org_path('actions', 'variables', escape_component($var_name)), \%params);
}

=method delete_variable

    $org->actions->delete_variable('MY_VAR');

Delete a variable.

=cut

sub delete_variable {
    my ($self, $var_name) = @_;
    croak "Var name required" unless defined $var_name && length $var_name;
    return $self->client->delete($self->_org_path('actions', 'variables', escape_component($var_name)));
}

=method list_runners

    my $runners = $org->actions->list_runners;

List the Actions runners of an organization. Further named arguments are
sent as the query string of the request.

=cut

sub list_runners {
    my ($self, %params) = @_;
    return $self->client->get($self->_org_path('actions', 'runners'), params => \%params);
}

=method get_runner

    my $runner = $org->actions->get_runner($runner_id);

Get a specific runner.

=cut

sub get_runner {
    my ($self, $runner_id) = @_;
    croak "Runner ID required" unless defined $runner_id && length $runner_id;
    return $self->client->get($self->_org_path('actions', 'runners', escape_component($runner_id)));
}

=method delete_runner

    $org->actions->delete_runner($runner_id);

Delete a runner.

=cut

sub delete_runner {
    my ($self, $runner_id) = @_;
    croak "Runner ID required" unless defined $runner_id && length $runner_id;
    return $self->client->delete($self->_org_path('actions', 'runners', escape_component($runner_id)));
}

=method runner_registration_token

    my $token = $org->actions->runner_registration_token;

Get the token for registering a runner with the organization (C<GET
/orgs/{org}/actions/runners/registration-token>).

=cut

sub runner_registration_token {
    my ($self) = @_;
    return $self->client->get($self->_org_path('actions', 'runners', 'registration-token'));
}

=method create_runner

    $org->actions->create_runner(name => 'runner-1', description => 'A runner');

Register a runner for the organization (C<POST /orgs/{org}/actions/runners>).
The named arguments are sent as the JSON body; the API takes C<name> and takes
C<description> and C<ephemeral> as well.

=cut

sub create_runner {
    my ($self, %params) = @_;
    return $self->client->post($self->_org_path('actions', 'runners'), \%params);
}

=method list_runner_jobs

    my $jobs = $org->actions->list_runner_jobs;

List the jobs of all runners of the organization
(C<GET /orgs/{org}/actions/runners/jobs>). Further named arguments are sent as
the query string of the request (C<labels>).

=cut

sub list_runner_jobs {
    my ($self, %params) = @_;
    return $self->client->get($self->_org_path('actions', 'runners', 'jobs'), params => \%params);
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo  = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $org_name = 'my-org';
    my $org      = $forgejo->orgs->get($org_name);

    my $secrets = $org->actions->list_secrets;

    $org->actions->set_secret('MY_SECRET', data => 'secret value');

    $org->actions->delete_secret('MY_SECRET');

=head1 DESCRIPTION

Controller for the C</orgs/{org}/actions> endpoints. It is obtained
through L<WWW::Forgejo::Entity::Org/actions>.

The controller is bound to one organization: every method sends its request to
the organization the controller was obtained from (L</owner>). There is no
organization argument to pass.

The API has no organization-level calls for workflow runs or workflows; those
live on the repository, see L<WWW::Forgejo::API::Repo::Actions>.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Org>, L<WWW::Forgejo::API::Orgs>,
L<WWW::Forgejo::API::Repo::Actions>, L<WWW::Forgejo>

=cut
