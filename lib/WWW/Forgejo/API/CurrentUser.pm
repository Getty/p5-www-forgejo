# ABSTRACT: Forgejo Current User API
# PODNAME: WWW::Forgejo::API::CurrentUser

use strict;
use warnings;

package WWW::Forgejo::API::CurrentUser;

use Moo;
use Carp qw(croak);
use WWW::Forgejo::URL qw( escape_component );
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
    return $self->client->get('/user/keys/' . escape_component($key_id));
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
    return $self->client->delete('/user/keys/' . escape_component($key_id));
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
    return $self->client->get('/user/gpg_keys/' . escape_component($key_id));
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
    return $self->client->delete('/user/gpg_keys/' . escape_component($key_id));
}

=method gpg_key_token

    my $token = $forgejo->current_user->gpg_key_token;

Get the token to sign a commit with the GPG key of the current user
(C<GET /user/gpg_key_token>). The token is returned as a plain structure.

=cut

sub gpg_key_token {
    my ($self) = @_;
    return $self->client->get('/user/gpg_key_token');
}

=method verify_gpg_key

    my $key = $forgejo->current_user->verify_gpg_key(
        armored_signature => $signature,
        key_id            => $key_id,
    );

Verify a GPG key of the current user (C<POST /user/gpg_key_verify>). The
key/value pairs are sent as the JSON body; the API takes the
C<armored_signature> and the C<key_id>.

=cut

sub verify_gpg_key {
    my ($self, %params) = @_;
    croak "Armored signature required" unless $params{armored_signature};
    croak "Key ID required" unless $params{key_id};
    return $self->client->post('/user/gpg_key_verify', \%params);
}

=method set_avatar

    $forgejo->current_user->set_avatar(image => $base64);

Set the avatar of the current user (C<POST /user/avatar>). The named
arguments are sent as the JSON body; the API expects the image in C<image>,
as a base64 encoded string. Returns true.

=cut

sub set_avatar {
    my ($self, %params) = @_;
    croak "Avatar image required" unless defined $params{image} && length $params{image};
    $self->client->post('/user/avatar', \%params);
    return 1;
}

=method delete_avatar

    $forgejo->current_user->delete_avatar;

Delete the avatar of the current user (C<DELETE /user/avatar>); the user gets
the default avatar. Returns true.

=cut

sub delete_avatar {
    my ($self) = @_;
    $self->client->delete('/user/avatar');
    return 1;
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
    return $self->client->get('/user/hooks/' . escape_component($hook_id));
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
    return $self->client->patch('/user/hooks/' . escape_component($hook_id), \%params);
}

=method delete_hook

    $forgejo->current_user->delete_hook($hook_id);

Delete a webhook.

=cut

sub delete_hook {
    my ($self, $hook_id) = @_;
    return $self->client->delete('/user/hooks/' . escape_component($hook_id));
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
    return $self->client->delete('/user/applications/oauth2/' . escape_component($app_id));
}

=method get_application

    my $app = $forgejo->current_user->get_application($app_id);

Get an OAuth2 application of the current user
(C<GET /user/applications/oauth2/{id}>).

=cut

sub get_application {
    my ($self, $app_id) = @_;
    croak "Application ID required" unless defined $app_id && length $app_id;
    return $self->client->get('/user/applications/oauth2/' . escape_component($app_id));
}

=method edit_application

    my $app = $forgejo->current_user->edit_application($app_id, name => 'New name');

Edit an OAuth2 application of the current user
(C<PATCH /user/applications/oauth2/{id}>). The key/value pairs are sent as the
JSON body.

=cut

sub edit_application {
    my ($self, $app_id, %params) = @_;
    croak "Application ID required" unless defined $app_id && length $app_id;
    return $self->client->patch('/user/applications/oauth2/' . escape_component($app_id), \%params);
}

=method activitypub_follow

    $forgejo->current_user->activitypub_follow(target => 'https://example.com/user');

Follow an actor of the fediverse (C<POST /user/activitypub/follow>). The
named arguments are sent as the JSON body; the API takes the C<target>, the
URL of the actor.

=cut

