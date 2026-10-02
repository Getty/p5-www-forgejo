# ABSTRACT: Forgejo Current User API
# PODNAME: WWW::Forgejo::API::CurrentUser

use strict;
use warnings;

package WWW::Forgejo::API::CurrentUser;

use Moo;
use Carp qw(croak);
use URI::Escape qw(uri_escape);
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

=method get

    my $user = $forgejo->current_user->get;

Get the current user (C<GET /user>).

=cut

sub get {
    my ($self) = @_;
    return $self->client->get('/user');
}

=method settings

    my $settings = $forgejo->current_user->settings;

Get user settings.

=cut

sub settings {
    my ($self) = @_;
    return $self->client->get('/user/settings');
}

=method update_settings

    my $settings = $forgejo->current_user->update_settings(full_name => 'New Name');

Update user settings. The key/value pairs are sent as the JSON body.

=cut

sub update_settings {
    my ($self, %params) = @_;
    return $self->client->patch('/user/settings', \%params);
}

=method list_emails

    my $emails = $forgejo->current_user->list_emails;

List emails for the current user.

=cut

sub list_emails {
    my ($self) = @_;
    return $self->client->get('/user/emails');
}

=method add_email

    my $emails = $forgejo->current_user->add_email('new@example.com', 'other@example.com');

Add one or more email addresses (C<POST /user/emails>).

=cut

sub add_email {
    my ($self, @emails) = @_;
    croak "Email address required" unless @emails;
    return $self->client->post('/user/emails', { emails => \@emails });
}

=method delete_email

    $forgejo->current_user->delete_email('old@example.com');

Delete one or more email addresses (C<DELETE /user/emails>, the addresses
travel in the request body).

=cut

sub delete_email {
    my ($self, @emails) = @_;
    croak "Email address required" unless @emails;
    return $self->client->delete('/user/emails', { emails => \@emails });
}

=method list_keys

    my $keys = $forgejo->current_user->list_keys;

List public keys for the current user. Named arguments are sent as the query
string of the request.

=cut

sub list_keys {
    my ($self, %params) = @_;
    return $self->client->get('/user/keys', params => \%params);
}

=method get_key

    my $key = $forgejo->current_user->get_key($key_id);

Get a specific public key.

=cut

sub get_key {
    my ($self, $key_id) = @_;
    return $self->client->get('/user/keys/' . uri_escape($key_id));
}

=method create_key

    my $key = $forgejo->current_user->create_key(title => 'My Key', key => $public_key);

Create a public key. The key/value pairs are sent as the JSON body.

=cut

sub create_key {
    my ($self, %params) = @_;
    return $self->client->post('/user/keys', \%params);
}

=method delete_key

    $forgejo->current_user->delete_key($key_id);

Delete a public key.

=cut

sub delete_key {
    my ($self, $key_id) = @_;
    return $self->client->delete('/user/keys/' . uri_escape($key_id));
}

=method list_gpg_keys

    my $keys = $forgejo->current_user->list_gpg_keys;

List GPG keys for the current user. Named arguments are sent as the query
string of the request.

=cut

sub list_gpg_keys {
    my ($self, %params) = @_;
    return $self->client->get('/user/gpg_keys', params => \%params);
}

=method get_gpg_key

    my $key = $forgejo->current_user->get_gpg_key($key_id);

Get a specific GPG key.

=cut

sub get_gpg_key {
    my ($self, $key_id) = @_;
    return $self->client->get('/user/gpg_keys/' . uri_escape($key_id));
}

=method create_gpg_key

    my $key = $forgejo->current_user->create_gpg_key(armored_public_key => $armored);

Create a GPG key. The key/value pairs are sent as the JSON body.

=cut

sub create_gpg_key {
    my ($self, %params) = @_;
    return $self->client->post('/user/gpg_keys', \%params);
}

=method delete_gpg_key

    $forgejo->current_user->delete_gpg_key($key_id);

Delete a GPG key.

=cut

