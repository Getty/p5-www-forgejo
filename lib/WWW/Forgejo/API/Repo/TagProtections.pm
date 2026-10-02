# ABSTRACT: Forgejo Repo Tag Protections API
# PODNAME: WWW::Forgejo::API::Repo::TagProtections

use strict;
use warnings;

package WWW::Forgejo::API::Repo::TagProtections;

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
    return $self->_repo_path('tag_protections', @path);
}

=method list

    my @protections = $repo->tag_protections->list;

List the tag protections of the repository, as plain structures. Named
arguments are sent as the query string.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return @$data;
}

=method get

    my $protection = $repo->tag_protections->get($id);

Get a specific tag protection by ID.

=cut

sub get {
    my ($self, $id) = @_;
    return $self->client->get($self->_path_for(uri_escape($id)));
}

=method create

    my $protection = $repo->tag_protections->create({
        name_pattern        => 'v*',
        whitelist_usernames => ['releaser'],
    });

Create a tag protection.

=cut

sub create {
    my ($self, $data) = @_;
    return $self->client->post($self->_path_for, $data);
}

=method edit

    my $protection = $repo->tag_protections->edit($id, { name_pattern => 'release-*' });

Edit a tag protection; only the fields that are given are changed.

=cut

sub edit {
    my ($self, $id, $data) = @_;
    return $self->client->patch($self->_path_for(uri_escape($id)), $data);
}

=method update

Alias for L</edit>.

=cut

sub update { shift->edit(@_) }

=method delete

    $repo->tag_protections->delete($id);

Delete a tag protection.

=cut

sub delete {
    my ($self, $id) = @_;
    return $self->client->delete($self->_path_for(uri_escape($id)));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @protections = $repo->tag_protections->list;

    my $protection = $repo->tag_protections->create({
        name_pattern => 'v*',
    });

    $protection = $repo->tag_protections->get($protection->{id});

    $protection = $repo->tag_protections->edit($protection->{id}, { name_pattern => 'release-*' });

    $repo->tag_protections->delete($protection->{id});

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/tag_protections> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/tag_protections>, which binds it to
that repository; every method then addresses that repository.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo>

=cut
