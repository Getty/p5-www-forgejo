# ABSTRACT: Forgejo Users API
# PODNAME: WWW::Forgejo::API::Users

use strict;
use warnings;

package WWW::Forgejo::API::Users;

use Moo;
use Log::Any qw($log);
use Carp qw(croak);

has _client => (
    is       => 'ro',
    init_arg => 'client',
    weak_ref => 1,
);

sub client { shift->_client }

sub _get        { shift->_client->get(@_)        }
sub _post       { shift->_client->post(@_)       }
sub _put        { shift->_client->put(@_)        }
sub _delete     { shift->_client->delete(@_)     }
sub _patch      { shift->_client->patch(@_)      }

=method search

    my $users = $self->search(limit => 10);

Search for users.

=cut

sub search {
    my ($self, %params) = @_;
    croak "query parameter required" unless exists $params{query};
    return $self->_client->get('/users/search', params => \%params);
}

=method get

    my $user = $self->get($username);

Get a user by username.

=cut

sub get {
    my ($self, $username) = @_;
    return $self->_client->get("/users/$username");
}

=method keys

    my $keys = $self->keys($username);

List public keys for a user.

=cut

sub keys {
    my ($self, $username) = @_;
    return $self->_client->get("/users/$username/keys");
}

=method gpg_keys

    my $keys = $self->gpg_keys($username);

List GPG keys for a user.

=cut

sub gpg_keys {
    my ($self, $username) = @_;
    return $self->_client->get("/users/$username/gpg_keys");
}

=method followers

    my $followers = $self->followers($username);

List followers for a user.

=cut

sub followers {
    my ($self, $username) = @_;
    return $self->_client->get("/users/$username/followers");
}

=method following

    my $following = $self->following($username);

List following for a user.

=cut

sub following {
    my ($self, $username) = @_;
    return $self->_client->get("/users/$username/following");
}

=method starred

    my $starred = $self->starred($username);

List starred repositories for a user.

=cut

sub starred {
    my ($self, $username) = @_;
    return $self->_client->get("/users/$username/starred");
}

=method subscriptions

    my $subs = $self->subscriptions($username);

List watched repositories for a user.

=cut

sub subscriptions {
    my ($self, $username) = @_;
    return $self->_client->get("/users/$username/subscriptions");
}

=method repos

    my $repos = $self->repos($username);

List repositories for a user.

=cut

sub repos {
    my ($self, $username) = @_;
    return $self->_client->get("/users/$username/repos");
}

=method tokens

    my $tokens = $self->tokens($username);

List access tokens for a user. Requires admin permissions.

=cut

sub tokens {
    my ($self, $username) = @_;
    return $self->_client->get("/users/$username/tokens");
}

=method heatmap

    my $heatmap = $self->heatmap($username);

Get contribution heatmap for a user.

=cut

sub heatmap {
    my ($self, $username) = @_;
    return $self->_client->get("/users/$username/heatmap");
}

=method activities

    my $activities = $self->activities($username);

Get activities for a user.

=cut

sub activities {
    my ($self, $username) = @_;
    return $self->_client->get("/users/$username/activities");
}

1;