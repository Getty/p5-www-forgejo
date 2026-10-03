# ABSTRACT: Forgejo Repo Contents API
# PODNAME: WWW::Forgejo::API::Repo::Contents

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Contents;

use Moo;
use URI::Escape qw(uri_escape);
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
    return join '/', '/repos', uri_escape($self->owner), uri_escape($self->repo), @path;
}

sub _path_for {
    my ($self, @path) = @_;
    return $self->_repo_path('contents', @path);
}

# A file path keeps its slashes; every segment between them is escaped.
sub _file_path {
    my ($self, $path) = @_;
    return map { uri_escape($_) } grep { length } split m{/}, $path // '';
}

=method get

    my $content = $repo->contents->get($path);
    my $content = $repo->contents->get($path, ref => 'develop');
    my $entries = $repo->contents->get('');

Get the metadata and contents of a file, or the entries of a directory. An
empty path addresses the root directory. Named arguments are sent as the query
string; C<ref> selects the branch, tag or commit.

=cut

sub get {
    my ($self, $path, %params) = @_;
    return $self->client->get($self->_path_for($self->_file_path($path)), params => \%params);
}

=method get_archive

    my $zip = $repo->contents->get_archive('main.zip');

Download an archive of the repository. The argument is a git reference with the
archive format attached, e.g. C<main.zip>. Returns the archive as bytes.

=cut

sub get_archive {
    my ($self, $archive) = @_;
    return $self->client->get($self->_repo_path('archive', $self->_file_path($archive)), raw => 1);
}

=method create

    my $file = $repo->contents->create($path, {
        content => $base64_encoded_content,
        message => 'Add file',
        branch  => 'main',
    });

Create a file; the API requires the base64 encoded C<content>.

=cut

sub create {
    my ($self, $path, $data) = @_;
    return $self->client->post($self->_path_for($self->_file_path($path)), $data);
}

=method update

    my $file = $repo->contents->update($path, {
        content => $base64_encoded_content,
        sha     => $current_sha,
        message => 'Update file',
    });

Update a file; the API requires C<content> and the C<sha> of the file being
replaced.

=cut

sub update {
    my ($self, $path, $data) = @_;
    return $self->client->put($self->_path_for($self->_file_path($path)), $data);
}

=method delete

    my $result = $repo->contents->delete($path, {
        sha     => $current_sha,
        message => 'Remove file',
        branch  => 'main',
    });

Delete a file. The data is sent as the JSON body of the request; the API
requires the C<sha> of the file being deleted and this method croaks without
it. Returns the decoded response, which describes the resulting commit.

=cut

sub delete {
    my ($self, $path, $data) = @_;
    croak "sha required to delete a file" unless ref $data eq 'HASH' && defined $data->{sha};
    return $self->client->delete($self->_path_for($self->_file_path($path)), $data);
}

=method raw

    my $bytes = $repo->contents->raw($path);
    my $bytes = $repo->contents->raw($path, ref => 'develop');

Get the raw contents of a file, as the bytes stored in the repository: a
text file is not decoded from its charset, a JSON file is not parsed. Named
arguments are sent as the query string.

=cut

sub raw {
    my ($self, $path, %params) = @_;
    return $self->client->get($self->_repo_path('raw', $self->_file_path($path)), params => \%params, raw => 1);
}

=method media

    my $bytes = $repo->contents->media($path);

Get the raw contents of a file like L</raw>, but with an LFS pointer resolved
to the file it stands for. Named arguments are sent as the query string.

=cut

sub media {
    my ($self, $path, %params) = @_;
    return $self->client->get($self->_repo_path('media', $self->_file_path($path)), params => \%params, raw => 1);
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my $content = $repo->contents->get('path/to/file.txt');

    my $file = $repo->contents->create('path/to/file.txt', {
        message => 'Add file',
        content => $base64_encoded_content,
        branch  => 'main',
    });

    $repo->contents->delete('path/to/file.txt', {
        sha     => $content->{sha},
        message => 'Remove file',
    });

    my $zip = $repo->contents->get_archive('main.zip');

=head1 DESCRIPTION

Controller for the file endpoints of one repository: C</repos/{owner}/{repo}/contents>, C</raw>, C</media> and C</archive>.
It is obtained through L<WWW::Forgejo::Entity::Repo/contents>, which binds it to
that repository; every method then addresses that repository.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo>

=cut
