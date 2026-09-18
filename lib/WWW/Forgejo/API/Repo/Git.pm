# ABSTRACT: Forgejo Repo Git API
# PODNAME: WWW::Forgejo::API::Repo::Git

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Git;

use Moo;
use Log::Any qw($log);
use URI::Escape;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\uri_escape($self->owner)}/${\uri_escape($self->repo)}/git/" . join('/', @path);
}

=method refs

    my @refs = $self->refs;

List all references.

=cut

sub list_refs {
    my ($self) = @_;
    my $data = $self->{client}->get($self->_path_for('refs'));
    return $data;
}

=method get_ref

    my $ref = $self->get_ref('heads/main');

Get a reference.

=cut

sub get_ref {
    my ($self, $ref) = @_;
    my $data = $self->{client}->get($self->_path_for("refs/$ref"));
    return $data;
}

=method create_ref

    $self->create_ref({
        ref  => 'refs/heads/new-branch',
        sha  => 'abc123',
    });

Create a reference.

=cut

sub create_ref {
    my ($self, $data) = @_;
    my $ref = $self->{client}->post($self->_path_for('refs'), $data);
    return $ref;
}

=method delete_ref

    $self->delete_ref('refs/heads/old-branch');

Delete a reference.

=cut

sub delete_ref {
    my ($self, $ref) = @_;
    $self->{client}->delete($self->_path_for("refs/$ref"));
    return;
}

=method get_commit

    my $commit = $self->get_commit('abc123');

Get a commit.

=cut

sub get_commit {
    my ($self, $sha) = @_;
    my $data = $self->{client}->get($self->_path_for("commits/" . uri_escape($sha)));
    return $data;
}

=method get_tree

    my $tree = $self->get_tree('abc123');

Get a tree.

=cut

sub get_tree {
    my ($self, $sha) = @_;
    my $data = $self->{client}->get($self->_path_for("trees/" . uri_escape($sha)));
    return $data;
}

=method get_blob

    my $blob = $self->get_blob('abc123');

Get a blob.

=cut

sub get_blob {
    my ($self, $sha) = @_;
    my $data = $self->{client}->get($self->_path_for("blobs/" . uri_escape($sha)));
    return $data;
}

1;
__END__

=cut
