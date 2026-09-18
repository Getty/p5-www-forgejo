# ABSTRACT: Forgejo Repo Branches API
# PODNAME: WWW::Forgejo::API::Repo::Branches

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Branches;

use Moo;
use Log::Any qw($log);
use URI::Escape;
use WWW::Forgejo::Entity::Branch;
use WWW::Forgejo::Entity::BranchProtection;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\uri_escape($self->owner)}/${\uri_escape($self->repo)}/branches/" . join('/', @path);
}

=method list

    my @branches = $self->list;

List all branches.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, %params);
    return map {
        WWW::Forgejo::Entity::Branch->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

=method get

    my $branch = $self->get('main');

Get a single branch.

=cut

sub get {
    my ($self, $branch) = @_;
    my $data = $self->{client}->get($self->_path_for(uri_escape($branch)));
    return WWW::Forgejo::Entity::Branch->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method create

    my $branch = $self->create({
        branch_name => 'new-branch',
        from        => 'main',
    });

Create a new branch.

=cut

sub create {
    my ($self, $data) = @_;
    my $path = $self->_path_for;
    my $result = $self->{client}->post($path, $data);
    return WWW::Forgejo::Entity::Branch->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $result,
    );
}

=method delete

    $self->delete('feature-branch');

Delete a branch.

=cut

sub delete {
    my ($self, $branch) = @_;
    my $path = $self->_path_for(uri_escape($branch));
    return $self->{client}->delete($path);
}

=method protect

    $self->protect('main');

Protect a branch.

=cut

sub protect {
    my ($self, $branch) = @_;
    my $path = $self->_path_for(uri_escape($branch), 'protection');
    my $result = $self->{client}->get($path);
    return WWW::Forgejo::Entity::BranchProtection->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $result,
    );
}

=method unprotect

    $self->unprotect('main');

Unprotect a branch.

=cut

sub unprotect {
    my ($self, $branch) = @_;
    my $path = $self->_path_for(uri_escape($branch), 'protection');
    return $self->{client}->delete($path);
}

=method list_protected

    my @protected = $self->list_protected;

List all protected branches.

=cut

sub list_protected {
    my ($self, %params) = @_;
    my $path = $self->_path_for('protected');
    my $data = $self->{client}->get($path, %params);
    return map {
        WWW::Forgejo::Entity::Branch->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Branch>

=cut