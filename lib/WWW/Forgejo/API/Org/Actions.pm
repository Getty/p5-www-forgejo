# ABSTRACT: Forgejo Organization Actions API
# PODNAME: WWW::Forgejo::API::Org::Actions

use strict;
use warnings;

package WWW::Forgejo::API::Org::Actions;

use Moo;
use Carp qw(croak);
use URI::Escape qw(uri_escape);
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);
has owner  => (is => 'ro', predicate => 'has_owner');

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=attr owner

Name of the organization this controller was created for. Optional; when the
controller comes from a L<WWW::Forgejo::Entity::Org> it is the
L<name|WWW::Forgejo::Entity::Org/name> of that organization. It is used whenever a method is called without an
organization name (C<undef> as first argument, or no arguments at all).
L</has_owner> tells whether it was passed to the constructor.

=method has_owner

    my $bool = $controller->has_owner;

True when an L</owner> was passed to the constructor.

=cut

# /orgs/{org}/... for the given organization, falling back to the owner.
sub _org_path {
    my ($self, $org, @path) = @_;
    $org = $self->owner unless defined $org && length $org;
    croak "Organization name required" unless defined $org && length $org;
    return join '/', '/orgs', uri_escape($org), @path;
}

=method list_secrets

    my $secrets = $org->actions->list_secrets($org_name);

List the Actions secrets of an organization. The API returns their names,
not their values. Further named arguments are sent as the query string of
the request.

=cut

sub list_secrets {
    my ($self, $org, %params) = @_;
    return $self->client->get($self->_org_path($org, 'actions', 'secrets'), params => \%params);
}

=method set_secret

    $org->actions->set_secret($org_name, 'MY_SECRET', { data => 'secret value' });

Create or update a secret (C<PUT /orgs/{org}/actions/secrets/{secretname}>).
The hashref is sent as the JSON body; the API expects the value in C<data>.

=cut

sub set_secret {
    my ($self, $org, $secret_name, $data) = @_;
    croak "Secret name required" unless defined $secret_name && length $secret_name;
    return $self->client->put($self->_org_path($org, 'actions', 'secrets', uri_escape($secret_name)), $data);
}

=method delete_secret

    $org->actions->delete_secret($org_name, 'MY_SECRET');

Delete a secret.

=cut

sub delete_secret {
    my ($self, $org, $secret_name) = @_;
    croak "Secret name required" unless defined $secret_name && length $secret_name;
    return $self->client->delete($self->_org_path($org, 'actions', 'secrets', uri_escape($secret_name)));
}

=method list_variables

    my $vars = $org->actions->list_variables($org_name);

List the Actions variables of an organization. Further named arguments are
sent as the query string of the request.

=cut

sub list_variables {
    my ($self, $org, %params) = @_;
    return $self->client->get($self->_org_path($org, 'actions', 'variables'), params => \%params);
}

=method get_variable

    my $var = $org->actions->get_variable($org_name, 'MY_VAR');

Get a specific variable.

=cut

sub get_variable {
    my ($self, $org, $var_name) = @_;
    croak "Var name required" unless defined $var_name && length $var_name;
    return $self->client->get($self->_org_path($org, 'actions', 'variables', uri_escape($var_name)));
}

=method create_variable

    $org->actions->create_variable($org_name, 'MY_VAR', { value => 'some value' });

Create a variable (C<POST /orgs/{org}/actions/variables/{variablename}>).
The hashref is sent as the JSON body; the API expects the value in C<value>.

=cut

sub create_variable {
    my ($self, $org, $var_name, $data) = @_;
    croak "Var name required" unless defined $var_name && length $var_name;
    return $self->client->post($self->_org_path($org, 'actions', 'variables', uri_escape($var_name)), $data);
}

=method set_variable

    $org->actions->set_variable($org_name, 'MY_VAR', { value => 'new value' });

Update an existing variable (C<PUT
/orgs/{org}/actions/variables/{variablename}>). The hashref is sent as the
JSON body.

=cut

sub set_variable {
    my ($self, $org, $var_name, $data) = @_;
    croak "Var name required" unless defined $var_name && length $var_name;
    return $self->client->put($self->_org_path($org, 'actions', 'variables', uri_escape($var_name)), $data);
}

=method delete_variable

    $org->actions->delete_variable($org_name, 'MY_VAR');

Delete a variable.

=cut

sub delete_variable {
    my ($self, $org, $var_name) = @_;
    croak "Var name required" unless defined $var_name && length $var_name;
    return $self->client->delete($self->_org_path($org, 'actions', 'variables', uri_escape($var_name)));
}

=method list_runners

    my $runners = $org->actions->list_runners($org_name);

List the Actions runners of an organization. Further named arguments are
sent as the query string of the request.

=cut

sub list_runners {
    my ($self, $org, %params) = @_;
    return $self->client->get($self->_org_path($org, 'actions', 'runners'), params => \%params);
}

=method get_runner

    my $runner = $org->actions->get_runner($org_name, $runner_id);

Get a specific runner.

=cut

sub get_runner {
    my ($self, $org, $runner_id) = @_;
    croak "Runner ID required" unless defined $runner_id && length $runner_id;
    return $self->client->get($self->_org_path($org, 'actions', 'runners', uri_escape($runner_id)));
}

=method delete_runner

    $org->actions->delete_runner($org_name, $runner_id);

Delete a runner.

=cut

sub delete_runner {
    my ($self, $org, $runner_id) = @_;
    croak "Runner ID required" unless defined $runner_id && length $runner_id;
    return $self->client->delete($self->_org_path($org, 'actions', 'runners', uri_escape($runner_id)));
}

=method runner_registration_token

    my $token = $org->actions->runner_registration_token($org_name);

Get the token for registering a runner with the organization (C<GET
/orgs/{org}/actions/runners/registration-token>).

=cut

sub runner_registration_token {
    my ($self, $org) = @_;
    return $self->client->get($self->_org_path($org, 'actions', 'runners', 'registration-token'));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo  = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $org_name = 'my-org';
    my $org      = $forgejo->orgs->get($org_name);

    my $secrets = $org->actions->list_secrets($org_name);

    $org->actions->set_secret($org_name, 'MY_SECRET', { data => 'secret value' });

    $org->actions->delete_secret($org_name, 'MY_SECRET');

=head1 DESCRIPTION

Controller for the C</orgs/{org}/actions> endpoints. It is obtained
through L<WWW::Forgejo::Entity::Org/actions>.

The methods take the organization name as their first argument. When it is
left out or undefined, the organization the controller was obtained from
(L</owner>) is used.

The API has no organization-level calls for workflow runs or workflows; those
live on the repository, see L<WWW::Forgejo::API::Repo::Actions>.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Org>, L<WWW::Forgejo::API::Orgs>,
L<WWW::Forgejo::API::Repo::Actions>, L<WWW::Forgejo>

=cut
