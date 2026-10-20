# ABSTRACT: Forgejo Repo Issues API
# PODNAME: WWW::Forgejo::API::Repo::Issues

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Issues;

use Moo;
use WWW::Forgejo::URL qw( escape_component );
use WWW::Forgejo::Entity::Issue;
use WWW::Forgejo::Entity::IssueComment;
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
    return $self->_repo_path('issues', @path);
}

sub _issue {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::Issue->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

sub _comment {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::IssueComment->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method list

    my $issues = $repo->issues->list;
    my $open   = $repo->issues->list(state => 'open', labels => 'bug');

List the issues of the repository as L<WWW::Forgejo::Entity::Issue> objects, in
an arrayref. Named arguments are sent as the query string (C<state>, C<labels>,
C<q>, C<type>, C<milestones>, C<since>, C<before>, C<created_by>, C<assigned_by>,
C<mentioned_by>, C<sort>, C<page>, C<limit>).

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return [ map { $self->_issue($_) } @$data ];
}

=method get

    my $issue = $repo->issues->get($index);

Get an issue by its index.

=cut

sub get {
    my ($self, $index) = @_;
    return $self->_issue($self->client->get($self->_path_for(escape_component($index))));
}

=method create

    my $issue = $repo->issues->create(title => 'Bug report', body => 'Description');

Create an issue; the API requires C<title>. The named arguments are sent as the
JSON body.

=cut

sub create {
    my ($self, %params) = @_;
    return $self->_issue($self->client->post($self->_path_for, \%params));
}

=method edit

    my $issue = $repo->issues->edit($index, state => 'closed');

Edit an issue. The named arguments are sent as the JSON body.

=cut

sub edit {
    my ($self, $index, %params) = @_;
    return $self->_issue($self->client->patch($self->_path_for(escape_component($index)), \%params));
}

=method update

Alias for L</edit>.

=cut

sub update { shift->edit(@_) }

=method delete

    $repo->issues->delete($index);

Delete an issue. Returns true.

=cut

sub delete {
    my ($self, $index) = @_;
    $self->client->delete($self->_path_for(escape_component($index)));
    return 1;
}

=method list_comments

    my $comments = $repo->issues->list_comments($index);

List the comments of an issue as L<WWW::Forgejo::Entity::IssueComment> objects,
in an arrayref. Named arguments are sent as the query string (C<since>,
C<before>).

=cut

sub list_comments {
    my ($self, $index, %params) = @_;
    my $data = $self->client->get($self->_path_for(escape_component($index), 'comments'), params => \%params);
    return [ map { $self->_comment($_) } @$data ];
}

=method comments

Alias for L</list_comments>.

=cut

sub comments { shift->list_comments(@_) }

=method add_comment

    my $comment = $repo->issues->add_comment($index, body => 'Looks good');

Add a comment to an issue; the API requires C<body>. The named arguments are
sent as the JSON body. Returns the plain comment structure.

=cut

sub add_comment {
    my ($self, $index, %params) = @_;
    return $self->client->post($self->_path_for(escape_component($index), 'comments'), \%params);
}

=method list_labels

    my $labels = $repo->issues->list_labels($index);

List the labels of an issue, as plain label structures in an arrayref.

=cut

sub list_labels {
    my ($self, $index) = @_;
    my $data = $self->client->get($self->_path_for(escape_component($index), 'labels'));
    return [@$data];
}

=method labels

Alias for L</list_labels>.

=cut

sub labels { shift->list_labels(@_) }

=method add_label

    my $labels = $repo->issues->add_label($index, labels => [ $label_id ]);

Add labels to an issue. The named arguments are sent as the JSON body. Returns
the labels the issue then has.

=cut

sub add_label {
    my ($self, $index, %params) = @_;
    return $self->client->post($self->_path_for(escape_component($index), 'labels'), \%params);
}

=method remove_label

    $repo->issues->remove_label($index, $label_id);

Remove one label, given by its ID or name, from an issue. Returns true.

=cut

sub remove_label {
    my ($self, $index, $label) = @_;
    $self->client->delete($self->_path_for(escape_component($index), 'labels', escape_component($label)));
    return 1;
}

=method list_pinned

    my $pinned = $repo->issues->list_pinned;

List the pinned issues of the repository as L<WWW::Forgejo::Entity::Issue>
objects, in an arrayref. Named arguments are sent as the query string.

=cut

sub list_pinned {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for('pinned'), params => \%params);
    return [ map { $self->_issue($_) } @$data ];
}

