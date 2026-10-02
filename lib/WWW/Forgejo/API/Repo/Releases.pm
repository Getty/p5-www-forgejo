# ABSTRACT: Forgejo Repo Releases API
# PODNAME: WWW::Forgejo::API::Repo::Releases

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Releases;

use Moo;
use URI::Escape qw(uri_escape);
use WWW::Forgejo::Entity::Release;
use WWW::Forgejo::Entity::ReleaseAsset;
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
    return $self->_repo_path('releases', @path);
}

sub _release {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::Release->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

sub _asset {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::ReleaseAsset->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method list

    my @releases = $repo->releases->list;
    my @drafts   = $repo->releases->list(draft => 'true');

List the releases as L<WWW::Forgejo::Entity::Release> objects. Named arguments
are sent as the query string (C<draft>, C<pre-release>, C<q>, C<page>,
C<limit>).

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return map { $self->_release($_) } @$data;
}

=method get

    my $release = $repo->releases->get($id);

Get a release by ID.

=cut

sub get {
    my ($self, $id) = @_;
    return $self->_release($self->client->get($self->_path_for(uri_escape($id))));
}

=method get_by_tag

    my $release = $repo->releases->get_by_tag('v1.0.0');

Get a release by the name of its tag.

=cut

sub get_by_tag {
    my ($self, $tag) = @_;
    return $self->_release($self->client->get($self->_path_for('tags', uri_escape($tag))));
}

=method latest

    my $release = $repo->releases->latest;

Get the most recent release that is neither a draft nor a pre-release
(C<GET /repos/{owner}/{repo}/releases/latest>).

=cut

sub latest {
    my ($self) = @_;
    return $self->_release($self->client->get($self->_path_for('latest')));
}

=method create

    my $release = $repo->releases->create({ tag_name => 'v1.0.0', name => 'First release' });

Create a release; the API requires C<tag_name>.

=cut

sub create {
    my ($self, $data) = @_;
    return $self->_release($self->client->post($self->_path_for, $data));
}

=method edit

    my $release = $repo->releases->edit($id, { draft => \0 });

Edit a release.

=cut

sub edit {
    my ($self, $id, $data) = @_;
    return $self->_release($self->client->patch($self->_path_for(uri_escape($id)), $data));
}

=method update

Alias for L</edit>.

=cut

sub update { shift->edit(@_) }

=method delete

    $repo->releases->delete($id);

Delete a release. Returns true.

=cut

sub delete {
    my ($self, $id) = @_;
    $self->client->delete($self->_path_for(uri_escape($id)));
    return 1;
}

=method delete_by_tag

    $repo->releases->delete_by_tag($tag);

Delete the release that belongs to a tag. Returns true.

=cut

sub delete_by_tag {
    my ($self, $tag) = @_;
    $self->client->delete($self->_path_for('tags', uri_escape($tag)));
    return 1;
}

=method assets

    my @assets = $repo->releases->assets($id);

List the attachments of a release as L<WWW::Forgejo::Entity::ReleaseAsset>
objects.

=cut

sub assets {
    my ($self, $id) = @_;
    my $data = $self->client->get($self->_path_for(uri_escape($id), 'assets'));
    return map { $self->_asset($_) } @$data;
}

=method upload_asset

    my $asset = $repo->releases->upload_asset($id, file => 'dist/app.tar.gz');
    my $asset = $repo->releases->upload_asset($id,
        file => 'dist/app.tar.gz',
        name => 'app-1.0.tar.gz',
    );
    my $asset = $repo->releases->upload_asset($id,
        filename => 'notes.txt',
        content  => $text,
    );

Upload a file as attachment of a release, as a C<multipart/form-data> request.
The file is taken from disk (C<file>) or from memory (C<content>, which needs a
C<filename>); C<filename> overrides the name sent along with a C<file>. C<name>
is the name the attachment gets on the server, sent as query parameter; without
it the server uses the name of the uploaded file. Returns the
L<WWW::Forgejo::Entity::ReleaseAsset>.

=cut

sub upload_asset {
    my ($self, $id, %upload) = @_;
    my $name = delete $upload{name};
    my $data = $self->client->post(
        $self->_path_for(uri_escape($id), 'assets'), undef,
        params => { name => $name },
        upload => \%upload,
    );
    return $self->_asset($data);
}

=method get_asset

    my $asset = $repo->releases->get_asset($id, $asset_id);

Get one attachment of a release as L<WWW::Forgejo::Entity::ReleaseAsset>.

=cut

sub get_asset {
    my ($self, $id, $asset_id) = @_;
    return $self->_asset($self->client->get($self->_path_for(uri_escape($id), 'assets', uri_escape($asset_id))));
}

=method edit_asset

    my $asset = $repo->releases->edit_asset($id, $asset_id, { name => 'app-1.0.tar.gz' });

Edit an attachment of a release; the API takes C<name> and, for an external
attachment, C<browser_download_url>. Returns the
L<WWW::Forgejo::Entity::ReleaseAsset>.

=cut

sub edit_asset {
    my ($self, $id, $asset_id, $data) = @_;
    return $self->_asset(
        $self->client->patch($self->_path_for(uri_escape($id), 'assets', uri_escape($asset_id)), $data));
}

=method delete_asset

    $repo->releases->delete_asset($id, $asset_id);

Delete an attachment of a release. Returns true.

=cut

sub delete_asset {
    my ($self, $id, $asset_id) = @_;
    $self->client->delete($self->_path_for(uri_escape($id), 'assets', uri_escape($asset_id)));
    return 1;
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @releases = $repo->releases->list;

    my $release = $repo->releases->get_by_tag('v1.0.0');
    $release    = $repo->releases->latest;
    $release    = $repo->releases->edit($release->id, { name => 'First release' });

    my $asset = $repo->releases->upload_asset($release->id, file => 'dist/app.tar.gz');
    $repo->releases->delete_asset($release->id, $asset->id);

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/releases> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/releases>, which binds it to
that repository; every method then addresses that repository.

Depending on the method, results are L<WWW::Forgejo::Entity::Release> and L<WWW::Forgejo::Entity::ReleaseAsset>
objects or the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::Release>, L<WWW::Forgejo::Entity::ReleaseAsset>, L<WWW::Forgejo>

=cut
