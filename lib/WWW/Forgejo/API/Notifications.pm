# ABSTRACT: Forgejo Notifications API
# PODNAME: WWW::Forgejo::API::Notifications

use strict;
use warnings;

package WWW::Forgejo::API::Notifications;

use Moo;
use Log::Any qw($log);
use URI::Escape;

has client => (
    is       => 'ro',
    init_arg => 'client',
);


=method list

    my $notifications = $self->list;

List all notifications for the current user.

=cut

sub list {
    my ($self, %params) = @_;
    return $self->client->get('/notifications', params => \%params);
}

=method count

    my $count = $self->count;

Get the count of unread notifications.

=cut

sub count {
    my ($self) = @_;
    return $self->client->get('/notifications/count');
}

=method check

    my $new = $self->check;

Check for new notifications.

=cut

sub check {
    my ($self) = @_;
    return $self->client->get('/notifications/new');
}

=method mark_read

    $self->mark_read;

Mark all notifications as read.

=cut

sub mark_read {
    my ($self, %params) = @_;
    return $self->client->post('/notifications/mark-all-read', \%params);
}

=method mark_read_thread

    $self->mark_read_thread($thread_id);

Mark a specific thread as read.

=cut

sub mark_read_thread {
    my ($self, $thread_id) = @_;
    return $self->client->post("/notifications/threads/" . uri_escape($thread_id) . "/mark-read");
}

=method list_for_repo

    my $notifications = $self->list_for_repo($owner, $repo);
    my $notifications = $self->list_for_repo($owner, $repo, status => 'unread');

List notifications for a specific repository.

=cut

sub list_for_repo {
    my ($self, $owner, $repo, %params) = @_;
    return $self->client->get("/repos/" . uri_escape($owner) . "/" . uri_escape($repo) . "/notifications", params => \%params);
}

=method mark_read_repo

    $self->mark_read_repo($owner, $repo);
    $self->mark_read_repo($owner, $repo, last_read_at => $timestamp);

Mark all notifications for a repository as read.

=cut

sub mark_read_repo {
    my ($self, $owner, $repo, %params) = @_;
    return $self->client->post("/repos/" . uri_escape($owner) . "/" . uri_escape($repo) . "/notifications/mark-all-read", \%params);
}

1;