=method list_repo_comments

    my $comments = $repo->issues->list_repo_comments;

List the comments of all issues of the repository as
L<WWW::Forgejo::Entity::IssueComment> objects, in an arrayref. Named arguments
are sent as the query string (C<since>, C<before>).

=cut

sub list_repo_comments {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for('comments'), params => \%params);
    return [ map { $self->_comment($_) } @$data ];
}

=method get_repo_comment

    my $comment = $repo->issues->get_repo_comment($id);

Get a comment of the repository by its ID, no matter which issue it belongs to.

=cut

sub get_repo_comment {
    my ($self, $id) = @_;
    return $self->_comment($self->client->get($self->_path_for('comments', escape_component($id))));
}

=method edit_repo_comment

    $repo->issues->edit_repo_comment($id, body => 'Corrected');

Edit a comment of the repository. The named arguments are sent as the JSON body.

=cut

sub edit_repo_comment {
    my ($self, $id, %params) = @_;
    return $self->_comment(
        $self->client->patch($self->_path_for('comments', escape_component($id)), \%params));
}

=method delete_repo_comment

    $repo->issues->delete_repo_comment($id);

Delete a comment of the repository. Returns true.

=cut

sub delete_repo_comment {
    my ($self, $id) = @_;
    $self->client->delete($self->_path_for('comments', escape_component($id)));
    return 1;
}

=method edit_comment

    $repo->issues->edit_comment($index, $id, body => 'Corrected');

Edit a comment of an issue. The named arguments are sent as the JSON body.

=cut

sub edit_comment {
    my ($self, $index, $id, %params) = @_;
    return $self->_comment(
        $self->client->patch($self->_path_for(escape_component($index), 'comments', escape_component($id)), \%params));
}

=method delete_comment

    $repo->issues->delete_comment($index, $id);

Delete a comment of an issue. Returns true.

=cut

sub delete_comment {
    my ($self, $index, $id) = @_;
    $self->client->delete($self->_path_for(escape_component($index), 'comments', escape_component($id)));
    return 1;
}

=method list_comment_assets

    my $assets = $repo->issues->list_comment_assets($id);

List the assets (attachments) of a comment, as plain structures in an arrayref.

=cut

sub list_comment_assets {
    my ($self, $id) = @_;
    my $data = $self->client->get($self->_path_for('comments', escape_component($id), 'assets'));
    return [@$data];
}

=method get_comment_asset

    my $asset = $repo->issues->get_comment_asset($id, $asset_id);

Get one asset of a comment.

=cut

sub get_comment_asset {
    my ($self, $id, $asset_id) = @_;
    return $self->client->get(
        $self->_path_for('comments', escape_component($id), 'assets', escape_component($asset_id)));
}

=method create_comment_asset

    my $asset = $repo->issues->create_comment_asset($id,
        name     => 'screenshot.png',
        file     => 'screenshot.png',
    );

Add an asset to a comment, as a C<multipart/form-data> request. The file is
taken from disk (C<file>) or from memory (C<content>, which needs a
C<filename>); C<name> is the name the asset gets on the server, sent as
query parameter.

=cut

sub create_comment_asset {
    my ($self, $id, %upload) = @_;
    my $name       = delete $upload{name};
    my $updated_at = delete $upload{updated_at};
    return $self->client->post(
        $self->_path_for('comments', escape_component($id), 'assets'), undef,
        params => { name => $name, updated_at => $updated_at },
        upload => \%upload,
    );
}

=method edit_comment_asset

    $repo->issues->edit_comment_asset($id, $asset_id, name => 'new-name.png');

Edit an asset of a comment. The named arguments are sent as the JSON body.

=cut

sub edit_comment_asset {
    my ($self, $id, $asset_id, %params) = @_;
    return $self->client->patch(
        $self->_path_for('comments', escape_component($id), 'assets', escape_component($asset_id)), \%params);
}

=method delete_comment_asset

    $repo->issues->delete_comment_asset($id, $asset_id);

Delete an asset of a comment. Returns true.

