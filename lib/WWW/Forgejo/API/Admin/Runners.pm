# ABSTRACT: Forgejo Admin Runners API
# PODNAME: WWW::Forgejo::API::Admin::Runners

use strict;
use warnings;

package WWW::Forgejo::API::Admin::Runners;

use Moo;
use Carp qw(croak);
use WWW::Forgejo::URL qw( escape_component );
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

=method list

    my $runners = $forgejo->admin->runners->list;

List the instance-wide Actions runners. Named arguments are sent as the
query string of the request.

=cut

sub list {
    my ($self, %params) = @_;
    return $self->client->get('/admin/actions/runners', params => \%params);
}

=method get

    my $runner = $forgejo->admin->runners->get($runner_id);

Get a specific runner by ID.

=cut

sub get {
    my ($self, $runner_id) = @_;
    return $self->client->get('/admin/actions/runners/' . escape_component($runner_id));
}

=method delete

    $forgejo->admin->runners->delete($runner_id);

Delete a runner.

=cut

sub delete {
    my ($self, $runner_id) = @_;
    return $self->client->delete('/admin/actions/runners/' . escape_component($runner_id));
}

=method registration_token

    my $token = $forgejo->admin->runners->registration_token;

Get the token for registering an instance-wide runner.

=cut

sub registration_token {
    my ($self) = @_;
    return $self->client->get('/admin/actions/runners/registration-token');
}

=method create

    my $runner = $forgejo->admin->runners->create(
        name => 'my-runner',
    );

Register a new global runner (C<POST /admin/actions/runners>). The key/value
pairs are sent as the JSON body; the API takes the C<name> of the runner, its
C<description> and whether it is C<ephemeral>.

=cut

sub create {
    my ($self, %params) = @_;
    croak "Runner name required" unless $params{name};
    return $self->client->post('/admin/actions/runners', \%params);
}

=method jobs

    my $jobs = $forgejo->admin->runners->jobs;

List the jobs of the runners of the instance
(C<GET /admin/actions/runners/jobs>). Named arguments are sent as the query
string of the request (C<labels>).

=cut

sub jobs {
    my ($self, %params) = @_;
    return $self->client->get('/admin/actions/runners/jobs', params => \%params);
}

=method global_jobs

    my $jobs = $forgejo->admin->runners->global_jobs;

List the jobs of the global runners of the instance
(C<GET /admin/runners/jobs>). Named arguments are sent as the query string of
the request (C<labels>).

Forgejo 15 has deprecated this call in favour of L</jobs>.

=cut

sub global_jobs {
    my ($self, %params) = @_;
    return $self->client->get('/admin/runners/jobs', params => \%params);
}

=method global_registration_token

    my $token = $forgejo->admin->runners->global_registration_token;

Get the token for registering a global runner
(C<GET /admin/runners/registration-token>).

Forgejo 15 has deprecated this call in favour of L</registration_token>.

=cut

sub global_registration_token {
    my ($self) = @_;
    return $self->client->get('/admin/runners/registration-token');
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $runners = $forgejo->admin->runners->list;
    my $token   = $forgejo->admin->runners->registration_token;

=head1 DESCRIPTION

The C</admin/actions/runners> site administration endpoints for instance-wide
Actions runners. It is obtained through L<WWW::Forgejo::API::Admin/runners>.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::API::Admin>, L<WWW::Forgejo>

=cut