sub delete_gpg_key {
    my ($self, $key_id) = @_;
    return $self->client->delete('/user/gpg_keys/' . uri_escape($key_id));
}

=method list_hooks

    my $hooks = $forgejo->current_user->list_hooks;

List webhooks for the current user. Named arguments are sent as the query
string of the request.

=cut

sub list_hooks {
    my ($self, %params) = @_;
    return $self->client->get('/user/hooks', params => \%params);
}

=method get_hook

    my $hook = $forgejo->current_user->get_hook($hook_id);

Get a specific webhook.

=cut

sub get_hook {
    my ($self, $hook_id) = @_;
    return $self->client->get('/user/hooks/' . uri_escape($hook_id));
}

=method create_hook

    my $hook = $forgejo->current_user->create_hook(
        type   => 'forgejo',
        config => { url => 'https://example.com/hook', content_type => 'json' },
    );

Create a webhook. The key/value pairs are sent as the JSON body; C<type> and
C<config> are required by the API.

=cut

sub create_hook {
    my ($self, %params) = @_;
    return $self->client->post('/user/hooks', \%params);
}

=method edit_hook

    my $hook = $forgejo->current_user->edit_hook($hook_id, active => \0);

Edit a webhook. The key/value pairs are sent as the JSON body.

=cut

sub edit_hook {
    my ($self, $hook_id, %params) = @_;
    return $self->client->patch('/user/hooks/' . uri_escape($hook_id), \%params);
}

=method delete_hook

    $forgejo->current_user->delete_hook($hook_id);

Delete a webhook.

=cut

sub delete_hook {
    my ($self, $hook_id) = @_;
    return $self->client->delete('/user/hooks/' . uri_escape($hook_id));
}

=method list_applications

    my $apps = $forgejo->current_user->list_applications;

List OAuth2 applications of the current user (C<GET
/user/applications/oauth2>). Named arguments are sent as the query string of
the request.

=cut

sub list_applications {
    my ($self, %params) = @_;
    return $self->client->get('/user/applications/oauth2', params => \%params);
}

=method create_application

    my $app = $forgejo->current_user->create_application(
        name          => 'My App',
        redirect_uris => ['https://example.com/callback'],
    );

Create an OAuth2 application. The key/value pairs are sent as the JSON body.

=cut

sub create_application {
    my ($self, %params) = @_;
    return $self->client->post('/user/applications/oauth2', \%params);
}

=method delete_application

    $forgejo->current_user->delete_application($app_id);

Delete an OAuth2 application.

=cut

sub delete_application {
    my ($self, $app_id) = @_;
    return $self->client->delete('/user/applications/oauth2/' . uri_escape($app_id));
}

=method orgs

    my $orgs = $forgejo->current_user->orgs;

List organizations for the current user. Named arguments are sent as the
query string of the request.

=cut

sub orgs {
    my ($self, %params) = @_;
    return $self->client->get('/user/orgs', params => \%params);
}

=method teams

    my $teams = $forgejo->current_user->teams;

List teams for the current user. Named arguments are sent as the query
string of the request.

=cut

sub teams {
    my ($self, %params) = @_;
    return $self->client->get('/user/teams', params => \%params);
}

=method repos

    my $repos = $forgejo->current_user->repos;

List repositories for the current user. Named arguments are sent as the
query string of the request.

=cut

sub repos {
    my ($self, %params) = @_;
    return $self->client->get('/user/repos', params => \%params);
}

=method starred

    my $starred = $forgejo->current_user->starred;

List starred repositories for the current user. Named arguments are sent as
the query string of the request.

=cut

sub starred {
    my ($self, %params) = @_;
    return $self->client->get('/user/starred', params => \%params);
}

=method subscriptions

    my $subs = $forgejo->current_user->subscriptions;

List watched repositories for the current user. Named arguments are sent as
the query string of the request.

=cut

sub subscriptions {
    my ($self, %params) = @_;
    return $self->client->get('/user/subscriptions', params => \%params);
}

=method followers

    my $followers = $forgejo->current_user->followers;

