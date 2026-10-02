# ABSTRACT: Forgejo Admin Cron API
# PODNAME: WWW::Forgejo::API::Admin::Cron

use strict;
use warnings;

package WWW::Forgejo::API::Admin::Cron;

use Moo;
use URI::Escape qw(uri_escape);
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

=method list

    my $tasks = $forgejo->admin->cron->list;

List all cron tasks. Named arguments are sent as the query string of the
request.

=cut

sub list {
    my ($self, %params) = @_;
    return $self->client->get('/admin/cron', params => \%params);
}

=method run

    $forgejo->admin->cron->run($task_name);

Run a cron task (C<POST /admin/cron/{task}>).

=cut

sub run {
    my ($self, $task) = @_;
    return $self->client->post('/admin/cron/' . uri_escape($task));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $tasks = $forgejo->admin->cron->list;

    $forgejo->admin->cron->run($tasks->[0]{name});

=head1 DESCRIPTION

The C</admin/cron> site administration endpoints: list the cron tasks of the
instance and trigger one. It is obtained through
L<WWW::Forgejo::API::Admin/cron>.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::API::Admin>, L<WWW::Forgejo>

=cut
