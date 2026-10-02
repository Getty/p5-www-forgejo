# ABSTRACT: Forgejo Repo Statuses API
# PODNAME: WWW::Forgejo::API::Repo::Statuses

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Statuses;

use Moo;
use URI::Escape qw(uri_escape);
use WWW::Forgejo::Entity::CommitStatus;
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
    return $self->_repo_path('statuses', @path);
}

sub _status {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::CommitStatus->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method list

    my @statuses = $repo->statuses->list($sha);
    my @failed   = $repo->statuses->list($sha, state => 'failure');

List the statuses of a commit as L<WWW::Forgejo::Entity::CommitStatus> objects.
Named arguments are sent as the query string (C<sort>, C<state>, C<page>,
C<limit>).

=cut

sub list {
    my ($self, $sha, %params) = @_;
    my $data = $self->client->get($self->_path_for(uri_escape($sha)), params => \%params);
    return map { $self->_status($_) } @$data;
}

=method create

    my $status = $repo->statuses->create($sha, { state => 'success', context => 'ci/build' });

Create a status for a commit. Returns the L<WWW::Forgejo::Entity::CommitStatus>.

=cut

sub create {
    my ($self, $sha, $data) = @_;
    return $self->_status($self->client->post($self->_path_for(uri_escape($sha)), $data));
}

=method combined

    my $combined = $repo->statuses->combined($ref);
    print $combined->{state};

Get the combined status of a branch, tag or commit: a structure with the
overall C<state>, the C<sha> and the single C<statuses> it is made of. Named
arguments are sent as the query string.

=cut

sub combined {
    my ($self, $ref, %params) = @_;
    return $self->client->get(
        $self->_repo_path('commits', (map { uri_escape($_) } split m{/}, $ref), 'status'),
        params => \%params,
    );
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @statuses = $repo->statuses->list($sha);

    my $status = $repo->statuses->create($sha, {
        state       => 'success',
        target_url  => 'https://ci.example.com/build/123',
        description => 'Build passed',
        context     => 'ci/build',
    });

    my $combined = $repo->statuses->combined('main');

=head1 DESCRIPTION

Controller for the commit status endpoints of one repository: C</repos/{owner}/{repo}/statuses/{sha}> and C</repos/{owner}/{repo}/commits/{ref}/status>.
It is obtained through L<WWW::Forgejo::Entity::Repo/statuses>, which binds it to
that repository; every method then addresses that repository.

Depending on the method, results are L<WWW::Forgejo::Entity::CommitStatus>
objects or the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::CommitStatus>, L<WWW::Forgejo>

=cut