List followers for the current user. Named arguments are sent as the query
string of the request.

=cut

sub followers {
    my ($self, %params) = @_;
    return $self->client->get('/user/followers', params => \%params);
}

=method following

    my $following = $forgejo->current_user->following;

List the users the current user follows. Named arguments are sent as the
query string of the request.

=cut

sub following {
    my ($self, %params) = @_;
    return $self->client->get('/user/following', params => \%params);
}

=method block

    $forgejo->current_user->block($username);

Block a user (C<PUT /user/block/{username}>).

=cut

sub block {
    my ($self, $username) = @_;
    return $self->client->put('/user/block/' . uri_escape($username));
}

=method unblock

    $forgejo->current_user->unblock($username);

Unblock a user (C<PUT /user/unblock/{username}>).

=cut

sub unblock {
    my ($self, $username) = @_;
    return $self->client->put('/user/unblock/' . uri_escape($username));
}

=method list_blocked

    my $blocked = $forgejo->current_user->list_blocked;

List blocked users (C<GET /user/list_blocked>). Named arguments are sent as
the query string of the request.

=cut

sub list_blocked {
    my ($self, %params) = @_;
    return $self->client->get('/user/list_blocked', params => \%params);
}

=method quota

    my $quota = $forgejo->current_user->quota;

Get quota information for the current user.

=cut

sub quota {
    my ($self) = @_;
    return $self->client->get('/user/quota');
}

=method stopwatches

    my $stopwatches = $forgejo->current_user->stopwatches;

List stopwatches for the current user. Named arguments are sent as the query
string of the request.

=cut

sub stopwatches {
    my ($self, %params) = @_;
    return $self->client->get('/user/stopwatches', params => \%params);
}

=method times

    my $times = $forgejo->current_user->times;

List tracked times for the current user. Named arguments are sent as the
query string of the request.

=cut

sub times {
    my ($self, %params) = @_;
    return $self->client->get('/user/times', params => \%params);
}

=method set_secret

    $forgejo->current_user->set_secret('MY_SECRET', { data => 'secret value' });

Create or update an Actions secret of the current user
(C<PUT /user/actions/secrets/{secretname}>). The hashref is sent as the JSON
body; the API expects the value in C<data>. The API has no call to read
secrets back.

=cut

sub set_secret {
    my ($self, $secret_name, $data) = @_;
    return $self->client->put('/user/actions/secrets/' . uri_escape($secret_name), $data);
}

=method delete_secret

    $forgejo->current_user->delete_secret('MY_SECRET');

Delete an Actions secret of the current user.

=cut

sub delete_secret {
    my ($self, $secret_name) = @_;
    return $self->client->delete('/user/actions/secrets/' . uri_escape($secret_name));
}

=method list_variables

    my $vars = $forgejo->current_user->list_variables;

List the Actions variables of the current user (C<GET
/user/actions/variables>). Named arguments are sent as the query string of
the request.

=cut

sub list_variables {
    my ($self, %params) = @_;
    return $self->client->get('/user/actions/variables', params => \%params);
}

=method list_runners

    my $runners = $forgejo->current_user->list_runners;

List the Actions runners of the current user (C<GET /user/actions/runners>).
Named arguments are sent as the query string of the request.

=cut

sub list_runners {
    my ($self, %params) = @_;
    return $self->client->get('/user/actions/runners', params => \%params);
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $me    = $forgejo->current_user->get;
    my $repos = $forgejo->current_user->repos(limit => 50);
    my $keys  = $forgejo->current_user->list_keys;

    $forgejo->current_user->add_email('new@example.com');

=head1 DESCRIPTION

The C</user/...> endpoints, i.e. everything about the user the API token
belongs to: profile, settings, emails, SSH and GPG keys, webhooks, OAuth2
applications, organizations, repositories, blocks, quota and Actions
secrets, variables and runners. Available as C<< $forgejo->current_user >>.

All methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::API::Users>, L<WWW::Forgejo>

=cut
