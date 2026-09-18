# ABSTRACT: Forgejo Repo Releases API
# PODNAME: WWW::Forgejo::API::Repo::Releases

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Releases;

use Moo;
use Log::Any qw($log);
use URI::Escape;
use Carp qw(croak);
use WWW::Forgejo::Entity::Release;
use WWW::Forgejo::Entity::ReleaseAsset;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\uri_escape($self->owner)}/${\uri_escape($self->repo)}/releases/" . join('/', @path);
}

=method list

    my @releases = $self->list;

List all releases.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, %params);
    return map {
        WWW::Forgejo::Entity::Release->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

=method get

    my $release = $self->get(1);

Get a release by ID.

=cut

sub get {
    my ($self, $id) = @_;
    my $data = $self->{client}->get($self->_path_for(uri_escape($id)));
    return WWW::Forgejo::Entity::Release->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method get_by_tag

    my $release = $self->get_by_tag('v1.0.0');

Get a release by tag.

=cut

sub get_by_tag {
    my ($self, $tag) = @_;
    my $data = $self->{client}->get($self->_path_for('tags', uri_escape($tag)));
    return WWW::Forgejo::Entity::Release->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method create

    my $release = $self->create({
        tag_name   => 'v1.0.0',
        name       => 'Version 1.0.0',
        body       => 'Release notes',
        target     => 'main',
    });

Create a release.

=cut

sub create {
    my ($self, $data) = @_;
    my $result = $self->{client}->post($self->_path_for, $data);
    return WWW::Forgejo::Entity::Release->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $result,
    );
}

=method edit

    my $release = $self->edit(1, { name => 'Updated name' });

Edit a release.

=cut

sub edit {
    my ($self, $id, $data) = @_;
    my $result = $self->{client}->patch($self->_path_for(uri_escape($id)), $data);
    return WWW::Forgejo::Entity::Release->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $result,
    );
}

=method update

    my $release = $self->update(1, { name => 'Updated name' });

Update a release (alias for edit).

=cut

*update = \&edit;

=method delete

    $self->delete(1);

Delete a release.

=cut

sub delete {
    my ($self, $id) = @_;
    $self->{client}->delete($self->_path_for(uri_escape($id)));
    return 1;
}

=method assets

    my @assets = $self->assets(1);

List assets for a release.

=cut

sub assets {
    my ($self, $id) = @_;
    my $data = $self->{client}->get($self->_path_for(uri_escape($id), 'assets'));
    return map {
        WWW::Forgejo::Entity::ReleaseAsset->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

sub upload_asset {
    my ($self, $id, $data) = @_;
    my $result = $self->{client}->post($self->_path_for(uri_escape($id), 'assets'), $data);
    return $result;
}

1;
__END__

=cut