=cut

sub delete_comment_asset {
    my ($self, $id, $asset_id) = @_;
    $self->client->delete(
        $self->_path_for('comments', escape_component($id), 'assets', escape_component($asset_id)));
    return 1;
}

=method list_comment_reactions

    my $reactions = $repo->issues->list_comment_reactions($id);

List the reactions of a comment, as plain structures in an arrayref.

=cut

sub list_comment_reactions {
    my ($self, $id) = @_;
    my $data = $self->client->get($self->_path_for('comments', escape_component($id), 'reactions'));
    return [@$data];
}

=method create_comment_reaction

    my $reaction = $repo->issues->create_comment_reaction($id, content => 'eyes');

Add a reaction to a comment. The named arguments are sent as the JSON body.

=cut

sub create_comment_reaction {
    my ($self, $id, %params) = @_;
    return $self->client->post($self->_path_for('comments', escape_component($id), 'reactions'), \%params);
}

=method delete_comment_reaction

    $repo->issues->delete_comment_reaction($id);

Remove the reaction of the current user from a comment. Returns true.

=cut

sub delete_comment_reaction {
    my ($self, $id) = @_;
    $self->client->delete($self->_path_for('comments', escape_component($id), 'reactions'));
    return 1;
}

=method list_assets

    my $assets = $repo->issues->list_assets($index);

List the assets (attachments) of an issue, as plain structures in an arrayref.

=cut

sub list_assets {
    my ($self, $index) = @_;
    my $data = $self->client->get($self->_path_for(escape_component($index), 'assets'));
    return [@$data];
}

=method get_asset

    my $asset = $repo->issues->get_asset($index, $asset_id);

Get one asset of an issue.

=cut

sub get_asset {
    my ($self, $index, $asset_id) = @_;
    return $self->client->get(
        $self->_path_for(escape_component($index), 'assets', escape_component($asset_id)));
}

=method create_asset

    my $asset = $repo->issues->create_asset($index,
        name     => 'screenshot.png',
        file     => 'screenshot.png',
    );

Add an asset to an issue, as a C<multipart/form-data> request. The file is
taken from disk (C<file>) or from memory (C<content>, which needs a
C<filename>); C<name> is the name the asset gets on the server, sent as
query parameter.

=cut

sub create_asset {
    my ($self, $index, %upload) = @_;
    my $name       = delete $upload{name};
    my $updated_at = delete $upload{updated_at};
    return $self->client->post(
        $self->_path_for(escape_component($index), 'assets'), undef,
        params => { name => $name, updated_at => $updated_at },
        upload => \%upload,
    );
}

=method edit_asset

    $repo->issues->edit_asset($index, $asset_id, name => 'new-name.png');

Edit an asset of an issue. The named arguments are sent as the JSON body.

=cut

sub edit_asset {
    my ($self, $index, $asset_id, %params) = @_;
    return $self->client->patch(
        $self->_path_for(escape_component($index), 'assets', escape_component($asset_id)), \%params);
}

=method delete_asset

    $repo->issues->delete_asset($index, $asset_id);

Delete an asset of an issue. Returns true.

=cut

sub delete_asset {
    my ($self, $index, $asset_id) = @_;
    $self->client->delete(
        $self->_path_for(escape_component($index), 'assets', escape_component($asset_id)));
    return 1;
}

=method list_reactions

    my $reactions = $repo->issues->list_reactions($index);

List the reactions of an issue, as plain structures in an arrayref.

=cut

sub list_reactions {
    my ($self, $index) = @_;
    my $data = $self->client->get($self->_path_for(escape_component($index), 'reactions'));
    return [@$data];
}

=method create_reaction

    my $reaction = $repo->issues->create_reaction($index, content => 'eyes');

Add a reaction to an issue. The named arguments are sent as the JSON body.

=cut

sub create_reaction {
    my ($self, $index, %params) = @_;
    return $self->client->post($self->_path_for(escape_component($index), 'reactions'), \%params);
}

=method delete_reaction

    $repo->issues->delete_reaction($index);

Remove the reaction of the current user from an issue. Returns true.

=cut

sub delete_reaction {
    my ($self, $index) = @_;
    $self->client->delete($self->_path_for(escape_component($index), 'reactions'));
    return 1;
}

