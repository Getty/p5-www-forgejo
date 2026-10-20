# ABSTRACT: Forgejo Repo Pull Requests API
# PODNAME: WWW::Forgejo::API::Repo::PullRequests

use strict;
use warnings;

package WWW::Forgejo::API::Repo::PullRequests;

use Moo;
use WWW::Forgejo::URL qw( escape_component );
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
    return join '/', '/repos', escape_component($self->owner), escape_component($self->repo), @path;
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

sub _to_review {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::PullRequestReview->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method list

    my $pulls = $repo->pulls->list;
    my $open  = $repo->pulls->list(state => 'open');

List the pull requests as L<WWW::Forgejo::Entity::PullRequest> objects, in an
arrayref. Named arguments are sent as the query string (C<state>, C<sort>,
C<milestone>, C<labels>, C<poster>, C<base>, C<head>, C<page>, C<limit>).

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return [ map { $self->_to_pr($_) } @$data ];
}

=method get

    my $pr = $repo->pulls->get($index);

Get a pull request by its index.

=cut

sub get {
    my ($self, $index) = @_;
    return $self->_to_pr($self->client->get($self->_path_for(escape_component($index))));
}

=method create

    my $pr = $repo->pulls->create(title => 'Feature PR', head => 'feature', base => 'main');

Create a pull request. The named arguments are sent as the JSON body.

=cut

sub create {
    my ($self, %params) = @_;
    return $self->_to_pr($self->client->post($self->_path_for, \%params));
}

=method edit

    my $pr = $repo->pulls->edit($index, title => 'New title');
    my $pr = $repo->pulls->edit($index, state => 'closed');

Edit a pull request. The named arguments are sent as the JSON body. The API
cannot delete a pull request; closing it with C<< state => 'closed' >> is the
way to retire one.

=cut

sub edit {
    my ($self, $index, %params) = @_;
    return $self->_to_pr($self->client->patch($self->_path_for(escape_component($index)), \%params));
}

=method update

Alias for L</edit>.

=cut

sub update { shift->edit(@_) }

=method merge

    $repo->pulls->merge($index, Do => 'merge');

Merge a pull request. The API requires C<Do>, the merge style: C<merge>,
C<rebase>, C<rebase-merge>, C<squash>, C<fast-forward-only> or
C<manually-merged>. The named arguments are sent as the JSON body.

=cut

sub merge {
    my ($self, $index, %params) = @_;
    return $self->client->post($self->_path_for(escape_component($index), 'merge'), \%params);
}

=method is_merged

    my $bool = $repo->pulls->is_merged($index);

Check whether a pull request has been merged. Returns true or false; the API
answers this with its status code only.

=cut

sub is_merged {
    my ($self, $index) = @_;
    return $self->client->check($self->_path_for(escape_component($index), 'merge'));
}

=method reviews

    my $reviews = $repo->pulls->reviews($index);

List the reviews of a pull request as L<WWW::Forgejo::Entity::PullRequestReview>
objects, in an arrayref. Named arguments are sent as the query string.

=cut

sub reviews {
    my ($self, $index, %params) = @_;
    my $data = $self->client->get($self->_path_for(escape_component($index), 'reviews'), params => \%params);
    return [ map { $self->_to_review($_) } @$data ];
}

=method create_review

    my $review = $repo->pulls->create_review($index, event => 'APPROVED', body => 'LGTM');

Create a review on a pull request. The named arguments are sent as the JSON
body. Returns the plain review structure.

=cut

sub create_review {
    my ($self, $index, %params) = @_;
    return $self->client->post($self->_path_for(escape_component($index), 'reviews'), \%params);
}

=method list_pinned

    my $pinned = $repo->pulls->list_pinned;

List the pinned pull requests of the repository as
L<WWW::Forgejo::Entity::PullRequest> objects, in an arrayref. Named arguments
are sent as the query string.

=cut

sub list_pinned {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for('pinned'), params => \%params);
    return [ map { $self->_to_pr($_) } @$data ];
}

=method compare

    my $comparison = $repo->pulls->compare('main', 'feature');

