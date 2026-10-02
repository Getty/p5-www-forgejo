# ABSTRACT: Forgejo Repo Pull Requests API
# PODNAME: WWW::Forgejo::API::Repo::PullRequests

use strict;
use warnings;

package WWW::Forgejo::API::Repo::PullRequests;

use Moo;
use URI::Escape qw(uri_escape);
use WWW::Forgejo::Entity::PullRequest;
use WWW::Forgejo::Entity::PullRequestReview;
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
    return $self->_repo_path('pulls', @path);
}

sub _to_pr {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::PullRequest->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method list

    my @pulls = $repo->pulls->list;
    my @open  = $repo->pulls->list(state => 'open');

List the pull requests as L<WWW::Forgejo::Entity::PullRequest> objects. Named
arguments are sent as the query string (C<state>, C<sort>, C<milestone>,
C<labels>, C<poster>, C<base>, C<head>, C<page>, C<limit>).

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return map { $self->_to_pr($_) } @$data;
}

=method get

    my $pr = $repo->pulls->get($index);

Get a pull request by its index.

=cut

sub get {
    my ($self, $index) = @_;
    return $self->_to_pr($self->client->get($self->_path_for(uri_escape($index))));
}

=method create

    my $pr = $repo->pulls->create({ title => 'Feature PR', head => 'feature', base => 'main' });

Create a pull request.

=cut

sub create {
    my ($self, $data) = @_;
    return $self->_to_pr($self->client->post($self->_path_for, $data));
}

=method edit

    my $pr = $repo->pulls->edit($index, { title => 'New title' });
    my $pr = $repo->pulls->edit($index, { state => 'closed' });

Edit a pull request. The API cannot delete a pull request; closing it with
C<< state => 'closed' >> is the way to retire one.

=cut

sub edit {
    my ($self, $index, $data) = @_;
    return $self->_to_pr($self->client->patch($self->_path_for(uri_escape($index)), $data));
}

=method update

Alias for L</edit>.

=cut

sub update { shift->edit(@_) }

=method merge

    $repo->pulls->merge($index, { Do => 'merge' });

Merge a pull request. The API requires C<Do>, the merge style: C<merge>,
C<rebase>, C<rebase-merge>, C<squash>, C<fast-forward-only> or
C<manually-merged>.

=cut

sub merge {
    my ($self, $index, $data) = @_;
    return $self->client->post($self->_path_for(uri_escape($index), 'merge'), $data);
}

=method is_merged

    my $bool = $repo->pulls->is_merged($index);

Check whether a pull request has been merged. Returns true or false; the API
answers this with its status code only.

=cut

sub is_merged {
    my ($self, $index) = @_;
    return $self->client->check($self->_path_for(uri_escape($index), 'merge'));
}

=method reviews

    my @reviews = $repo->pulls->reviews($index);

List the reviews of a pull request as L<WWW::Forgejo::Entity::PullRequestReview>
objects. Named arguments are sent as the query string.

=cut

sub reviews {
    my ($self, $index, %params) = @_;
    my $data = $self->client->get($self->_path_for(uri_escape($index), 'reviews'), params => \%params);
    return map {
        WWW::Forgejo::Entity::PullRequestReview->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

=method create_review

    my $review = $repo->pulls->create_review($index, { event => 'APPROVED', body => 'LGTM' });

Create a review on a pull request. Returns the plain review structure.

=cut

sub create_review {
    my ($self, $index, $data) = @_;
    return $self->client->post($self->_path_for(uri_escape($index), 'reviews'), $data);
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @pulls = $repo->pulls->list;
    my @open  = $repo->pulls->list(state => 'open');
    my @page2 = $repo->pulls->list(page => 2, limit => 50);

    my $pr = $repo->pulls->get(1);

    $pr = $repo->pulls->create({
        title => 'Feature PR',
        body  => 'Description',
        head  => 'feature-branch',
        base  => 'main',
    });

    $repo->pulls->merge(1, { Do => 'squash' }) unless $repo->pulls->is_merged(1);

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/pulls> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/pulls>, which binds it to
that repository; every method then addresses that repository.

Depending on the method, results are L<WWW::Forgejo::Entity::PullRequest> and L<WWW::Forgejo::Entity::PullRequestReview>
objects or the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::PullRequest>, L<WWW::Forgejo::Entity::PullRequestReview>, L<WWW::Forgejo>

=cut
