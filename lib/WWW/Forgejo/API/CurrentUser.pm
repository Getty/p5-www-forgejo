# ABSTRACT: Forgejo Current User API
# PODNAME: WWW::Forgejo::API::CurrentUser

use strict;
use warnings;

package WWW::Forgejo::API::CurrentUser;

use Moo;
use Log::Any qw($log);

has _client => (
    is       => 'ro',
    init_arg => 'client',
    weak_ref => 1,
);

sub client { shift->_client }

=method get

    my $user = $self->get;

Get the current user.

=cut

sub get {
    my ($self) = @_;
    return $self->client->get('/user');
}

=method settings

    my $settings = $self->client->settings;

Get user settings.

=cut

sub settings {
    my ($self) = @_;
    return $self->client->get('/user/settings');
}

=method update_settings

    my $settings = $self->client->update_settings(theme => 'dark');

Update user settings.

=cut

sub update_settings {
    my ($self, %params) = @_;
    return $self->client->patch('/user/settings', \%params);
}

=method list_emails

    my $emails = $self->client->list_emails;

List emails for the current user.

=cut

sub list_emails {
    my ($self) = @_;
    return $self->client->get('/user/emails');
}

=method add_email

    my $email = $self->client->add_email(email => 'new@example.com');

Add an email address.

=cut

sub add_email {
    my ($self, %params) = @_;
    return $self->client->post('/user/emails', \%params);
}

=method delete_email

    $self->client->delete_email($email);

Delete an email address.

=cut

sub delete_email {
    my ($self, $email) = @_;
    return $self->client->delete("/user/emails/$email");
}

=method list_keys

    my $keys = $self->client->list_keys;

List public keys for the current user.

=cut

sub list_keys {
    my ($self) = @_;
    return $self->client->get('/user/keys');
}

=method get_key

    my $key = $self->client->get_key($key_id);

Get a specific public key.

=cut

sub get_key {
    my ($self, $key_id) = @_;
    return $self->client->get("/user/keys/$key_id");
}

=method create_key

    my $key = $self->client->create_key(title => 'My Key', key => $public_key);

Create a public key.

=cut

sub create_key {
    my ($self, %params) = @_;
    return $self->client->post('/user/keys', \%params);
}

=method delete_key

    $self->client->delete_key($key_id);

Delete a public key.

=cut

sub delete_key {
    my ($self, $key_id) = @_;
    return $self->client->delete("/user/keys/$key_id");
}

=method list_gpg_keys

    my $keys = $self->client->list_gpg_keys;

List GPG keys for the current user.

=cut

sub list_gpg_keys {
    my ($self) = @_;
    return $self->client->get('/user/gpg_keys');
}

=method get_gpg_key

    my $key = $self->client->get_gpg_key($key_id);

Get a specific GPG key.

=cut

sub get_gpg_key {
    my ($self, $key_id) = @_;
    return $self->client->get("/user/gpg_keys/$key_id");
}

=method create_gpg_key

    my $key = $self->client->create_gpg_key(armor => $gpg_key);

Create a GPG key.

=cut

sub create_gpg_key {
    my ($self, %params) = @_;
    return $self->client->post('/user/gpg_keys', \%params);
}

=method delete_gpg_key

    $self->client->delete_gpg_key($key_id);

Delete a GPG key.

=cut

sub delete_gpg_key {
    my ($self, $key_id) = @_;
    return $self->client->delete("/user/gpg_keys/$key_id");
}

=method list_hooks

    my $hooks = $self->client->list_hooks;

List webhooks for the current user.

=cut

sub list_hooks {
    my ($self) = @_;
    return $self->client->get('/user/hooks');
}

=method get_hook

    my $hook = $self->client->get_hook($hook_id);

Get a specific webhook.

=cut

sub get_hook {
    my ($self, $hook_id) = @_;
    return $self->client->get("/user/hooks/$hook_id");
}

=method create_hook

    my $hook = $self->client->create_hook(
        type => 'web',
        url => 'https://example.com/hook',
    );

Create a webhook.

=cut

sub create_hook {
    my ($self, %params) = @_;
    return $self->client->post('/user/hooks', \%params);
}

=method edit_hook

    my $hook = $self->client->edit_hook($hook_id, url => 'https://example.com/new-hook');

Edit a webhook.

=cut

sub edit_hook {
    my ($self, $hook_id, %params) = @_;
    return $self->client->patch("/user/hooks/$hook_id", \%params);
}

=method delete_hook

    $self->client->delete_hook($hook_id);

