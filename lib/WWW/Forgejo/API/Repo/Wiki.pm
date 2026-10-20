# ABSTRACT: Forgejo Repo Wiki API
# PODNAME: WWW::Forgejo::API::Repo::Wiki

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Wiki;

use Moo;
use WWW::Forgejo::URL qw( escape_component );
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
    return join '/', '/repos', escape_component($self->owner), escape_component($self->repo), @path;
}

sub _path_for {
    my ($self, @path) = @_;
    return $self->_repo_path('wiki', @path);
}

=method list_pages

    my $pages = $repo->wiki->list_pages;

List the wiki pages, as plain structures with the metadata of each page (not
its content), in an arrayref. Named arguments are sent as the query string.

=cut

sub list_pages {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for('pages'), params => \%params);
    return [@$data];
}

=method get_page

    my $page = $repo->wiki->get_page($page_name);

Get a wiki page by name, including its base64 encoded content. The name is the
C<sub_url> of the page (C<Page-Title> for the title C<Page Title>).

=cut

sub get_page {
    my ($self, $page_name) = @_;
    return $self->client->get($self->_path_for('page', escape_component($page_name)));
}

=method create_page

    my $page = $repo->wiki->create_page(
        title          => 'Page Title',
        content_base64 => $base64_encoded_markdown,
        message        => 'Add wiki page',
    );

Create a wiki page. The content is given base64 encoded as C<content_base64>.
The named arguments are sent as the JSON body.

=cut

sub create_page {
    my ($self, %params) = @_;
    return $self->client->post($self->_path_for('new'), \%params);
}

=method edit_page

    my $page = $repo->wiki->edit_page($page_name,
        title          => 'Page Title',
        content_base64 => $base64_encoded_markdown,
    );

Edit a wiki page; takes the same fields as L</create_page>. Without a
C<title> the page is titled with the name it is addressed by, C<$page_name>:
Forgejo (15) renames a page that is edited without a title to C<unnamed>. The
named arguments are sent as the JSON body.

=cut

sub edit_page {
    my ($self, $page_name, %params) = @_;

    my $body = { %params };
    # Without a title Forgejo (15) renames the page to "unnamed". The
    # name the caller addresses the page by is the title it wants.
    $body->{title} = $page_name
        unless defined $body->{title} && length $body->{title};

    return $self->client->patch($self->_path_for('page', escape_component($page_name)), $body);
}

=method delete_page

    $repo->wiki->delete_page($page_name);

Delete a wiki page.

=cut

sub delete_page {
    my ($self, $page_name) = @_;
    $self->client->delete($self->_path_for('page', escape_component($page_name)));
    return;
}

=method revisions

    my $revisions = $repo->wiki->revisions('Page-Title');

List the revisions of a wiki page
(C<GET /repos/{owner}/{repo}/wiki/revisions/{pageName}>). The name of the page
is the C<sub_url> of the page, as in L</get_page>. Named arguments are sent as
the query string; C<page> names the page of the list.

=cut

sub revisions {
    my ($self, $page_name, %params) = @_;
    my $data = $self->client->get(
        $self->_path_for('revisions', escape_component($page_name)), params => \%params);
    return [@$data];
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my $pages = $repo->wiki->list_pages;

    my $page = $repo->wiki->get_page('Home');

    $page = $repo->wiki->create_page(
        title          => 'Page Title',
        content_base64 => $base64_encoded_markdown,
        message        => 'Add wiki page',
    );

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/wiki> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/wiki>, which binds it to
that repository; every method then addresses that repository.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo>

=cut
