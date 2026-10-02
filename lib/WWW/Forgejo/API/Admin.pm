# ABSTRACT: Forgejo Admin API
# PODNAME: WWW::Forgejo::API::Admin

use strict;
use warnings;

package WWW::Forgejo::API::Admin;

use Moo;
use WWW::Forgejo::API::Admin::Users;
use WWW::Forgejo::API::Admin::Hooks;
use WWW::Forgejo::API::Admin::Cron;
use WWW::Forgejo::API::Admin::Quota;
use WWW::Forgejo::API::Admin::Runners;
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

=method users

    my $users = $forgejo->admin->users;

Returns a L<WWW::Forgejo::API::Admin::Users> controller (C</admin/users>).

=cut

sub users { WWW::Forgejo::API::Admin::Users->new(client => $_[0]->client) }

=method hooks

    my $hooks = $forgejo->admin->hooks;

Returns a L<WWW::Forgejo::API::Admin::Hooks> controller (C</admin/hooks>).

=cut

sub hooks { WWW::Forgejo::API::Admin::Hooks->new(client => $_[0]->client) }

=method cron

    my $cron = $forgejo->admin->cron;

Returns a L<WWW::Forgejo::API::Admin::Cron> controller (C</admin/cron>).

=cut

sub cron { WWW::Forgejo::API::Admin::Cron->new(client => $_[0]->client) }

=method quota

    my $quota = $forgejo->admin->quota;

Returns a L<WWW::Forgejo::API::Admin::Quota> controller (C</admin/quota/groups>).

=cut

sub quota { WWW::Forgejo::API::Admin::Quota->new(client => $_[0]->client) }

=method runners

    my $runners = $forgejo->admin->runners;

Returns a L<WWW::Forgejo::API::Admin::Runners> controller
(C</admin/actions/runners>).

=cut

sub runners { WWW::Forgejo::API::Admin::Runners->new(client => $_[0]->client) }

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $users = $forgejo->admin->users->list;
    my $tasks = $forgejo->admin->cron->list;

=head1 DESCRIPTION

Entry point to the site administration endpoints (C</admin/...>). Available
as C<< $forgejo->admin >>. It has no endpoints of its own; each method returns
the controller for one area.

=head1 SEE ALSO

L<WWW::Forgejo::API::Admin::Users>, L<WWW::Forgejo::API::Admin::Hooks>,
L<WWW::Forgejo::API::Admin::Cron>, L<WWW::Forgejo::API::Admin::Quota>,
L<WWW::Forgejo::API::Admin::Runners>, L<WWW::Forgejo>

=cut
