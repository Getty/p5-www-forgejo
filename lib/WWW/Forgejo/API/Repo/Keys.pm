# ABSTRACT: Forgejo Repo Keys API
# PODNAME: WWW::Forgejo::API::Repo::Keys

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Keys;

use Moo;
use URI::Escape qw(uri_escape);
use WWW::Forgejo::Entity::DeployKey;
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

# /repos/{owner}/{repo}/... of the repository this controller is bound to.
sub _repo_path {
    my ($self, @path) = @_;
    return join '/', '/repos', uri_escape($self->owner), uri_escape($self->repo), @path;
}

sub _path_for {
    my ($self, @path) = @_;
    return $self->_repo_path('keys', @path);
}

sub _key {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::DeployKey->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method list

    my @keys = $repo->keys->list;
    my @keys = $repo->keys->list(fingerprint => $fingerprint);

List the deploy keys as L<WWW::Forgejo::Entity::DeployKey> objects. Named
arguments are sent as the query string (C<key_id>, C<fingerprint>, C<page>,
C<limit>).

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return map { $self->_key($_) } @$data;
}

=method get

    my $key = $repo->keys->get($id);

Get a specific deploy key by ID.

=cut

sub get {
    my ($self, $id) = @_;
    return $self->_key($self->client->get($self->_path_for(uri_escape($id))));
}

=method create

    my $key = $repo->keys->create({ title => 'Deploy Key', key => 'ssh-ed25519 AAAA...' });

Add a deploy key; the API requires C<title> and C<key>.

=cut

sub create {
    my ($self, $data) = @_;
    return $self->_key($self->client->post($self->_path_for, $data));
}

=method delete

    $repo->keys->delete($id);

Delete a deploy key.

=cut

sub delete {
    my ($self, $id) = @_;
    return $self->client->delete($self->_path_for(uri_escape($id)));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @keys = $repo->keys->list;

    my $key = $repo->keys->get(1);

    $key = $repo->keys->create({
        title     => 'Deploy Key',
        key       => 'ssh-ed25519 AAAA...',
        read_only => \1,
    });

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/keys> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/keys>, which binds it to
that repository; every method then addresses that repository.

Depending on the method, results are L<WWW::Forgejo::Entity::DeployKey>
objects or the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::DeployKey>, L<WWW::Forgejo>

=cut
