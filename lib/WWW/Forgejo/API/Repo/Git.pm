# ABSTRACT: Forgejo Repo Git API
# PODNAME: WWW::Forgejo::API::Repo::Git

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Git;

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
    return $self->_repo_path('git', @path);
}

=method list_refs

    my $refs = $repo->git->list_refs;

List all git references of the repository.

=cut

sub list_refs {
    my ($self) = @_;
    return $self->client->get($self->_path_for('refs'));
}

=method get_ref

    my $ref = $repo->git->get_ref('heads/main');
    my $refs = $repo->git->get_ref('tags');

Get the git references matching a name, given without the leading C<refs/>.
The API answers with a list, as the name may match several references.

The API only reads references; branches and tags are created and deleted
through L<WWW::Forgejo::API::Repo::Branches> and
L<WWW::Forgejo::API::Repo::Tags>.

=cut

sub get_ref {
    my ($self, $ref) = @_;
    return $self->client->get($self->_path_for('refs', map { uri_escape($_) } split m{/}, $ref));
}

=method get_commit

    my $commit = $repo->git->get_commit($sha);

Get a single commit. Named arguments are sent as the query string (C<stat>,
C<verification>, C<files>).

=cut

sub get_commit {
    my ($self, $sha, %params) = @_;
    return $self->client->get($self->_path_for('commits', uri_escape($sha)), params => \%params);
}

=method get_tree

    my $tree = $repo->git->get_tree($sha);
    my $tree = $repo->git->get_tree($sha, recursive => 'true');

Get the tree of a commit. Named arguments are sent as the query string
(C<recursive>, C<page>, C<per_page>).

=cut

sub get_tree {
    my ($self, $sha, %params) = @_;
    return $self->client->get($self->_path_for('trees', uri_escape($sha)), params => \%params);
}

=method get_blob

    my $blob = $repo->git->get_blob($sha);

Get a blob.

=cut

sub get_blob {
    my ($self, $sha) = @_;
    return $self->client->get($self->_path_for('blobs', uri_escape($sha)));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my $refs = $repo->git->list_refs;

    $refs = $repo->git->get_ref('heads/main');

    my $commit = $repo->git->get_commit($sha);

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/git> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/git>, which binds it to
that repository; every method then addresses that repository.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo>

=cut
