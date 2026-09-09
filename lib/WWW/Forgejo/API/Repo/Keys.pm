# ABSTRACT: Forgejo Repo Keys API
# PODNAME: WWW::Forgejo::API::Repo::Keys

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Keys;

use Moo;
use Log::Any qw($log);
use URI::Escape;
use WWW::Forgejo::Entity::DeployKey;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\uri_escape($self->owner)}/${\uri_escape($self->repo)}/keys/" . join('/', @path);
}

=method list

    my @keys = $self->list;

List deploy keys.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, %params);
    return map {
        WWW::Forgejo::Entity::DeployKey->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

=method get

    my $key = $self->get(1);

Get a deploy key by ID.

=cut

sub get {
    my ($self, $id) = @_;
    my $data = $self->{client}->get($self->_path_for(uri_escape($id)));
    return WWW::Forgejo::Entity::DeployKey->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method create

    my $key = $self->create({
        title      => 'Deploy Key',
        key        => 'ssh-rsa AAAAB...',
        read_only  => 0,
    });

Create a deploy key.

=cut

sub create {
    my ($self, $data) = @_;
    my $path = $self->_path_for;
    my $result = $self->{client}->post($path, $data);
    return WWW::Forgejo::Entity::DeployKey->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $result,
    );
}

=method delete

    $self->delete(1);

Delete a deploy key.

=cut

sub delete {
    my ($self, $id) = @_;
    my $path = $self->_path_for(uri_escape($id));
    return $self->{client}->delete($path);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::Entity::DeployKey>

=cut
