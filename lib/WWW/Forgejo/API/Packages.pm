# ABSTRACT: Forgejo Packages API
# PODNAME: WWW::Forgejo::API::Packages

use strict;
use warnings;

package WWW::Forgejo::API::Packages;

use Moo;
use Carp qw(croak);
use URI::Escape qw(uri_escape);
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

sub _package_path {
    my ($self, $owner, $type, $name, $version, @path) = @_;
    return join '/', '/packages', map { uri_escape($_) } $owner, $type, $name, $version, @path;
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
    return $self->client->get("/packages/" . uri_escape($owner), params => \%params);
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

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $packages = $forgejo->packages->list('owner');
    my $package  = $forgejo->packages->get('owner', $type, $name, $version);
    my $files    = $forgejo->packages->files('owner', $type, $name, $version);

=head1 DESCRIPTION

The C</packages> endpoints: list the packages of an owner and inspect or delete
a single package version. Available as C<< $forgejo->packages >>.

All methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo>

=cut
