# ABSTRACT: Forgejo Repo Assignees API
# PODNAME: WWW::Forgejo::API::Repo::Assignees

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Assignees;

use Moo;
use Log::Any qw($log);
use URI::Escape;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\uri_escape($self->owner)}/${\uri_escape($self->repo)}/assignees/" . join('/', @path);
}

=method list

    my @assignees = $self->list;

List all available assignees.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, %params);
    return @$data;
}

=method check

    my $is_assignee = $self->check('username');

Check if user is an assignee.

=cut

sub check {
    my ($self, $username) = @_;
    my $data = $self->{client}->get($self->_path_for(uri_escape($username)));
    return $data;
}

=method add

    $self->add(1, 'username');

Add an assignee to an issue.

=cut

sub add {
    my ($self, $index, $username) = @_;
    my $data = $self->{client}->post($self->_path_for("../issues/" . uri_escape($index) . "/assignees"), { assignee => $username });
    return $data;
}

=method remove

    $self->remove(1, 'username');

Remove an assignee from an issue.

=cut

sub remove {
    my ($self, $index, $username) = @_;
    $self->{client}->delete($self->_path_for("../issues/" . uri_escape($index) . "/assignees/" . uri_escape($username)));
    return;
}

1;
__END__

=cut
