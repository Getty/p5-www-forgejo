# ABSTRACT: Forgejo Repo Reviewers API
# PODNAME: WWW::Forgejo::API::Repo::Reviewers

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Reviewers;

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
    return $self->_repo_path('reviewers', @path);
}

=method list

    my @reviewers = $repo->reviewers->list;

List the users that can be asked to review a pull request of this repository,
as plain user structures.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return @$data;
}

# requested_reviewers body: usernames and team names, each a name or a list.
sub _request_body {
    my ($self, $reviewers, $team_reviewers) = @_;
    my %body;
    $body{reviewers}      = ref $reviewers      ? $reviewers      : [$reviewers]      if defined $reviewers;
    $body{team_reviewers} = ref $team_reviewers ? $team_reviewers : [$team_reviewers] if defined $team_reviewers;
    return \%body;
}

=method add

    my $reviews = $repo->reviewers->add($index, ['user1', 'user2']);
    my $reviews = $repo->reviewers->add($index, 'user1', ['team1']);

Request reviews for a pull request from users and, as optional third argument,
from teams. Each is a single name or an arrayref of names. Returns the
resulting review structures.

=cut

sub add {
    my ($self, $index, $reviewers, $team_reviewers) = @_;
    return $self->client->post(
        $self->_repo_path('pulls', uri_escape($index), 'requested_reviewers'),
        $self->_request_body($reviewers, $team_reviewers),
    );
}

=method remove

    $repo->reviewers->remove($index, 'user1');
    $repo->reviewers->remove($index, ['user1', 'user2'], ['team1']);

Cancel review requests for a pull request. Takes the same arguments as
L</add>; they are sent as the JSON body of the request.

=cut

sub remove {
    my ($self, $index, $reviewers, $team_reviewers) = @_;
    $self->client->delete(
        $self->_repo_path('pulls', uri_escape($index), 'requested_reviewers'),
        $self->_request_body($reviewers, $team_reviewers),
    );
    return;
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @reviewers = $repo->reviewers->list;

    $repo->reviewers->add(1, ['user1', 'user2']);

    $repo->reviewers->remove(1, 'user1');

=head1 DESCRIPTION

Controller for the reviewer endpoints of one repository: C</repos/{owner}/{repo}/reviewers> and C</repos/{owner}/{repo}/pulls/{index}/requested_reviewers>.
It is obtained through L<WWW::Forgejo::Entity::Repo/reviewers>, which binds it to
that repository; every method then addresses that repository.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo>

=cut
