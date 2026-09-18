# ABSTRACT: Forgejo Repo Issues API
# PODNAME: WWW::Forgejo::API::Repo::Issues

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Issues;

use Moo;
use Log::Any qw($log);
use URI::Escape;
use Carp qw(croak);
use WWW::Forgejo::Entity::Issue;
use WWW::Forgejo::Entity::IssueComment;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\uri_escape($self->owner)}/${\uri_escape($self->repo)}/issues/" . join('/', @path);
}

=method list

    my @issues = $self->list;

List all issues.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, params => \%params);
    return map {
        WWW::Forgejo::Entity::Issue->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

=method get

    my $issue = $self->get(1);

Get an issue by ID.

=cut

sub get {
    my ($self, $id) = @_;
    my $data = $self->{client}->get($self->_path_for(uri_escape($id)));
    return WWW::Forgejo::Entity::Issue->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method create

    my $issue = $self->create({
        title  => 'Bug report',
        body   => 'Description',
        labels => ['bug'],
    });

Create an issue.

=cut

sub create {
    my ($self, $data) = @_;
    my $result = $self->{client}->post($self->_path_for, $data);
    return WWW::Forgejo::Entity::Issue->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $result,
    );
}

=method edit

    my $issue = $self->edit(1, { title => 'Updated title' });

Edit an issue.

=cut

sub edit {
    my ($self, $index, $data) = @_;
    my $result = $self->{client}->patch($self->_path_for(uri_escape($index)), $data);
    return WWW::Forgejo::Entity::Issue->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $result,
    );
}

=method update

    my $issue = $self->update(1, { title => 'Updated title' });

Update an issue (alias for edit).

=cut

*update = \&edit;

=method delete

    $self->delete(1);

Delete an issue.

=cut

sub delete {
    my ($self, $index) = @_;
    $self->{client}->delete($self->_path_for(uri_escape($index)));
    return 1;
}

=method list_comments

    my @comments = $self->list_comments(1);

List comments on an issue.

=cut

sub list_comments {
    my ($self, $index) = @_;
    my $data = $self->{client}->get($self->_path_for(uri_escape($index), 'comments'));
    return map {
        WWW::Forgejo::Entity::IssueComment->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

=method comments

    my @comments = $self->comments(1);

List comments on an issue (alias for list_comments).

=cut

*comments = \&list_comments;

=method add_comment

    my $comment = $self->add_comment(1, { body => 'Reply text' });

Add a comment to an issue.

=cut

sub add_comment {
    my ($self, $index, $data) = @_;
    my $result = $self->{client}->post($self->_path_for(uri_escape($index), 'comments'), $data);
    return $result;
}

=method list_labels

    my @labels = $self->list_labels(1);

List labels on an issue.

=cut

sub list_labels {
    my ($self, $index) = @_;
    my $data = $self->{client}->get($self->_path_for(uri_escape($index), 'labels'));
    return @$data;
}

=method labels

    my @labels = $self->labels(1);

List labels on an issue (alias for list_labels).

=cut

*labels = \&list_labels;

=method add_label

    my $label = $self->add_label(1, { name => 'bug' });

Add a label to an issue.

=cut

sub add_label {
    my ($self, $index, $data) = @_;
    my $result = $self->{client}->post($self->_path_for(uri_escape($index), 'labels'), $data);
    return $result;
}

sub remove_label {
    my ($self, $index, $label) = @_;
    $self->{client}->delete($self->_path_for(uri_escape($index), 'labels', uri_escape($label)));
    return 1;
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Issue>

=cut
