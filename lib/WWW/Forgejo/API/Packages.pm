# ABSTRACT: Forgejo Packages API
# PODNAME: WWW::Forgejo::API::Packages

use strict;
use warnings;

package WWW::Forgejo::API::Packages;

use Moo;
use Carp qw(croak);
use WWW::Forgejo::URL qw( escape_component );
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

sub _package_path {
    my ($self, $owner, $type, $name, $version, @path) = @_;
    return join '/', '/packages', map { escape_component($_) } $owner, $type, $name, $version, @path;
}

# The upload of a package lives outside the /api/v1 of the API: Forgejo mounts
# the packages router at /api/packages on the instance.
sub _upload_base {
    my ($self) = @_;
    return $self->client->url . '/api';
}

=method list

    my $packages = $forgejo->packages->list($owner);
    my $packages = $forgejo->packages->list($owner, type => 'npm');

List the packages of an owner (C<GET /packages/{owner}>). Further named
arguments are sent as the query string of the request.

=cut

sub list {
    my ($self, $owner, %params) = @_;
    croak "Package owner required" unless defined $owner && length $owner;
    return $self->client->get("/packages/" . escape_component($owner), params => \%params);
}

=method get

    my $package = $forgejo->packages->get($owner, $type, $name, $version);

Get a specific package version.

=cut

sub get {
    my ($self, $owner, $type, $name, $version) = @_;
    return $self->client->get($self->_package_path($owner, $type, $name, $version));
}

=method delete

    $forgejo->packages->delete($owner, $type, $name, $version);

Delete a package version.

=cut

sub delete {
    my ($self, $owner, $type, $name, $version) = @_;
    return $self->client->delete($self->_package_path($owner, $type, $name, $version));
}

=method files

    my $files = $forgejo->packages->files($owner, $type, $name, $version);

List files for a specific package version.

=cut

sub files {
    my ($self, $owner, $type, $name, $version) = @_;
    return $self->client->get($self->_package_path($owner, $type, $name, $version, 'files'));
}

=method link

    $forgejo->packages->link($owner, 'generic', $name, $repo);

Link a package to a repository
(C<POST /packages/{owner}/{type}/{name}/-/link/{repo_name}>). The repository is
named by the last part of its path in the instance, C<my-repo> say.

=cut

sub link {
    my ($self, $owner, $type, $name, $repo) = @_;
    croak "Package owner required" unless defined $owner && length $owner;
    croak "Package type required" unless defined $type && length $type;
    croak "Package name required" unless defined $name && length $name;
    croak "Repository name required" unless defined $repo && length $repo;
    my $path = join '/', '/packages',
        map { escape_component($_) } $owner, $type, $name, '-', 'link', $repo;
    return $self->client->post($path);
}

=method unlink

    $forgejo->packages->unlink($owner, 'generic', $name);

Remove the link between a package and a repository
(C<POST /packages/{owner}/{type}/{name}/-/unlink>).

=cut

sub unlink {
    my ($self, $owner, $type, $name) = @_;
    croak "Package owner required" unless defined $owner && length $owner;
    croak "Package type required" unless defined $type && length $type;
    croak "Package name required" unless defined $name && length $name;
    my $path = join '/', '/packages',
        map { escape_component($_) } $owner, $type, $name, '-', 'unlink';
    return $self->client->post($path);
}

=method upload

    $forgejo->packages->upload($owner, 'generic', $name, $version, $filename,
        content => $bytes);
    $forgejo->packages->upload($owner, 'generic', $name, $version, $filename,
        file => '/path/to/file.txt');

Upload a file as a package
(C<PUT /api/packages/{owner}/{type}/{name}/{version}/{filename}>).

The upload lives outside the API: Forgejo mounts the packages router at
C</api/packages> on the instance, not under the C</api/v1> of the API. The
client sends the request to the instance all the same.

The file is given as C<content> (the bytes) or as C<file> (a path on disk);
C<content_type> names its media type (default C<application/octet-stream>).

=cut

sub upload {
    my ($self, $owner, $type, $name, $version, $filename, %args) = @_;

    croak "Package owner required" unless defined $owner && length $owner;
    croak "Package type required" unless defined $type && length $type;
    croak "Package name required" unless defined $name && length $name;
    croak "Package version required" unless defined $version && length $version;
    croak "File name required" unless defined $filename && length $filename;

    my $content = delete $args{content};
    my $file    = delete $args{file};
    my $content_type = delete $args{content_type};

    if (!defined $content && defined $file) {
        croak "upload: cannot read file $file" unless -r $file;
        open my $fh, '<:raw', $file or croak "upload: cannot read file $file: $!";
        $content = do { local $/; <$fh> };
        close $fh;
    }
    croak "upload: file or content required" unless defined $content;

    my $path = $self->_package_path($owner, $type, $name, $version, $filename);

    return $self->client->put($path, undef,
        base_url     => $self->_upload_base,
        content      => $content,
        content_type => $content_type // 'application/octet-stream',
    );
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $packages = $forgejo->packages->list('owner');
    my $package  = $forgejo->packages->get('owner', $type, $name, $version);
    my $files    = $forgejo->packages->files('owner', $type, $name, $version);
    $forgejo->packages->upload('owner', 'generic', $name, $version, 'file.txt',
        file => '/path/to/file.txt');

=head1 DESCRIPTION

The C</packages> endpoints: list the packages of an owner, inspect or delete a
single package version and upload a file as a package. Available as
C<< $forgejo->packages >>.

All methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo>

=cut
