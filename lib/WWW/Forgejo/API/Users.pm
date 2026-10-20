# ABSTRACT: Forgejo Users API
# PODNAME: WWW::Forgejo::API::Users

use strict;
use warnings;

package WWW::Forgejo::API::Users;

use Moo;
use Carp qw(croak);
use WWW::Forgejo::URL qw( escape_component );
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

sub _user_path {
    my ($self, $username, @path) = @_;
    croak "Username required" unless defined $username && length $username;
    return join '/', '/users', escape_component($username), @path;
}

=method search

    my $result = $forgejo->users->search(q => 'getty', limit => 10);
    my $result = $forgejo->users->search('getty');   # same as q => 'getty'

Search for users (C<GET /users/search>). Named arguments are sent as the query
string of the request (C<q>, C<uid>, C<sort>, C<page>, C<limit>); a single
argument is shorthand for the search term C<q>. Returns the decoded response,
an object whose C<data> member holds the users.

=cut

sub search {
    my ($self, @args) = @_;
    my %params = @args % 2 ? (q => $args[0]) : @args;
    return $self->client->get('/users/search', params => \%params);
}

=method get

    my $user = $forgejo->users->get($username);

Get a user by username.

=cut

sub get {
    my ($self, $username) = @_;
    return $self->client->get($self->_user_path($username));
}

=method keys

    my $keys = $forgejo->users->keys($username);

List public keys for a user. Further named arguments are sent as the query
string of the request.

=cut

sub keys {
    my ($self, $username, %params) = @_;
    return $self->client->get($self->_user_path($username, 'keys'), params => \%params);
}

=method gpg_keys

    my $keys = $forgejo->users->gpg_keys($username);

List GPG keys for a user. Further named arguments are sent as the query string
of the request.

=cut

sub gpg_keys {
    my ($self, $username, %params) = @_;
    return $self->client->get($self->_user_path($username, 'gpg_keys'), params => \%params);
}

=method followers

    my $followers = $forgejo->users->followers($username);

List followers for a user. Further named arguments are sent as the query string
of the request.

=cut

sub followers {
    my ($self, $username, %params) = @_;
    return $self->client->get($self->_user_path($username, 'followers'), params => \%params);
}

=method following

    my $following = $forgejo->users->following($username);

List the users a user follows. Further named arguments are sent as the query
string of the request.

=cut

sub following {
    my ($self, $username, %params) = @_;
    return $self->client->get($self->_user_path($username, 'following'), params => \%params);
}

=method following_check

    my $follows = $forgejo->users->following_check('user', 'other');

Tell whether a user follows another one
(C<GET /users/{username}/following/{target}>). The answer of the API is the
plain structure of the relation.

=cut

sub following_check {
    my ($self, $username, $target) = @_;
    croak "User name required" unless defined $username && length $username;
    croak "Target user required" unless defined $target && length $target;
    return $self->client->get(
        $self->_user_path($username, 'following', escape_component($target)));
}

=method starred

    my $starred = $forgejo->users->starred($username);

List starred repositories for a user. Further named arguments are sent as the
query string of the request.

=cut

sub starred {
    my ($self, $username, %params) = @_;
    return $self->client->get($self->_user_path($username, 'starred'), params => \%params);
}

=method subscriptions

    my $subs = $forgejo->users->subscriptions($username);

List watched repositories for a user. Further named arguments are sent as the
query string of the request.

=cut

sub subscriptions {
    my ($self, $username, %params) = @_;
    return $self->client->get($self->_user_path($username, 'subscriptions'), params => \%params);
}

=method repos

    my $repos = $forgejo->users->repos($username);

List repositories for a user. Further named arguments are sent as the query
string of the request.

=cut

sub repos {
    my ($self, $username, %params) = @_;
    return $self->client->get($self->_user_path($username, 'repos'), params => \%params);
}

=method orgs

    my $orgs = $forgejo->users->orgs($username);

List the organizations of a user. Further named arguments are sent as the query
string of the request.

=cut

sub orgs {
    my ($self, $username, %params) = @_;
    return $self->client->get($self->_user_path($username, 'orgs'), params => \%params);
}

