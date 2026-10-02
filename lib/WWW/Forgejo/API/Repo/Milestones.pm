# ABSTRACT: Forgejo Repo Milestones API
# PODNAME: WWW::Forgejo::API::Repo::Milestones

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Milestones;

use Moo;
use URI::Escape qw(uri_escape);
use WWW::Forgejo::Entity::Milestone;
use WWW::Forgejo::Entity::Issue;
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
    return $self->_repo_path('milestones', @path);
}

sub _to_milestone {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::Milestone->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method list

    my @milestones = $repo->milestones->list;
    my @closed     = $repo->milestones->list(state => 'closed');

List the milestones as L<WWW::Forgejo::Entity::Milestone> objects. Named
arguments are sent as the query string (C<state>, C<name>, C<page>, C<limit>).

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return map { $self->_to_milestone($_) } @$data;
}

=method get

    my $milestone = $repo->milestones->get($id);

Get a milestone by its ID or title.

=cut

sub get {
    my ($self, $id) = @_;
    return $self->_to_milestone($self->client->get($self->_path_for(uri_escape($id))));
}

=method create

    my $milestone = $repo->milestones->create({ title => 'v1.0' });

Create a milestone.

=cut

sub create {
    my ($self, $data) = @_;
    return $self->_to_milestone($self->client->post($self->_path_for, $data));
}

=method edit

    my $milestone = $repo->milestones->edit($id, { state => 'closed' });

Edit a milestone.

=cut

sub edit {
    my ($self, $id, $data) = @_;
    return $self->_to_milestone($self->client->patch($self->_path_for(uri_escape($id)), $data));
}

=method update

Alias for L</edit>.

=cut

sub update { shift->edit(@_) }

=method delete

    $repo->milestones->delete($id);

Delete a milestone. Returns true.

=cut

sub delete {
    my ($self, $id) = @_;
    $self->client->delete($self->_path_for(uri_escape($id)));
    return 1;
}

=method issues

    my @issues = $repo->milestones->issues($id);
    my @closed = $repo->milestones->issues($id, state => 'closed');

List the issues of a milestone, given by its ID or name, as
L<WWW::Forgejo::Entity::Issue> objects. This is the issue list of the
repository filtered by C<milestones>; further named arguments are sent as the
query string like in L<WWW::Forgejo::API::Repo::Issues/list>.

=cut

sub issues {
    my ($self, $id, %params) = @_;
    my $data = $self->client->get($self->_repo_path('issues'), params => { %params, milestones => $id });
    return map {
        WWW::Forgejo::Entity::Issue->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @milestones = $repo->milestones->list;

    my $milestone = $repo->milestones->get(1);

    $milestone = $repo->milestones->create({
        title       => 'v1.0',
        description => 'Version 1 milestone',
        due_on      => '2025-12-31T00:00:00Z',
    });

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/milestones> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/milestones>, which binds it to
that repository; every method then addresses that repository.

Depending on the method, results are L<WWW::Forgejo::Entity::Milestone> and L<WWW::Forgejo::Entity::Issue>
objects or the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::Milestone>, L<WWW::Forgejo::Entity::Issue>, L<WWW::Forgejo>

=cut