Delete a webhook.

=cut

sub delete_hook {
    my ($self, $hook_id) = @_;
    return $self->client->delete("/user/hooks/$hook_id");
}

=method list_applications

    my $apps = $self->client->list_applications;

List OAuth2 applications for the current user.

=cut

sub list_applications {
    my ($self) = @_;
    return $self->client->get('/user/applications');
}

=method create_application

    my $app = $self->client->create_application(name => 'My App');

Create an OAuth2 application.

=cut

sub create_application {
    my ($self, %params) = @_;
    return $self->client->post('/user/applications', \%params);
}

=method delete_application

    $self->client->delete_application($app_id);

Delete an OAuth2 application.

=cut

sub delete_application {
    my ($self, $app_id) = @_;
    return $self->client->delete("/user/applications/$app_id");
}

=method orgs

    my $orgs = $self->client->orgs;

List organizations for the current user.

=cut

sub orgs {
    my ($self) = @_;
    return $self->client->get('/user/orgs');
}

=method teams

    my $teams = $self->client->teams;

List teams for the current user.

=cut

sub teams {
    my ($self) = @_;
    return $self->client->get('/user/teams');
}

=method repos

    my $repos = $self->client->repos;

List repositories for the current user.

=cut

sub repos {
    my ($self) = @_;
    return $self->client->get('/user/repos');
}

=method starred

    my $starred = $self->client->starred;

List starred repositories for the current user.

=cut

sub starred {
    my ($self) = @_;
    return $self->client->get('/user/starred');
}

=method subscriptions

    my $subs = $self->client->subscriptions;

List watched repositories for the current user.

=cut

sub subscriptions {
    my ($self) = @_;
    return $self->client->get('/user/subscriptions');
}

=method followers

    my $followers = $self->client->followers;

List followers for the current user.

=cut

sub followers {
    my ($self) = @_;
    return $self->client->get('/user/followers');
}

=method following

    my $following = $self->client->following;

List following for the current user.

=cut

sub following {
    my ($self) = @_;
    return $self->client->get('/user/following');
}

=method block

    $self->client->block($username);

Block a user.

=cut

sub block {
    my ($self, $username) = @_;
    return $self->client->put("/user/blocks/$username");
}

=method unblock

    $self->client->unblock($username);

Unblock a user.

=cut

sub unblock {
    my ($self, $username) = @_;
    return $self->client->delete("/user/blocks/$username");
}

=method list_blocked

    my $blocked = $self->client->list_blocked;

List blocked users.

=cut

sub list_blocked {
    my ($self) = @_;
    return $self->client->get('/user/blocks');
}

=method quota

    my $quota = $self->client->quota;

Get quota information for the current user.

=cut

sub quota {
    my ($self) = @_;
    return $self->client->get('/user/quota');
}

=method stopwatches

    my $stopwatches = $self->client->stopwatches;

List stopwatches for the current user.

=cut

sub stopwatches {
    my ($self) = @_;
    return $self->client->get('/user/stopwatches');
}

=method times

    my $times = $self->client->times;

List times for the current user.

=cut

sub times {
    my ($self) = @_;
    return $self->client->get('/user/times');
}

=method list_secrets

    my $secrets = $self->client->list_secrets;

List secrets for the current user.

=cut

sub list_secrets {
    my ($self) = @_;
    return $self->client->get('/user/secrets');
}

=method get_secret

    my $secret = $self->client->get_secret($secret_name);

Get a specific secret.

=cut

sub get_secret {
    my ($self, $secret_name) = @_;
    return $self->client->get("/user/secrets/$secret_name");
}

=method create_secret

    my $secret = $self->client->create_secret(
        secret_name => 'my_secret',
        data => { key => 'value' },
    );

Create a secret.

=cut

sub create_secret {
    my ($self, %params) = @_;
    return $self->client->post('/user/secrets', \%params);
}

=method delete_secret

    $self->client->delete_secret($secret_name);

Delete a secret.

=cut

sub delete_secret {
    my ($self, $secret_name) = @_;
    return $self->client->delete("/user/secrets/$secret_name");
}

=method list_variables

    my $vars = $self->client->list_variables;

List variables for the current user.

=cut

sub list_variables {
    my ($self) = @_;
    return $self->client->get('/user/variables');
}

=method list_runners

    my $runners = $self->client->list_runners;

List runners for the current user.

=cut

sub list_runners {
    my ($self) = @_;
    return $self->client->get('/user/runners');
}

1;