=method list_blocks

    my $blocks = $repo->issues->list_blocks($index);

List the issues that block the issue, as plain structures in an arrayref.

=cut

sub list_blocks {
    my ($self, $index) = @_;
    my $data = $self->client->get($self->_path_for(escape_component($index), 'blocks'));
    return [@$data];
}

=method create_block

    my $block = $repo->issues->create_block($index, issue_id => 42);

Make an issue block the issue. The named arguments are sent as the JSON body.

=cut

sub create_block {
    my ($self, $index, %params) = @_;
    return $self->client->post($self->_path_for(escape_component($index), 'blocks'), \%params);
}

=method delete_block

    $repo->issues->delete_block($index, owner => 'o', repo => 'r', index => $other);

Remove the block relation of the issue. The API takes the issue to unblock in
the body: its C<owner>, C<repo> and C<index> are sent as the JSON body.
Returns true.

=cut

sub delete_block {
    my ($self, $index, %params) = @_;
    $self->client->delete($self->_path_for(escape_component($index), 'blocks'), \%params);
    return 1;
}

=method list_dependencies

    my $dependencies = $repo->issues->list_dependencies($index);

List the dependencies of the issue, as plain structures in an arrayref.

=cut

sub list_dependencies {
    my ($self, $index) = @_;
    my $data = $self->client->get($self->_path_for(escape_component($index), 'dependencies'));
    return [@$data];
}

=method create_dependency

    my $dependency = $repo->issues->create_dependency($index, issue_id => 42);

Add a dependency to the issue. The named arguments are sent as the JSON body.

=cut

sub create_dependency {
    my ($self, $index, %params) = @_;
    return $self->client->post($self->_path_for(escape_component($index), 'dependencies'), \%params);
}

=method delete_dependency

    $repo->issues->delete_dependency($index, owner => 'o', repo => 'r', index => $other);

Remove the dependencies of the issue. The API takes the issue to remove the
dependency to in the body: its C<owner>, C<repo> and C<index> are sent as the
JSON body. Returns true.

=cut

sub delete_dependency {
    my ($self, $index, %params) = @_;
    $self->client->delete($self->_path_for(escape_component($index), 'dependencies'), \%params);
    return 1;
}

=method set_deadline

    my $issue = $repo->issues->set_deadline($index, deadline => '2026-12-31T23:59:00Z');

Set the deadline of an issue. The named arguments are sent as the JSON body.

=cut

sub set_deadline {
    my ($self, $index, %params) = @_;
    return $self->client->post($self->_path_for(escape_component($index), 'deadline'), \%params);
}

=method set_labels

    my $labels = $repo->issues->set_labels($index, labels => [ $label_id ]);

Replace the labels of an issue. The named arguments are sent as the JSON body.
Returns the labels the issue then has.

=cut

sub set_labels {
    my ($self, $index, %params) = @_;
    return $self->client->put($self->_path_for(escape_component($index), 'labels'), \%params);
}

=method remove_all_labels

    $repo->issues->remove_all_labels($index);

Remove all labels from an issue. Returns true.

=cut

sub remove_all_labels {
    my ($self, $index) = @_;
    $self->client->delete($self->_path_for(escape_component($index), 'labels'));
    return 1;
}

=method pin

    $repo->issues->pin($index);

Pin an issue. Returns true.

=cut

sub pin {
    my ($self, $index) = @_;
    $self->client->post($self->_path_for(escape_component($index), 'pin'));
    return 1;
}

=method unpin

    $repo->issues->unpin($index);

Unpin an issue. Returns true.

=cut

sub unpin {
    my ($self, $index) = @_;
    $self->client->delete($self->_path_for(escape_component($index), 'pin'));
    return 1;
}

=method update_pin

    $repo->issues->update_pin($index, 2);

Move a pinned issue to the given position. The API takes no body for this.
Returns true.

=cut

sub update_pin {
    my ($self, $index, $position) = @_;
    $self->client->patch(
        $self->_path_for(escape_component($index), 'pin', escape_component($position)));
    return 1;
}

=method start_stopwatch

    $repo->issues->start_stopwatch($index);

Start the stopwatch of an issue. Returns true.

=cut

