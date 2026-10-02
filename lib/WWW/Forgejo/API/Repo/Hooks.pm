# ABSTRACT: Forgejo Repo Hooks API
# PODNAME: WWW::Forgejo::API::Repo::Hooks

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Hooks;

use Moo;
use URI::Escape qw(uri_escape);
use WWW::Forgejo::Entity::Hook;
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
    return $self->_repo_path('hooks', @path);
}

sub _hook {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::Hook->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method list

    my @hooks = $repo->hooks->list;

List all hooks as L<WWW::Forgejo::Entity::Hook> objects. Named arguments are
sent as the query string.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return map { $self->_hook($_) } @$data;
}

=method get

    my $hook = $repo->hooks->get($id);

Get a specific hook by ID.

=cut

sub get {
    my ($self, $id) = @_;
    return $self->_hook($self->client->get($self->_path_for(uri_escape($id))));
}

=method create

    my $hook = $repo->hooks->create({
        type   => 'forgejo',
        config => { url => 'https://example.com/hook', content_type => 'json' },
        events => ['push'],
    });

Create a new hook; the API requires C<type> and C<config>.

=cut

sub create {
    my ($self, $data) = @_;
    return $self->_hook($self->client->post($self->_path_for, $data));
}

=method update

    my $hook = $repo->hooks->update($id, { active => \0 });

Update a hook.

=cut

sub update {
    my ($self, $id, $data) = @_;
    return $self->_hook($self->client->patch($self->_path_for(uri_escape($id)), $data));
}

=method edit

Alias for L</update>.

=cut

sub edit { shift->update(@_) }

=method delete

    $repo->hooks->delete($id);

Delete a hook.

=cut

sub delete {
    my ($self, $id) = @_;
    return $self->client->delete($self->_path_for(uri_escape($id)));
}

=method test

    $repo->hooks->test($id);
    $repo->hooks->test($id, ref => 'main');

Trigger a test delivery of a hook. Named arguments are sent as the query
string; C<ref> names the git reference the test payload is built from. This is
the only way the API offers to exercise a hook; it has no separate ping.

=cut

sub test {
    my ($self, $id, %params) = @_;
    return $self->client->post($self->_path_for(uri_escape($id), 'tests'), undef, params => \%params);
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @hooks = $repo->hooks->list;

    my $hook = $repo->hooks->get(1);

    $hook = $repo->hooks->create({
        type   => 'forgejo',
        config => { url => 'https://example.com/hook', content_type => 'json' },
        events => ['push', 'pull_request'],
        active => \1,
    });

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/hooks> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/hooks>, which binds it to
that repository; every method then addresses that repository.

Depending on the method, results are L<WWW::Forgejo::Entity::Hook>
objects or the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::Hook>, L<WWW::Forgejo>

=cut
