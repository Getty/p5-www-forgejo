# ABSTRACT: Forgejo Repo Collaborators API
# PODNAME: WWW::Forgejo::API::Repo::Collaborators

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Collaborators;

use Moo;
use URI::Escape qw(uri_escape);
use WWW::Forgejo::Entity::Collaborator;
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
    return $self->_repo_path('collaborators', @path);
}

=method list

    my @collaborators = $repo->collaborators->list;

List all collaborators as L<WWW::Forgejo::Entity::Collaborator> objects. Named
arguments are sent as the query string.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return map {
        WWW::Forgejo::Entity::Collaborator->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

=method check

    my $bool = $repo->collaborators->check($username);

Check whether a user is a collaborator of the repository. Returns true or
false; the API answers this with its status code only.

=cut

sub check {
    my ($self, $username) = @_;
    return $self->client->check($self->_path_for(uri_escape($username)));
}

=method add

    $repo->collaborators->add($username, { permission => 'write' });

Add a collaborator, or change the permission of an existing one. C<permission>
is one of C<read>, C<write> or C<admin>. Returns true; the API sends no data
back.

=cut

sub add {
    my ($self, $username, $data) = @_;
    $self->client->put($self->_path_for(uri_escape($username)), $data);
    return 1;
}

=method remove

    $repo->collaborators->remove($username);

Remove a collaborator.

=cut

sub remove {
    my ($self, $username) = @_;
    return $self->client->delete($self->_path_for(uri_escape($username)));
}

=method permission

    my $permission = $repo->collaborators->permission($username);
    print $permission->{permission};    # e.g. "write"

Get the repository permission of a user: a structure with C<permission>,
C<role_name> and C<user>.

=cut

sub permission {
    my ($self, $username) = @_;
    return $self->client->get($self->_path_for(uri_escape($username), 'permission'));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @collaborators = $repo->collaborators->list;

    if ($repo->collaborators->check('username')) { ... }

    $repo->collaborators->add('username', { permission => 'write' });

    my $permission = $repo->collaborators->permission('username');

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/collaborators> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/collaborators>, which binds it to
that repository; every method then addresses that repository.

Depending on the method, results are L<WWW::Forgejo::Entity::Collaborator>
objects or the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::Collaborator>, L<WWW::Forgejo>

=cut
