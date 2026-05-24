# ABSTRACT: Forgejo Repo Contents API
# PODNAME: WWW::Forgejo::API::Repo::Contents

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Contents;

use Moo;
use Log::Any qw($log);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\$self->owner}/${\\$self->repo}/contents/" . join('/', @path);
}

=method get

    my $content = $self->get('path/to/file.txt');

Get file content.

=cut

sub get {
    my ($self, $path, %params) = @_;
    my $data = $self->{client}->get($self->_path_for($path), %params);
    return $data;
}

=method get_archive

    my $archive = $self->get_archive('main');

Get repository archive.

=cut

sub get_archive {
    my ($self, $ref) = @_;
    my $data = $self->{client}->get($self->_path_for("archive/$ref"));
    return $data;
}

=method create

    my $file = $self->create('path/to/file.txt', {
        message  => 'Add file',
        content  => 'base64_encoded_content',
        branch   => 'main',
    });

Create or update a file.

=cut

sub create {
    my ($self, $path, $data) = @_;
    my $file = $self->{client}->post($self->_path_for($path), $data);
    return $file;
}

=method update

    my $file = $self->update('path/to/file.txt', {
        message      => 'Update file',
        content      => 'base64_encoded_content',
        sha          => 'abc123',
        branch       => 'main',
    });

Update a file.

=cut

sub update {
    my ($self, $path, $data) = @_;
    my $file = $self->{client}->put($self->_path_for($path), $data);
    return $file;
}

=method delete

    $self->delete('path/to/file.txt', {
        message => 'Delete file',
        sha     => 'abc123',
        branch  => 'main',
    });

Delete a file.

=cut

sub delete {
    my ($self, $path, $data) = @_;
    $self->{client}->delete($self->_path_for($path), $data);
    return;
}

=method readme

    my $readme = $self->readme;

Get README content.

=cut

sub readme {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for('readme'), %params);
    return $data;
}

=method raw

    my $raw = $self->raw('path/to/file.txt');

Get raw file content.

=cut

sub raw {
    my ($self, $path) = @_;
    my $data = $self->{client}->get($self->_path_for("../raw/$path"));
    return $data;
}

=method media

    my $media = $self->media('path/to/image.png');

Get media file.

=cut

sub media {
    my ($self, $path) = @_;
    my $data = $self->{client}->get($self->_path_for("../media/$path"));
    return $data;
}

1;
__END__

=cut
