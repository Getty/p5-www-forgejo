# ABSTRACT: Forgejo Repo Labels API
# PODNAME: WWW::Forgejo::API::Repo::Labels

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Labels;

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
    return $self->_repo_path('labels', @path);
}

=method list

    my @labels = $repo->labels->list;

List the labels of the repository, as plain label structures. Named arguments
are sent as the query string (C<sort>, C<page>, C<limit>).

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return @$data;
}

=method get

    my $label = $repo->labels->get($id);

Get a specific label by ID.

=cut

sub get {
    my ($self, $id) = @_;
    return $self->client->get($self->_path_for(uri_escape($id)));
}

=method create

    my $label = $repo->labels->create({ name => 'bug', color => 'ff0000' });

Create a label; the API requires C<name> and C<color>.

=cut

sub create {
    my ($self, $data) = @_;
    return $self->client->post($self->_path_for, $data);
}

=method update

    my $label = $repo->labels->update($id, { color => '00ff00' });

Update a label.

=cut

sub update {
    my ($self, $id, $data) = @_;
    return $self->client->patch($self->_path_for(uri_escape($id)), $data);
}

=method edit

Alias for L</update>.

=cut

sub edit { shift->update(@_) }

=method delete

    $repo->labels->delete($id);

Delete a label.

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

    my @labels = $repo->labels->list;

    my $label = $repo->labels->get(1);

    $label = $repo->labels->create({
        name        => 'bug',
        color       => 'ff0000',
        description => 'Bug report label',
    });

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/labels> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/labels>, which binds it to
that repository; every method then addresses that repository.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo>

=cut