sub start_stopwatch {
    my ($self, $index) = @_;
    $self->client->post($self->_path_for(escape_component($index), 'stopwatch', 'start'));
    return 1;
}

=method stop_stopwatch

    $repo->issues->stop_stopwatch($index);

Stop the stopwatch of an issue. Returns true.

=cut

sub stop_stopwatch {
    my ($self, $index) = @_;
    $self->client->post($self->_path_for(escape_component($index), 'stopwatch', 'stop'));
    return 1;
}

=method delete_stopwatch

    $repo->issues->delete_stopwatch($index);

Delete the stopwatch of an issue. Returns true.

=cut

sub delete_stopwatch {
    my ($self, $index) = @_;
    $self->client->delete($self->_path_for(escape_component($index), 'stopwatch', 'delete'));
    return 1;
}

=method list_subscribers

    my $subscribers = $repo->issues->list_subscribers($index);

List the users that watch an issue, as plain structures in an arrayref.

=cut

sub list_subscribers {
    my ($self, $index) = @_;
    my $data = $self->client->get($self->_path_for(escape_component($index), 'subscriptions'));
    return [@$data];
}

=method check_subscription

    my $watching = $repo->issues->check_subscription($index);

Check whether the current user watches an issue. Returns true or false; the API
answers this with its status code only.

=cut

sub check_subscription {
    my ($self, $index) = @_;
    return $self->client->check($self->_path_for(escape_component($index), 'subscriptions', 'check'));
}

=method subscribe

    $repo->issues->subscribe($index, 'other');

Make a user watch an issue. Returns true.

=cut

sub subscribe {
    my ($self, $index, $user) = @_;
    $self->client->put(
        $self->_path_for(escape_component($index), 'subscriptions', escape_component($user)));
    return 1;
}

=method unsubscribe

    $repo->issues->unsubscribe($index, 'other');

Stop a user from watching an issue. Returns true.

=cut

sub unsubscribe {
    my ($self, $index, $user) = @_;
    $self->client->delete(
        $self->_path_for(escape_component($index), 'subscriptions', escape_component($user)));
    return 1;
}

=method timeline

    my $timeline = $repo->issues->timeline($index);

Get the timeline of an issue, as plain data. Named arguments are sent as the
query string (C<since>, C<until>).

=cut

sub timeline {
    my ($self, $index, %params) = @_;
    return $self->client->get($self->_path_for(escape_component($index), 'timeline'), params => \%params);
}

=method list_times

    my $times = $repo->issues->list_times($index);

List the tracked times of an issue, as plain structures in an arrayref.

=cut

sub list_times {
    my ($self, $index) = @_;
    my $data = $self->client->get($self->_path_for(escape_component($index), 'times'));
    return [@$data];
}

=method add_time

    my $time = $repo->issues->add_time($index, time => 3600);

Track time on an issue. The named arguments are sent as the JSON body.

=cut

sub add_time {
    my ($self, $index, %params) = @_;
    return $self->client->post($self->_path_for(escape_component($index), 'times'), \%params);
}

=method delete_times

    $repo->issues->delete_times($index);

Delete the tracked times of an issue. Returns true.

=cut

sub delete_times {
    my ($self, $index) = @_;
    $self->client->delete($self->_path_for(escape_component($index), 'times'));
    return 1;
}

=method delete_time

    $repo->issues->delete_time($index, $time_id);

Delete one tracked time of an issue. Returns true.

=cut

sub delete_time {
    my ($self, $index, $time_id) = @_;
    $self->client->delete(
        $self->_path_for(escape_component($index), 'times', escape_component($time_id)));
    return 1;
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my $issues = $repo->issues->list;
    my $open   = $repo->issues->list(state => 'open');
    my $page2  = $repo->issues->list(page => 2, limit => 50);

    my $issue = $repo->issues->get(1);

    $issue = $repo->issues->create(
        title  => 'Bug report',
        body   => 'Description',
        labels => [ $label_id ],
    );

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/issues> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/issues>, which binds it to
that repository; every method then addresses that repository.

Depending on the method, results are L<WWW::Forgejo::Entity::Issue> and L<WWW::Forgejo::Entity::IssueComment>
objects or the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::Issue>, L<WWW::Forgejo::Entity::IssueComment>, L<WWW::Forgejo>

=cut
