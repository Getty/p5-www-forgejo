# ABSTRACT: Forgejo Admin Hooks API
# PODNAME: WWW::Forgejo::API::Admin::Hooks

use strict;
use warnings;

package WWW::Forgejo::API::Admin::Hooks;

use Moo;
use URI::Escape qw(uri_escape);
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

=method list

    my $hooks = $forgejo->admin->hooks->list;

List all system-wide hooks. Named arguments are sent as the query string of
the request. Forgejo 15 lists only the system webhooks here; a hook made with
L</create> is not one of them and does not show up, though L</get>, L</edit>
and L</delete> reach it.

=cut

sub list {
    my ($self, %params) = @_;
    return $self->client->get('/admin/hooks', params => \%params);
}

=method get

    my $hook = $forgejo->admin->hooks->get($id);

Get a specific hook by ID.

=cut

sub get {
    my ($self, $id) = @_;
    return $self->client->get('/admin/hooks/' . uri_escape($id));
}

=method create

    my $hook = $forgejo->admin->hooks->create(
        type   => 'forgejo',
        config => { url => 'https://example.com/hook', content_type => 'json' },
    );

Create a new system hook; the API requires C<type> and C<config>. The
key/value pairs are sent as the JSON body.

=cut

sub create {
    my ($self, %params) = @_;
    return $self->client->post('/admin/hooks', \%params);
}

=method edit

    my $hook = $forgejo->admin->hooks->edit($id, active => \0);

Edit an existing hook (C<PATCH /admin/hooks/{id}>). The key/value pairs are
sent as the JSON body.

=cut

sub edit {
    my ($self, $id, %params) = @_;
    return $self->client->patch('/admin/hooks/' . uri_escape($id), \%params);
}

=method delete

    $forgejo->admin->hooks->delete($id);

Delete a hook.

=cut

sub delete {
    my ($self, $id) = @_;
    return $self->client->delete('/admin/hooks/' . uri_escape($id));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $hooks = $forgejo->admin->hooks->list;
    my $hook  = $forgejo->admin->hooks->get($id);

=head1 DESCRIPTION

The C</admin/hooks> site administration endpoints for system-wide webhooks.
It is obtained through L<WWW::Forgejo::API::Admin/hooks>.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::API::Admin>, L<WWW::Forgejo>

=cut
