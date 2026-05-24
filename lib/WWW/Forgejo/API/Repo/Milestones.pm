# ABSTRACT: Forgejo Repo Milestones API
# PODNAME: WWW::Forgejo::API::Repo::Milestones

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Milestones;

use Moo;
use Log::Any qw($log);
use Carp qw(croak);
use WWW::Forgejo::Entity::Milestone;
use WWW::Forgejo::Entity::Issue;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\$self->owner}/${\\$self->repo}/milestones/" . join('/', @path);
}

sub _to_milestone {
    my ($self, $data) = @_;
    WWW::Forgejo::Entity::Milestone->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method list

    my @milestones = $self->list;

List all milestones.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, %params);
    return map { $self->_to_milestone($_) } @$data;
}

=method get

    my $milestone = $self->get(1);

Get a milestone by ID.

=cut

sub get {
    my ($self, $id) = @_;
    my $data = $self->{client}->get($self->_path_for($id));
    return $self->_to_milestone($data);
}

=method create

    my $milestone = $self->create({
        title       => 'v1.0',
        description => 'Version 1 milestone',
        due_date    => '2025-12-31',
    });

Create a milestone.

=cut

sub create {
    my ($self, $data) = @_;
    my $result = $self->{client}->post($self->_path_for, $data);
    return $self->_to_milestone($result);
}

=method edit

    my $milestone = $self->edit(1, { title => 'Updated title' });

Edit a milestone.

=cut

sub edit {
    my ($self, $id, $data) = @_;
    my $result = $self->{client}->patch($self->_path_for($id), $data);
    return $self->_to_milestone($result);
}

=method update

    my $milestone = $self->update(1, { title => 'Updated title' });

Update a milestone (alias for edit).

=cut

*update = \&edit;

=method delete

    $self->delete(1);

Delete a milestone.

=cut

sub delete {
    my ($self, $id) = @_;
    $self->{client}->delete($self->_path_for($id));
    return 1;
}

=method issues

    my @issues = $self->issues(1);

List issues in a milestone.

=cut

sub issues {
    my ($self, $id) = @_;
    my $data = $self->{client}->get($self->_path_for($id, 'issues'));
    return map {
        WWW::Forgejo::Entity::Issue->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

1;
__END__

=cut
