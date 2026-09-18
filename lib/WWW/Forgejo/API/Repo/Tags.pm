# ABSTRACT: Forgejo Repo Tags API
# PODNAME: WWW::Forgejo::API::Repo::Tags

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Tags;

use Moo;
use Log::Any qw($log);
use URI::Escape;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\uri_escape($self->owner)}/${\uri_escape($self->repo)}/tags/" . join('/', @path);
}

=method list

    my @tags = $self->list;

List all tags.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, %params);
    return @$data;
}

=method get

    my $tag = $self->get('v1.0.0');

Get a tag.

=cut

sub get {
    my ($self, $tag_name) = @_;
    my $path = $self->_path_for(uri_escape($tag_name));
    my $data = $self->{client}->get($path);
    return $data;
}

=method create

    my $tag = $self->create({
        tag_name  => 'v1.0.0',
        target    => 'main',
        message   => 'Release v1.0.0',
    });

Create a tag.

=cut

sub create {
    my ($self, $data) = @_;
    my $path = $self->_path_for;
    return $self->{client}->post($path, $data);
}

=method delete

    $self->delete('v1.0.0');

Delete a tag.

=cut

sub delete {
    my ($self, $tag_name) = @_;
    my $path = $self->_path_for(uri_escape($tag_name));
    return $self->{client}->delete($path);
}

1;
__END__

=cut