=method org_permissions

    my $permissions = $forgejo->users->org_permissions('user', 'my-org');

Get the permissions a user has in an organization
(C<GET /users/{username}/orgs/{org}/permissions>). The permissions are returned
as a plain structure.

=cut

sub org_permissions {
    my ($self, $username, $org) = @_;
    croak "User name required" unless defined $username && length $username;
    croak "Organization name required" unless defined $org && length $org;
    return $self->client->get(
        $self->_user_path($username, 'orgs', escape_component($org), 'permissions'));
}

=method tokens

    my $tokens = $forgejo->users->tokens($username);
    my $tokens = $forgejo->users->tokens($username,
        auth => { user => $username, password => $password });

List access tokens for a user (C<GET /users/{username}/tokens>). Further named
arguments are sent as the query string of the request.

C<auth> is not a query parameter: it holds the credentials (C<user> and
C<password>) the request is authenticated with, in place of the token of the
client (see L<WWW::Forgejo::Role::HTTP>).

=cut

sub tokens {
    my ($self, $username, %params) = @_;
    my $auth = delete $params{auth};
    return $self->client->get($self->_user_path($username, 'tokens'),
        params => \%params, (defined $auth ? (auth => $auth) : ()));
}

=method create_token

    my $token = $forgejo->users->create_token('getty',
        name => 'ci', scopes => ['all'],
        auth => { user => 'getty', password => $password });

Create an access token for a user (C<POST /users/{username}/tokens>). The named
arguments C<name> and C<scopes> are sent as the JSON body of the request.

Forgejo wants basic authentication for this: the token of the client may not
create a token for another user (it answers with C<auth method not allowed>).
The credentials of the user go into C<auth>:

    my $token = $forgejo->users->create_token('getty',
        name => 'ci', scopes => ['all'],
        auth => { user => 'getty', password => $password });

The answer holds the new token in C<sha1>; it is shown only this once.

=cut

sub create_token {
    my ($self, $username, %params) = @_;
    my $auth = delete $params{auth};
    return $self->client->post($self->_user_path($username, 'tokens'), \%params,
        (defined $auth ? (auth => $auth) : ()));
}

=method delete_token

    $forgejo->users->delete_token('getty', 'ci',
        auth => { user => 'getty', password => $password });

Delete an access token of a user
(C<DELETE /users/{username}/tokens/{token}>).

The C<token> is the B<name> of the token, not the secret it holds: Forgejo
answers with C<404> for a secret. Like the creation of a token, the deletion
wants basic authentication - the C<auth> option holds the credentials of the
user.

=cut

sub delete_token {
    my ($self, $username, $token, %params) = @_;
    my $auth = delete $params{auth};
    croak "Token name required" unless defined $token && length $token;
    return $self->client->delete(
        $self->_user_path($username, 'tokens', escape_component($token)), undef,
        (defined $auth ? (auth => $auth) : ()));
}

=method heatmap

    my $heatmap = $forgejo->users->heatmap($username);

Get contribution heatmap for a user.

=cut

sub heatmap {
    my ($self, $username) = @_;
    return $self->client->get($self->_user_path($username, 'heatmap'));
}

=method activities

    my $activities = $forgejo->users->activities($username);

Get the activity feed of a user (C<GET /users/{username}/activities/feeds>).
Further named arguments are sent as the query string of the request.

=cut

sub activities {
    my ($self, $username, %params) = @_;
    return $self->client->get($self->_user_path($username, 'activities', 'feeds'), params => \%params);
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $user   = $forgejo->users->get('getty');
    my $result = $forgejo->users->search(q => 'getty', limit => 10);
    my $repos  = $forgejo->users->repos('getty');

=head1 DESCRIPTION

The C</users/...> endpoints: look up and search users, read their public
keys, followers, repositories and activity and manage their access tokens.
Available as C<< $forgejo->users >>. For the user the token belongs to see
L<WWW::Forgejo::API::CurrentUser>.

All methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::API::CurrentUser>, L<WWW::Forgejo>

=cut