Compare two branches of the repository (C<GET /repos/{owner}/{repo}/pulls/{base}/{head}>).
Returns the plain comparison structure with its commits and files; it is not a
pull request. Named arguments are sent as the query string.

=cut

sub compare {
    my ($self, $base, $head, %params) = @_;
    return $self->client->get(
        $self->_path_for(escape_component($base), escape_component($head)), params => \%params);
}

=method diff

    my $diff  = $repo->pulls->diff($index, 'diff');
    my $patch = $repo->pulls->diff($index, 'patch');
    my $bin   = $repo->pulls->diff($index, 'diff', binary => 'true');

Get the diff or the patch of a pull request
(C<GET /repos/{owner}/{repo}/pulls/{index}.{diffType}>). The type is C<diff> or
C<patch>. Named arguments are sent as the query string (C<binary>). Returns the
body of the response as it is, as bytes.

=cut

sub diff {
    my ($self, $index, $type, %params) = @_;
    return $self->client->get(
        $self->_path_for(escape_component($index) . '.' . escape_component($type)),
        params => \%params, raw => 1);
}

=method list_commits

    my $commits = $repo->pulls->list_commits($index);

List the commits of a pull request, as plain structures in an arrayref. Named
arguments are sent as the query string.

=cut

sub list_commits {
    my ($self, $index, %params) = @_;
    my $data = $self->client->get(
        $self->_path_for(escape_component($index), 'commits'), params => \%params);
    return [@$data];
}

=method list_files

    my $files = $repo->pulls->list_files($index);

List the files a pull request changes, as plain structures in an arrayref. Named
arguments are sent as the query string.

=cut

sub list_files {
    my ($self, $index, %params) = @_;
    my $data = $self->client->get(
        $self->_path_for(escape_component($index), 'files'), params => \%params);
    return [@$data];
}

=method unmerge

    $repo->pulls->unmerge($index);

Cancel the merge of a pull request that is in the state of being merged
(C<DELETE /repos/{owner}/{repo}/pulls/{index}/merge>). Returns true.

=cut

sub unmerge {
    my ($self, $index) = @_;
    $self->client->delete($self->_path_for(escape_component($index), 'merge'));
    return 1;
}

=method get_review

    my $review = $repo->pulls->get_review($index, $id);

Get one review of a pull request as a L<WWW::Forgejo::Entity::PullRequestReview>
object.

=cut

sub get_review {
    my ($self, $index, $id) = @_;
    return $self->_to_review(
        $self->client->get($self->_path_for(escape_component($index), 'reviews', escape_component($id))));
}

=method submit_review

    my $review = $repo->pulls->submit_review($index, $id, event => 'APPROVED');

Submit a pending review of a pull request
(C<POST /repos/{owner}/{repo}/pulls/{index}/reviews/{id}>). The named arguments
are sent as the JSON body. Returns the review as a
L<WWW::Forgejo::Entity::PullRequestReview> object.

=cut

sub submit_review {
    my ($self, $index, $id, %params) = @_;
    return $self->_to_review($self->client->post(
        $self->_path_for(escape_component($index), 'reviews', escape_component($id)), \%params));
}

=method delete_review

    $repo->pulls->delete_review($index, $id);

Delete a pending review of a pull request
(C<DELETE /repos/{owner}/{repo}/pulls/{index}/reviews/{id}>). Returns true.

=cut

sub delete_review {
    my ($self, $index, $id) = @_;
    $self->client->delete($self->_path_for(escape_component($index), 'reviews', escape_component($id)));
    return 1;
}

=method list_review_comments

    my $comments = $repo->pulls->list_review_comments($index, $id);

List the comments of a review of a pull request, as plain structures in an
arrayref. Named arguments are sent as the query string.

=cut

sub list_review_comments {
    my ($self, $index, $id, %params) = @_;
    my $data = $self->client->get(
        $self->_path_for(escape_component($index), 'reviews', escape_component($id), 'comments'),
        params => \%params);
    return [@$data];
}

=method create_review_comment

    my $comment = $repo->pulls->create_review_comment($index, $id,
        body      => 'Please fix this',
        path      => 'lib/Foo.pm',
        new_position => 12,
    );

