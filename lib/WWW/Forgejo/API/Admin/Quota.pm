# ABSTRACT: Forgejo Admin Quota API
# PODNAME: WWW::Forgejo::API::Admin::Quota

use strict;
use warnings;

package WWW::Forgejo::API::Admin::Quota;

use Moo;
use URI::Escape qw(uri_escape);
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

=method list_groups

    my $groups = $forgejo->admin->quota->list_groups;

List all quota groups.

=cut

sub list_groups {
    my ($self) = @_;
    return $self->client->get('/admin/quota/groups');
}

=method get_group

    my $group = $forgejo->admin->quota->get_group($name);

Get a specific quota group by name.

=cut

sub get_group {
    my ($self, $name) = @_;
    return $self->client->get('/admin/quota/groups/' . uri_escape($name));
}

=method create_group

    my $group = $forgejo->admin->quota->create_group(name => 'mygroup');

Create a quota group. The key/value pairs are sent as the JSON body.

=cut

sub create_group {
    my ($self, %params) = @_;
    return $self->client->post('/admin/quota/groups', \%params);
}

=method delete_group

    $forgejo->admin->quota->delete_group($name);

Delete a quota group.

=cut

sub delete_group {
    my ($self, $name) = @_;
    return $self->client->delete('/admin/quota/groups/' . uri_escape($name));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $groups = $forgejo->admin->quota->list_groups;
    my $group  = $forgejo->admin->quota->get_group($name);

=head1 DESCRIPTION

The C</admin/quota/groups> site administration endpoints. It is obtained
through L<WWW::Forgejo::API::Admin/quota>.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::API::Admin>, L<WWW::Forgejo>

=cut
