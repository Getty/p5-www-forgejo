# ABSTRACT: Forgejo Repo Stargazers API
# PODNAME: WWW::Forgejo::API::Repo::Stargazers

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Stargazers;

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
    return $self->_repo_path('stargazers', @path);
}

=method list

    my @stargazers = $repo->stargazers->list;
    my @stargazers = $repo->stargazers->list(page => 2, limit => 50);

List the users who starred the repository, as plain user structures. Named
arguments are sent as the query string.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return @$data;
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @stargazers = $repo->stargazers->list;

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/stargazers> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/stargazers>, which binds it to
that repository; every method then addresses that repository.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo>

=cut