sub activitypub_follow {
    my ($self, %params) = @_;
    croak "Target required" unless defined $params{target} && length $params{target};
    $self->client->post('/user/activitypub/follow', \%params);
    return 1;
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

=method star

    $forgejo->current_user->star($owner, $repo);

Star a repository (C<PUT /user/starred/{owner}/{repo}>). Returns true; the API
sends no data back.

=cut

sub star {
    my ($self, $owner, $repo) = @_;
    croak "Repository owner required" unless defined $owner && length $owner;
    croak "Repository name required" unless defined $repo && length $repo;
    $self->client->put('/user/starred/' . escape_component($owner) . '/' . escape_component($repo));
    return 1;
}

=method unstar

    $forgejo->current_user->unstar($owner, $repo);

Remove the star from a repository (C<DELETE /user/starred/{owner}/{repo}>).

=cut

sub unstar {
    my ($self, $owner, $repo) = @_;
    croak "Repository owner required" unless defined $owner && length $owner;
    croak "Repository name required" unless defined $repo && length $repo;
    return $self->client->delete('/user/starred/' . escape_component($owner) . '/' . escape_component($repo));
}

=method check_starred

    my $is_starred = $forgejo->current_user->check_starred($owner, $repo);

Check whether the current user starred a repository (C<GET
/user/starred/{owner}/{repo}>). Returns true or false; the API answers this
with its status code only.

=cut

sub check_starred {
    my ($self, $owner, $repo) = @_;
    croak "Repository owner required" unless defined $owner && length $owner;
    croak "Repository name required" unless defined $repo && length $repo;
    return $self->client->check('/user/starred/' . escape_component($owner) . '/' . escape_component($repo));
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

=method follow

    $forgejo->current_user->follow($username);

Follow a user (C<PUT /user/following/{username}>). Returns true; the API sends
no data back.

=cut

sub follow {
    my ($self, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    $self->client->put('/user/following/' . escape_component($username));
    return 1;
}

=method unfollow

    $forgejo->current_user->unfollow($username);

Stop following a user (C<DELETE /user/following/{username}>).

=cut

sub unfollow {
    my ($self, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->delete('/user/following/' . escape_component($username));
}

=method check_following

    my $is_following = $forgejo->current_user->check_following($username);

Check whether the current user follows a user (C<GET
/user/following/{username}>). Returns true or false; the API answers this with
its status code only.

=cut

sub check_following {
    my ($self, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->check('/user/following/' . escape_component($username));
}

=method block

    $forgejo->current_user->block($username);

Block a user (C<PUT /user/block/{username}>).

=cut

sub block {
    my ($self, $username) = @_;
    return $self->client->put('/user/block/' . escape_component($username));
}

=method unblock

    $forgejo->current_user->unblock($username);

Unblock a user (C<PUT /user/unblock/{username}>).

=cut

sub unblock {
    my ($self, $username) = @_;
    return $self->client->put('/user/unblock/' . escape_component($username));
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

    $forgejo->current_user->set_secret('MY_SECRET', data => 'secret value');

Create or update an Actions secret of the current user
(C<PUT /user/actions/secrets/{secretname}>). The named arguments are sent as
the JSON body; the API expects the value in C<data>. The API has no call to
read secrets back.

=cut

sub set_secret {
    my ($self, $secret_name, %params) = @_;
    return $self->client->put('/user/actions/secrets/' . escape_component($secret_name), \%params);
}

=method delete_secret

    $forgejo->current_user->delete_secret('MY_SECRET');

Delete an Actions secret of the current user.

=cut

sub delete_secret {
    my ($self, $secret_name) = @_;
    return $self->client->delete('/user/actions/secrets/' . escape_component($secret_name));
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

=method get_runner

    my $runner = $forgejo->current_user->get_runner($runner_id);

Get one Actions runner of the current user (C<GET
/user/actions/runners/{runner_id}>).

=cut

sub get_runner {
    my ($self, $runner_id) = @_;
    return $self->client->get('/user/actions/runners/' . escape_component($runner_id));
}

=method create_runner

    $forgejo->current_user->create_runner(name => 'runner-1', description => 'A runner');

Register an Actions runner for the current user (C<POST /user/actions/runners>).
The named arguments are sent as the JSON body; the API takes C<name> and takes
C<description> and C<ephemeral> as well.

=cut

sub create_runner {
    my ($self, %params) = @_;
    return $self->client->post('/user/actions/runners', \%params);
}

=method delete_runner

    $forgejo->current_user->delete_runner($runner_id);

Delete an Actions runner of the current user (C<DELETE
/user/actions/runners/{runner_id}>).

=cut

sub delete_runner {
    my ($self, $runner_id) = @_;
    return $self->client->delete('/user/actions/runners/' . escape_component($runner_id));
}

=method list_runner_jobs

    my $jobs = $forgejo->current_user->list_runner_jobs;

List the jobs of all Actions runners of the current user (C<GET
/user/actions/runners/jobs>). Named arguments are sent as the query string
(C<labels>).

=cut

sub list_runner_jobs {
    my ($self, %params) = @_;
    return $self->client->get('/user/actions/runners/jobs', params => \%params);
}

=method get_runner_registration_token

    my $token = $forgejo->current_user->get_runner_registration_token;

Get the registration token of the Actions runners of the current user (C<GET
/user/actions/runners/registration-token>).

=cut

sub get_runner_registration_token {
    my ($self) = @_;
    return $self->client->get('/user/actions/runners/registration-token');
}

=method get_variable

    my $variable = $forgejo->current_user->get_variable('STAGE');

Get an Actions variable of the current user by name (C<GET
/user/actions/variables/{variablename}>).

=cut

sub get_variable {
    my ($self, $name) = @_;
    return $self->client->get('/user/actions/variables/' . escape_component($name));
}

=method create_variable

    $forgejo->current_user->create_variable('STAGE', value => 'prod');

Create an Actions variable of the current user (C<POST
/user/actions/variables/{variablename}>). The named arguments are sent as the
JSON body; the API expects the value in C<value>.

=cut

sub create_variable {
    my ($self, $name, %params) = @_;
    return $self->client->post('/user/actions/variables/' . escape_component($name), \%params);
}

=method set_variable

    $forgejo->current_user->set_variable('STAGE', value => 'test');
    $forgejo->current_user->set_variable('STAGE', value => 'test', name => 'ENV');

Update an Actions variable of the current user (C<PUT
/user/actions/variables/{variablename}>). The named arguments are sent as the
JSON body; the API expects the value in C<value> and renames the variable with
C<name>.

=cut

sub set_variable {
    my ($self, $name, %params) = @_;
    return $self->client->put('/user/actions/variables/' . escape_component($name), \%params);
}

=method delete_variable

    $forgejo->current_user->delete_variable('STAGE');

Delete an Actions variable of the current user (C<DELETE
/user/actions/variables/{variablename}>).

=cut

sub delete_variable {
    my ($self, $name) = @_;
    return $self->client->delete('/user/actions/variables/' . escape_component($name));
}

=method quota_artifacts

    my $artifacts = $forgejo->current_user->quota_artifacts;

List the artifacts of the current user that count against the quota (C<GET
/user/quota/artifacts>). Named arguments are sent as the query string (C<page>,
C<limit>).

=cut

sub quota_artifacts {
    my ($self, %params) = @_;
    return $self->client->get('/user/quota/artifacts', params => \%params);
}

=method quota_attachments

    my $attachments = $forgejo->current_user->quota_attachments;

List the attachments of the current user that count against the quota (C<GET
/user/quota/attachments>). Named arguments are sent as the query string
(C<page>, C<limit>).

=cut

sub quota_attachments {
    my ($self, %params) = @_;
    return $self->client->get('/user/quota/attachments', params => \%params);
}

=method quota_packages

    my $packages = $forgejo->current_user->quota_packages;

List the packages of the current user that count against the quota (C<GET
/user/quota/packages>). Named arguments are sent as the query string (C<page>,
C<limit>).

=cut

sub quota_packages {
    my ($self, %params) = @_;
    return $self->client->get('/user/quota/packages', params => \%params);
}

=method quota_check

    my $ok = $forgejo->current_user->quota_check(subject => 'size:repos:all');

Check whether the current user has quota left for a subject (C<GET
/user/quota/check>). The named arguments are sent as the query string; the API
requires the C<subject> to check. Returns true or false.

=cut

sub quota_check {
    my ($self, %params) = @_;
    croak "Quota subject required" unless defined $params{subject} && length $params{subject};
    return $self->client->get('/user/quota/check', params => \%params);
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
applications, organizations, repositories, blocks, stars and follows, quota and
Actions secrets, variables and runners. Available as
C<< $forgejo->current_user >>.

All methods return the decoded JSON response as plain Perl data. The methods
that star a repository or follow a user (C<star>, C<unstar>, C<follow>,
C<unfollow>) get no data back and return true; the C<check_starred> and
C<check_following> methods answer a question and return true or false.

=head1 SEE ALSO

L<WWW::Forgejo::API::Users>, L<WWW::Forgejo>

=cut