Add a comment to a review of a pull request
(C<POST /repos/{owner}/{repo}/pulls/{index}/reviews/{id}/comments>). The named
arguments are sent as the JSON body. Returns the plain comment structure.

=cut

sub create_review_comment {
    my ($self, $index, $id, %params) = @_;
    return $self->client->post(
        $self->_path_for(escape_component($index), 'reviews', escape_component($id), 'comments'),
        \%params);
}

=method get_review_comment

    my $comment = $repo->pulls->get_review_comment($index, $id, $comment_id);

Get one comment of a review of a pull request
(C<GET /repos/{owner}/{repo}/pulls/{index}/reviews/{id}/comments/{comment}>).
Returns the plain comment structure.

=cut

sub get_review_comment {
    my ($self, $index, $id, $comment) = @_;
    return $self->client->get($self->_path_for(
        escape_component($index), 'reviews', escape_component($id), 'comments',
        escape_component($comment)));
}

=method delete_review_comment

    $repo->pulls->delete_review_comment($index, $id, $comment_id);

Delete a comment of a review of a pull request
(C<DELETE /repos/{owner}/{repo}/pulls/{index}/reviews/{id}/comments/{comment}>).
Returns true.

=cut

sub delete_review_comment {
    my ($self, $index, $id, $comment) = @_;
    $self->client->delete($self->_path_for(
        escape_component($index), 'reviews', escape_component($id), 'comments',
        escape_component($comment)));
    return 1;
}

=method dismiss_review

    my $review = $repo->pulls->dismiss_review($index, $id, message => 'Outdated');

Dismiss a review of a pull request
(C<POST /repos/{owner}/{repo}/pulls/{index}/reviews/{id}/dismissals>). The named
arguments are sent as the JSON body. Returns the review as a
L<WWW::Forgejo::Entity::PullRequestReview> object.

=cut

sub dismiss_review {
    my ($self, $index, $id, %params) = @_;
    return $self->_to_review($self->client->post(
        $self->_path_for(escape_component($index), 'reviews', escape_component($id), 'dismissals'),
        \%params));
}

=method undismiss_review

    my $review = $repo->pulls->undismiss_review($index, $id);

Take back the dismissal of a review of a pull request
(C<POST /repos/{owner}/{repo}/pulls/{index}/reviews/{id}/undismissals>). The API
takes no body for this. Returns the review as a
L<WWW::Forgejo::Entity::PullRequestReview> object.

=cut

sub undismiss_review {
    my ($self, $index, $id) = @_;
    return $self->_to_review($self->client->post(
        $self->_path_for(escape_component($index), 'reviews', escape_component($id), 'undismissals')));
}

=method update_branch

    my $pr = $repo->pulls->update_branch($index, style => 'rebase');

Update the branch of a pull request
(C<POST /repos/{owner}/{repo}/pulls/{index}/update>) - merge the base branch
into the branch of the pull request. The named arguments are sent as the JSON
body; the API takes the update style C<merge> or C<rebase> there. Returns the
pull request as a L<WWW::Forgejo::Entity::PullRequest> object.

=cut

sub update_branch {
    my ($self, $index, %params) = @_;
    return $self->_to_pr(
        $self->client->post($self->_path_for(escape_component($index), 'update'), \%params));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my $pulls = $repo->pulls->list;
    my $open  = $repo->pulls->list(state => 'open');
    my $page2 = $repo->pulls->list(page => 2, limit => 50);

    my $pr = $repo->pulls->get(1);

    $pr = $repo->pulls->create(
        title => 'Feature PR',
        body  => 'Description',
        head  => 'feature-branch',
        base  => 'main',
    );

    $repo->pulls->merge(1, Do => 'squash') unless $repo->pulls->is_merged(1);

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/pulls> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/pulls>, which binds it to
that repository; every method then addresses that repository.

Depending on the method, results are L<WWW::Forgejo::Entity::PullRequest> and L<WWW::Forgejo::Entity::PullRequestReview>
objects or the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::PullRequest>, L<WWW::Forgejo::Entity::PullRequestReview>, L<WWW::Forgejo>

=cut
