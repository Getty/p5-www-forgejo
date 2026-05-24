# ABSTRACT: Forgejo Repo Pull Requests API
# PODNAME: WWW::Forgejo::API::Repo::PullRequests

use strict;
use warnings;

package WWW::Forgejo::API::Repo::PullRequests;

use Moo;
use Log::Any qw($log);
use Carp qw(croak);
use WWW::Forgejo::Entity::PullRequestReview;
use WWW::Forgejo::Entity::IssueComment;
use WWW::Forgejo::Entity::PullRequest;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\$self->owner}/${\\$self->repo}/pulls/" . join('/', @path);
}

=method list

    my @pulls = $self->list;

List all pull requests.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, %params);
    return map { $self->_to_pr($_) } @$data;
}

=method get

    my $pr = $self->get(1);

Get a pull request by ID.

=cut

sub get {
    my ($self, $id) = @_;
    my $data = $self->{client}->get($self->_path_for($id));
    return $self->_to_pr($data);
}

sub _to_pr {
    my ($self, $data) = @_;
    WWW::Forgejo::Entity::PullRequest->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method create

    my $pr = $self->create({
        title     => 'Feature PR',
        body      => 'Description',
        head      => 'feature-branch',
        base      => 'main',
    });

Create a pull request.

=cut

sub create {
    my ($self, $data) = @_;
    my $result = $self->{client}->post($self->_path_for, $data);
    return $self->_to_pr($result);
}

=method edit

    my $pr = $self->edit(1, { title => 'Updated title' });

Edit a pull request.

=cut

sub edit {
    my ($self, $index, $data) = @_;
    my $result = $self->{client}->patch($self->_path_for($index), $data);
    return $self->_to_pr($result);
}

=method update

    my $pr = $self->update(1, { title => 'Updated title' });

Update a pull request (alias for edit).

=cut

*update = \&edit;

=method delete

    $self->delete(1);

Delete a pull request.

=cut

sub delete {
    my ($self, $index) = @_;
    $self->{client}->delete($self->_path_for($index));
    return 1;
}

=method merge

    my $result = $self->merge(1);

Merge a pull request.

=cut

sub merge {
    my ($self, $index, $data) = @_;
    $data //= {};
    my $result = $self->{client}->post($self->_path_for($index, 'merge'), $data);
    return $result;
}

=method is_merged

    my $merged = $self->is_merged(1);

Check if a pull request is merged.

=cut

sub is_merged {
    my ($self, $index) = @_;
    my $result = $self->{client}->get($self->_path_for($index, 'merged'));
    return $result;
}

=method reviews

    my @reviews = $self->reviews(1);

List reviews for a pull request.

=cut

sub reviews {
    my ($self, $index) = @_;
    my $data = $self->{client}->get($self->_path_for($index, 'reviews'));
    return map {
        WWW::Forgejo::Entity::PullRequestReview->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

sub create_review {
    my ($self, $index, $data) = @_;
    my $result = $self->{client}->post($self->_path_for($index, 'reviews'), $data);
    return $result;
}

sub comments {
    my ($self, $index) = @_;
    my $data = $self->{client}->get($self->_path_for($index, 'comments'));
    return map {
        WWW::Forgejo::Entity::IssueComment->new(
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
