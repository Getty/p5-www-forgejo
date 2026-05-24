# ABSTRACT: Forgejo Repo Tag Protections API
# PODNAME: WWW::Forgejo::API::Repo::TagProtections

use strict;
use warnings;

package WWW::Forgejo::API::Repo::TagProtections;

use Moo;
use Log::Any qw($log);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\$self->owner}/${\\$self->repo}/tag_protections/" . join('/', @path);
}

=method list

    my @protections = $self->list;

List all tag protections.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, %params);
    return @$data;
}

=method get

    my $protection = $self->get(1);

Get a tag protection.

=cut

sub get {
    my ($self, $id) = @_;
    my $path = $self->_path_for($id);
    my $data = $self->{client}->get($path);
    return $data;
}

=method create

    my $protection = $self->create({
        pattern => 'v*',
    });

Create a tag protection.

=cut

sub create {
    my ($self, $data) = @_;
    my $path = $self->_path_for;
    return $self->{client}->post($path, $data);
}

=method delete

    $self->delete(1);

Delete a tag protection.

=cut

sub delete {
    my ($self, $id) = @_;
    my $path = $self->_path_for($id);
    return $self->{client}->delete($path);
}

1;
__END__

=cut
