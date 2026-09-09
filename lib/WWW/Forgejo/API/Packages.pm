# ABSTRACT: Forgejo Packages API
# PODNAME: WWW::Forgejo::API::Packages

use strict;
use warnings;

package WWW::Forgejo::API::Packages;

use Moo;
use Log::Any qw($log);
use URI::Escape;

has client => (
    is       => 'ro',
    init_arg => 'client',
);


=method list

    my $packages = $self->client->list;
    my $packages = $self->client->list(type => 'maven', page => 1);

List all packages for the current user or globally (admin).

=cut

sub list {
    my ($self, %params) = @_;
    return $self->client->get('/packages', params => \%params);
}

=method get

    my $package = $self->client->get($owner, $repo, $type, $name, $version);

Get a specific package.

=cut

sub get {
    my ($self, $owner, $type, $name, $version) = @_;
    return $self->client->get("/packages/" . uri_escape($owner) . "/" . uri_escape($type) . "/" . uri_escape($name) . "/" . uri_escape($version));
}

=method delete

    $self->client->delete($owner, $type, $name, $version);

Delete a package.

=cut

sub delete {
    my ($self, $owner, $type, $name, $version) = @_;
    return $self->client->delete("/packages/" . uri_escape($owner) . "/" . uri_escape($type) . "/" . uri_escape($name) . "/" . uri_escape($version));
}

=method files

    my $files = $self->client->files($owner, $type, $name, $version);

List files for a specific package version.

=cut

sub files {
    my ($self, $owner, $type, $name, $version) = @_;
    return $self->client->get("/packages/" . uri_escape($owner) . "/" . uri_escape($type) . "/" . uri_escape($name) . "/" . uri_escape($version) . "/files");
}

1;