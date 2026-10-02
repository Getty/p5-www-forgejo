# ABSTRACT: Forgejo Repo Issues API
# PODNAME: WWW::Forgejo::API::Repo::Issues

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Issues;

use Moo;
use URI::Escape qw(uri_escape);
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
    return join '/', '/repos', uri_escape($self->owner), uri_escape($self->repo), @path;
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

=method list

    my @issues = $repo->issues->list;
    my @open   = $repo->issues->list(state => 'open', labels => 'bug');

List the issues of the repository as L<WWW::Forgejo::Entity::Issue> objects.
Named arguments are sent as the query string (C<state>, C<labels>, C<q>,
C<type>, C<milestones>, C<since>, C<before>, C<created_by>, C<assigned_by>,
C<mentioned_by>, C<sort>, C<page>, C<limit>).

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return map { $self->_issue($_) } @$data;
}

=method get

    my $issue = $repo->issues->get($index);

Get an issue by its index.

=cut

sub get {
    my ($self, $index) = @_;
    return $self->_issue($self->client->get($self->_path_for(uri_escape($index))));
}

=method create

    my $issue = $repo->issues->create({ title => 'Bug report', body => 'Description' });

Create an issue; the API requires C<title>.

=cut

sub create {
    my ($self, $data) = @_;
    return $self->_issue($self->client->post($self->_path_for, $data));
}

=method edit

    my $issue = $repo->issues->edit($index, { state => 'closed' });

Edit an issue.

=cut

sub edit {
    my ($self, $index, $data) = @_;
    return $self->_issue($self->client->patch($self->_path_for(uri_escape($index)), $data));
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
    $self->client->delete($self->_path_for(uri_escape($index)));
    return 1;
}

=method list_comments

    my @comments = $repo->issues->list_comments($index);

List the comments of an issue as L<WWW::Forgejo::Entity::IssueComment> objects.
Named arguments are sent as the query string (C<since>, C<before>).

=cut

sub list_comments {
    my ($self, $index, %params) = @_;
    my $data = $self->client->get($self->_path_for(uri_escape($index), 'comments'), params => \%params);
    return map {
        WWW::Forgejo::Entity::IssueComment->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

=method comments

Alias for L</list_comments>.

=cut

sub comments { shift->list_comments(@_) }

=method add_comment

    my $comment = $repo->issues->add_comment($index, { body => 'Looks good' });

Add a comment to an issue; the API requires C<body>. Returns the plain comment
structure.

=cut

sub add_comment {
    my ($self, $index, $data) = @_;
    return $self->client->post($self->_path_for(uri_escape($index), 'comments'), $data);
}

=method list_labels

    my @labels = $repo->issues->list_labels($index);

List the labels of an issue, as plain label structures.

=cut

sub list_labels {
    my ($self, $index) = @_;
    my $data = $self->client->get($self->_path_for(uri_escape($index), 'labels'));
    return @$data;
}

=method labels

Alias for L</list_labels>.

=cut

sub labels { shift->list_labels(@_) }

=method add_label

    my $labels = $repo->issues->add_label($index, { labels => [ $label_id ] });

Add labels to an issue. Returns the labels the issue then has.

=cut

sub add_label {
    my ($self, $index, $data) = @_;
    return $self->client->post($self->_path_for(uri_escape($index), 'labels'), $data);
}

=method remove_label

    $repo->issues->remove_label($index, $label_id);

Remove one label, given by its ID or name, from an issue. Returns true.

=cut

sub remove_label {
    my ($self, $index, $label) = @_;
    $self->client->delete($self->_path_for(uri_escape($index), 'labels', uri_escape($label)));
    return 1;
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @issues = $repo->issues->list;
    my @open   = $repo->issues->list(state => 'open');
    my @page2  = $repo->issues->list(page => 2, limit => 50);

    my $issue = $repo->issues->get(1);

    $issue = $repo->issues->create({
        title  => 'Bug report',
        body   => 'Description',
        labels => [ $label_id ],
    });

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/issues> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/issues>, which binds it to
that repository; every method then addresses that repository.

Depending on the method, results are L<WWW::Forgejo::Entity::Issue> and L<WWW::Forgejo::Entity::IssueComment>
objects or the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::Issue>, L<WWW::Forgejo::Entity::IssueComment>, L<WWW::Forgejo>

=cut
