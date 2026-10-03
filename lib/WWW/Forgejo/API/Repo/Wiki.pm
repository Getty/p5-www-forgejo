# ABSTRACT: Forgejo Repo Wiki API
# PODNAME: WWW::Forgejo::API::Repo::Wiki

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Wiki;

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
    return $self->_repo_path('wiki', @path);
}

=method list_pages

    my @pages = $repo->wiki->list_pages;

List the wiki pages, as plain structures with the metadata of each page (not
its content). Named arguments are sent as the query string.

=cut

sub list_pages {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for('pages'), params => \%params);
    return @$data;
}

=method get_page

    my $page = $repo->wiki->get_page($page_name);

Get a wiki page by name, including its base64 encoded content. The name is the
C<sub_url> of the page (C<Page-Title> for the title C<Page Title>).

=cut

sub get_page {
    my ($self, $page_name) = @_;
    return $self->client->get($self->_path_for('page', uri_escape($page_name)));
}

=method create_page

    my $page = $repo->wiki->create_page({
        title          => 'Page Title',
        content_base64 => $base64_encoded_markdown,
        message        => 'Add wiki page',
    });

Create a wiki page. The content is given base64 encoded as C<content_base64>.

=cut

sub create_page {
    my ($self, $data) = @_;
    return $self->client->post($self->_path_for('new'), $data);
}

=method edit_page

    my $page = $repo->wiki->edit_page($page_name, {
        title          => 'Page Title',
        content_base64 => $base64_encoded_markdown,
    });

Edit a wiki page; takes the same fields as L</create_page>. Pass the C<title>
even when it stays the same: without one Forgejo (15) renames the page to
C<unnamed>.

=cut

sub edit_page {
    my ($self, $page_name, $data) = @_;
    return $self->client->patch($self->_path_for('page', uri_escape($page_name)), $data);
}

=method delete_page

    $repo->wiki->delete_page($page_name);

Delete a wiki page.

=cut

sub delete_page {
    my ($self, $page_name) = @_;
    $self->client->delete($self->_path_for('page', uri_escape($page_name)));
    return;
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @pages = $repo->wiki->list_pages;

    my $page = $repo->wiki->get_page('Home');

    $page = $repo->wiki->create_page({
        title          => 'Page Title',
        content_base64 => $base64_encoded_markdown,
        message        => 'Add wiki page',
    });

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/wiki> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/wiki>, which binds it to
that repository; every method then addresses that repository.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo>

=cut
