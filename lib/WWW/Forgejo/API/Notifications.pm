# ABSTRACT: Forgejo Notifications API
# PODNAME: WWW::Forgejo::API::Notifications

use strict;
use warnings;

package WWW::Forgejo::API::Notifications;

use Moo;
use URI::Escape qw(uri_escape);
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

sub _repo_path {
    my ($self, $owner, $repo) = @_;
    return join '/', '/repos', uri_escape($owner), uri_escape($repo), 'notifications';
}

=method list

    my $notifications = $forgejo->notifications->list;
    my $notifications = $forgejo->notifications->list(all => 'true');

List the notification threads of the current user (C<GET /notifications>).
Named arguments are sent as the query string of the request.

=cut

sub list {
    my ($self, %params) = @_;
    return $self->client->get('/notifications', params => \%params);
}

=method check

    my $new = $forgejo->notifications->check;

Check whether unread notifications exist (C<GET /notifications/new>). Returns
the decoded response, which carries the number of unread notifications.

=cut

sub check {
    my ($self) = @_;
    return $self->client->get('/notifications/new');
}

=method get_thread

    my $thread = $forgejo->notifications->get_thread($thread_id);

Get one notification thread (C<GET /notifications/threads/{id}>).

=cut

sub get_thread {
    my ($self, $thread_id) = @_;
    return $self->client->get("/notifications/threads/" . uri_escape($thread_id));
}

=method mark_read

    $forgejo->notifications->mark_read;
    $forgejo->notifications->mark_read(last_read_at => $timestamp);

Mark the notification threads as read (C<PUT /notifications>). Named arguments
are sent as the query string of the request.

=cut

sub mark_read {
    my ($self, %params) = @_;
    return $self->client->put('/notifications', undef, params => \%params);
}

=method mark_read_thread

    $forgejo->notifications->mark_read_thread($thread_id);

Mark a specific thread as read (C<PATCH /notifications/threads/{id}>). Further
named arguments are sent as the query string of the request.

=cut

sub mark_read_thread {
    my ($self, $thread_id, %params) = @_;
    return $self->client->patch("/notifications/threads/" . uri_escape($thread_id), undef, params => \%params);
}

=method list_for_repo

    my $notifications = $forgejo->notifications->list_for_repo($owner, $repo);
    my $notifications = $forgejo->notifications->list_for_repo($owner, $repo, all => 'true');

List the notification threads of the current user in one repository
(C<GET /repos/{owner}/{repo}/notifications>). Further named arguments are sent
as the query string of the request.

=cut

sub list_for_repo {
    my ($self, $owner, $repo, %params) = @_;
    return $self->client->get($self->_repo_path($owner, $repo), params => \%params);
}

=method mark_read_repo

    $forgejo->notifications->mark_read_repo($owner, $repo);
    $forgejo->notifications->mark_read_repo($owner, $repo, last_read_at => $timestamp);

Mark the notification threads of a repository as read
(C<PUT /repos/{owner}/{repo}/notifications>). Further named arguments are sent
as the query string of the request.

=cut

sub mark_read_repo {
    my ($self, $owner, $repo, %params) = @_;
    return $self->client->put($self->_repo_path($owner, $repo), undef, params => \%params);
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $notifications = $forgejo->notifications->list;
    my $new           = $forgejo->notifications->check;

    $forgejo->notifications->mark_read;

=head1 DESCRIPTION

The C</notifications> endpoints of the authenticated user, including the
per-repository notification endpoints. Available as
C<< $forgejo->notifications >>.

All methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo>

=cut
