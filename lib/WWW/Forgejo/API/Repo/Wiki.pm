# ABSTRACT: Forgejo Repo Wiki API
# PODNAME: WWW::Forgejo::API::Repo::Wiki

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Wiki;

use Moo;
use Log::Any qw($log);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\$self->owner}/${\\$self->repo}/wiki/" . join('/', @path);
}

=method list

    my @pages = $self->list;

List wiki pages.

=cut

sub list_pages {
    my ($self) = @_;
    my $data = $self->{client}->get($self->_path_for);
    return @$data;
}

=method get_page

    my $page = $self->get_page('page-slug');

Get a wiki page.

=cut

sub get_page {
    my ($self, $slug) = @_;
    my $data = $self->{client}->get($self->_path_for($slug));
    return $data;
}

=method create_page

    my $page = $self->create_page({
        title   => 'Page Title',
        content => 'Page content in markdown',
        message => 'Add wiki page',
    });

Create a wiki page.

=cut

sub create_page {
    my ($self, $data) = @_;
    my $page = $self->{client}->post($self->_path_for, $data);
    return $page;
}

=method edit_page

    my $page = $self->edit_page('page-slug', {
        title   => 'Updated Title',
        content => 'Updated content',
        message => 'Update wiki page',
    });

Edit a wiki page.

=cut

sub edit_page {
    my ($self, $slug, $data) = @_;
    my $page = $self->{client}->patch($self->_path_for($slug), $data);
    return $page;
}

=method delete_page

    $self->delete_page('page-slug', {
        message => 'Delete wiki page',
    });

Delete a wiki page.

=cut

sub delete_page {
    my ($self, $slug, $data) = @_;
    $self->{client}->delete($self->_path_for($slug), $data ? $data : {});
    return;
}

1;
__END__

=cut
