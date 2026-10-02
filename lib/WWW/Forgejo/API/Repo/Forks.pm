# ABSTRACT: Forgejo Repo Forks API
# PODNAME: WWW::Forgejo::API::Repo::Forks

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Forks;

use Moo;
use URI::Escape qw(uri_escape);
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);
has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=attr owner

Owner (user or organization name) of the repository this controller works on.
Required.

=attr repo

Name of the repository this controller works on. Required.

=cut

# /repos/{owner}/{repo}/... of the repository this controller is bound to.
sub _repo_path {
    my ($self, @path) = @_;
    return join '/', '/repos', uri_escape($self->owner), uri_escape($self->repo), @path;
}

sub _path_for {
    my ($self, @path) = @_;
    return $self->_repo_path('forks', @path);
}

=method list

    my @forks = $repo->forks->list;

List the forks of the repository, as plain repository structures. Named
arguments are sent as the query string.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return @$data;
}

=method create

    my $fork = $repo->forks->create({ organization => 'myorg', name => 'fork-name' });

Fork the repository, into C<organization> or else the account of the
authenticated user. Returns the plain repository structure of the fork.

=cut

sub create {
    my ($self, $data) = @_;
    return $self->client->post($self->_path_for, $data);
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @forks = $repo->forks->list;

    my $fork = $repo->forks->create({
        organization => 'myorg',
    });

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/forks> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/forks>, which binds it to
that repository; every method then addresses that repository.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo>

=cut
