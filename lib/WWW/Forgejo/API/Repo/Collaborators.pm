# ABSTRACT: Forgejo Repo Collaborators API
# PODNAME: WWW::Forgejo::API::Repo::Collaborators

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Collaborators;

use Moo;
use Log::Any qw($log);
use URI::Escape;
use WWW::Forgejo::Entity::Collaborator;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\$self->owner}/${\\$self->repo}/collaborators/" . join('/', @path);
}

=method list

    my @collaborators = $self->list;

List all collaborators.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, %params);
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

    my $is_collab = $self->check('username');

Check if a user is a collaborator.

=cut

sub check {
    my ($self, $username) = @_;
    my $path = $self->_path_for(uri_escape($username));
    return $self->{client}->get($path);
}

=method get

    my $collaborator = $self->get('username');

Get a collaborator.

=cut

sub get {
    my ($self, $username) = @_;
    my $path = $self->_path_for(uri_escape($username));
    my $data = $self->{client}->get($path);
    return WWW::Forgejo::Entity::Collaborator->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method add

    $self->add('username', { permission => 'write' });

Add a collaborator.

=cut

sub add {
    my ($self, $username, $data) = @_;
    my $path = $self->_path_for(uri_escape($username));
    my $result = $self->{client}->put($path, $data // {});
    return WWW::Forgejo::Entity::Collaborator->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $result,
    );
}

=method remove

    $self->remove('username');

Remove a collaborator.

=cut

sub remove {
    my ($self, $username) = @_;
    my $path = $self->_path_for(uri_escape($username));
    return $self->{client}->delete($path);
}

=method permission

    my $perm = $self->permission('username');

Get collaborator permission level.

=cut

sub permission {
    my ($self, $username) = @_;
    my $path = $self->_path_for(uri_escape($username));
    return $self->{client}->get($path);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Collaborator>

=cut