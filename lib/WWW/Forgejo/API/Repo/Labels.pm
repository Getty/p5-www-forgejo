# ABSTRACT: Forgejo Repo Labels API
# PODNAME: WWW::Forgejo::API::Repo::Labels

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Labels;

use Moo;
use Log::Any qw($log);
use URI::Escape;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\uri_escape($self->owner)}/${\uri_escape($self->repo)}/labels/" . join('/', @path);
}

=method list

    my @labels = $self->list;

List all labels.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, %params);
    return @$data;
}

=method get

    my $label = $self->get(1);

Get a label by ID.

=cut

sub get {
    my ($self, $id) = @_;
    my $data = $self->{client}->get($self->_path_for(uri_escape($id)));
    return $data;
}

=method create

    my $label = $self->create({
        name        => 'bug',
        color       => 'ff0000',
        description => 'Bug report label',
    });

Create a label.

=cut

sub create {
    my ($self, $data) = @_;
    my $path = $self->_path_for;
    return $self->{client}->post($path, $data);
}

=method update

    my $label = $self->update(1, { color => '00ff00' });

Update a label.

=cut

sub update {
    my ($self, $id, $data) = @_;
    my $path = $self->_path_for(uri_escape($id));
    return $self->{client}->patch($path, $data);
}

=method edit

    my $label = $self->edit(1, { color => '00ff00' });

Update a label (alias for update).

=cut

sub edit {
    my ($self, $id, $data) = @_;
    return $self->update($id, $data);
}

=method delete

    $self->delete(1);

Delete a label.

=cut

sub delete {
    my ($self, $id) = @_;
    my $path = $self->_path_for(uri_escape($id));
    return $self->{client}->delete($path);
}

1;
__END__

=cut
