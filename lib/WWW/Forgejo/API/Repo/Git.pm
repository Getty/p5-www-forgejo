# ABSTRACT: Forgejo Repo Git API
# PODNAME: WWW::Forgejo::API::Repo::Git

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Git;

use Moo;
use WWW::Forgejo::URL qw( escape_component );
use Carp qw(croak);
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
    return $self->client->get($self->_path_for('refs', map { escape_component($_) } split m{/}, $ref));
}

=method get_commit

    my $commit = $repo->git->get_commit($sha);

Get a single commit. Named arguments are sent as the query string (C<stat>,
C<verification>, C<files>).

=cut

sub get_commit {
    my ($self, $sha, %params) = @_;
    return $self->client->get($self->_path_for('commits', escape_component($sha)), params => \%params);
}

=method diff

    my $diff  = $repo->git->diff($sha, 'diff');
    my $patch = $repo->git->diff($sha, 'patch');

Get the diff or the patch of a commit
(C<GET /repos/{owner}/{repo}/git/commits/{sha}.{diffType}>). The type is C<diff>
or C<patch>. Returns the body of the response as it is, as bytes.

=cut

sub diff {
    my ($self, $sha, $type) = @_;
    return $self->client->get(
        $self->_path_for('commits', escape_component($sha) . '.' . escape_component($type)), raw => 1);
}

=method get_tree

    my $tree = $repo->git->get_tree($sha);
    my $tree = $repo->git->get_tree($sha, recursive => 'true');

Get the tree of a commit. Named arguments are sent as the query string
(C<recursive>, C<page>, C<per_page>).

=cut

sub get_tree {
    my ($self, $sha, %params) = @_;
    return $self->client->get($self->_path_for('trees', escape_component($sha)), params => \%params);
}

=method get_blob

    my $blob = $repo->git->get_blob($sha);

Get a blob.

=cut

sub get_blob {
    my ($self, $sha) = @_;
    return $self->client->get($self->_path_for('blobs', escape_component($sha)));
}

=method list_blobs

    my $blobs = $repo->git->list_blobs('a1b2c3,d4e5f6');

Get the blobs of the given object ids
(C<GET /repos/{owner}/{repo}/git/blobs>). The object ids are given as one
argument, separated by commas. The blobs are returned as plain structures in
an arrayref.

=cut

sub list_blobs {
    my ($self, $shas) = @_;
    croak "Object ids required" unless defined $shas && length $shas;
    my $data = $self->client->get($self->_path_for('blobs'), params => { shas => $shas });
    return [@$data];
}

=method get_tag

    my $tag = $repo->git->get_tag($sha);

Get the tag object of the repository
(C<GET /repos/{owner}/{repo}/git/tags/{sha}>).

=cut

sub get_tag {
    my ($self, $sha) = @_;
    return $self->client->get($self->_path_for('tags', escape_component($sha)));
}

=method get_note

    my $note = $repo->git->get_note($sha);

Get the note of a commit
(C<GET /repos/{owner}/{repo}/git/notes/{sha}>). The commit is addressed by its
SHA. Named arguments are sent as the query string (C<verification>, C<files>).

=cut

sub get_note {
    my ($self, $sha, %params) = @_;
    return $self->client->get($self->_path_for('notes', escape_component($sha)), params => \%params);
}

=method create_note

    my $note = $repo->git->create_note($sha, message => 'A note');

Add a note to a commit
(C<POST /repos/{owner}/{repo}/git/notes/{sha}>). The named arguments are sent
as the JSON body; the API takes the text of the note in C<message>.

=cut

sub create_note {
    my ($self, $sha, %params) = @_;
    return $self->client->post($self->_path_for('notes', escape_component($sha)), \%params);
}

=method delete_note

    $repo->git->delete_note($sha);

Delete the note of a commit
(C<DELETE /repos/{owner}/{repo}/git/notes/{sha}>). Returns true.

=cut

sub delete_note {
    my ($self, $sha) = @_;
    $self->client->delete($self->_path_for('notes', escape_component($sha)));
    return 1;
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
