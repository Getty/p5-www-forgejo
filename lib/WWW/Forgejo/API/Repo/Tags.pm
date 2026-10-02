# ABSTRACT: Forgejo Repo Tags API
# PODNAME: WWW::Forgejo::API::Repo::Tags

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Tags;

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
    return $self->_repo_path('tags', @path);
}

=method list

    my @tags = $repo->tags->list;
    my @tags = $repo->tags->list(page => 2, limit => 50);

List the tags of the repository, as plain tag structures. Named arguments are
sent as the query string.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return @$data;
}

=method get

    my $tag = $repo->tags->get($tag_name);

Get a specific tag by name.

=cut

sub get {
    my ($self, $tag_name) = @_;
    return $self->client->get($self->_path_for(uri_escape($tag_name)));
}

=method create

    my $tag = $repo->tags->create({ tag_name => 'v1.0.0', target => 'main' });

Create a tag; the API requires C<tag_name>.

=cut

sub create {
    my ($self, $data) = @_;
    return $self->client->post($self->_path_for, $data);
}

=method delete

    $repo->tags->delete($tag_name);

Delete a tag.

=cut

sub delete {
    my ($self, $tag_name) = @_;
    return $self->client->delete($self->_path_for(uri_escape($tag_name)));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @tags = $repo->tags->list;

    my $tag = $repo->tags->get('v1.0.0');

    $tag = $repo->tags->create({
        tag_name => 'v1.0.0',
        target   => 'main',
        message  => 'Release v1.0.0',
    });

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/tags> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/tags>, which binds it to
that repository; every method then addresses that repository.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo>

=cut
