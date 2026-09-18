# ABSTRACT: Forgejo Repo Branch Protections API
# PODNAME: WWW::Forgejo::API::Repo::BranchProtections

use strict;
use warnings;

package WWW::Forgejo::API::Repo::BranchProtections;

use Moo;
use Log::Any qw($log);
use URI::Escape;
use WWW::Forgejo::Entity::BranchProtection;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\uri_escape($self->owner)}/${\uri_escape($self->repo)}/branch_protections/" . join('/', @path);
}

=method list

    my @protections = $self->list;

List all branch protections.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, %params);
    return map {
        WWW::Forgejo::Entity::BranchProtection->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

=method get

    my $protection = $self->get('branch-name');

Get a branch protection.

=cut

sub get {
    my ($self, $branch_name) = @_;
    my $path = $self->_path_for(uri_escape($branch_name));
    my $data = $self->{client}->get($path);
    return WWW::Forgejo::Entity::BranchProtection->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method create

    my $protection = $self->create({
        branch_name => 'main',
        rule        => 'protect-main',
    });

Create a branch protection.

=cut

sub create {
    my ($self, $data) = @_;
    my $path = $self->_path_for;
    my $result = $self->{client}->post($path, $data);
    return WWW::Forgejo::Entity::BranchProtection->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $result,
    );
}

=method update

    my $protection = $self->update('main', { ... });

Update a branch protection.

=cut

sub update {
    my ($self, $branch_name, $data) = @_;
    my $path = $self->_path_for(uri_escape($branch_name));
    my $result = $self->{client}->patch($path, $data);
    return WWW::Forgejo::Entity::BranchProtection->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $result,
    );
}

=method edit

    my $protection = $self->edit('main', { ... });

Update a branch protection (alias for update).

=cut

sub edit {
    my ($self, $branch_name, $data) = @_;
    return $self->update($branch_name, $data);
}

=method delete

    $self->delete('main');

Delete a branch protection.

=cut

sub delete {
    my ($self, $branch_name) = @_;
    my $path = $self->_path_for(uri_escape($branch_name));
    return $self->{client}->delete($path);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::Entity::BranchProtection>

=cut
