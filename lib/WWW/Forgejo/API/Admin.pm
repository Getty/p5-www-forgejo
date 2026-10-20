# ABSTRACT: Forgejo Admin API
# PODNAME: WWW::Forgejo::API::Admin

use strict;
use warnings;

package WWW::Forgejo::API::Admin;

use Moo;
use Carp qw(croak);
use WWW::Forgejo::URL qw( escape_component );
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

=method orgs

    my $orgs = $forgejo->admin->orgs;

List all organizations of the instance (C<GET /admin/orgs>). Named arguments
are sent as the query string of the request.

=cut

sub orgs {
    my ($self, %params) = @_;
    return $self->client->get('/admin/orgs', params => \%params);
}

=method emails

    my $emails = $forgejo->admin->emails;

List the email addresses of all users of the instance (C<GET /admin/emails>).
Named arguments are sent as the query string of the request.

=cut

sub emails {
    my ($self, %params) = @_;
    return $self->client->get('/admin/emails', params => \%params);
}

=method unadopted

    my $repos = $forgejo->admin->unadopted;

List the repositories that are not adopted by any user
(C<GET /admin/unadopted>). Named arguments are sent as the query string of the
request (C<page>, C<limit>, C<pattern>).

=cut

sub unadopted {
    my ($self, %params) = @_;
    return $self->client->get('/admin/unadopted', params => \%params);
}

=method adopt

    $forgejo->admin->adopt('owner', 'repo-name');

Adopt a repository that is not adopted by any user
(C<POST /admin/unadopted/{owner}/{repo}>). The repository is adopted by the
user the token belongs to.

=cut

sub adopt {
    my ($self, $owner, $repo) = @_;
    croak "Repository owner required" unless defined $owner && length $owner;
    croak "Repository name required"  unless defined $repo  && length $repo;
    my $path = join '/', '/admin/unadopted', escape_component($owner), escape_component($repo);
    $self->client->post($path);
    return 1;
}

=method delete_unadopted

    $forgejo->admin->delete_unadopted('owner', 'repo-name');

Delete a repository that is not adopted by any user
(C<DELETE /admin/unadopted/{owner}/{repo}>).

=cut

sub delete_unadopted {
    my ($self, $owner, $repo) = @_;
    croak "Repository owner required" unless defined $owner && length $owner;
    croak "Repository name required"  unless defined $repo  && length $repo;
    my $path = join '/', '/admin/unadopted', escape_component($owner), escape_component($repo);
    $self->client->delete($path);
    return 1;
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $users = $forgejo->admin->users->list;
    my $tasks = $forgejo->admin->cron->list;

=head1 DESCRIPTION

Entry point to the site administration endpoints (C</admin/...>). Available
as C<< $forgejo->admin >>. Most of its methods return the controller for one
area; the endpoints that belong to no area of its own - the organizations, the
email addresses and the unadopted repositories of the instance - are here.

=head1 SEE ALSO

L<WWW::Forgejo::API::Admin::Users>, L<WWW::Forgejo::API::Admin::Hooks>,
L<WWW::Forgejo::API::Admin::Cron>, L<WWW::Forgejo::API::Admin::Quota>,
L<WWW::Forgejo::API::Admin::Runners>, L<WWW::Forgejo>

=cut
