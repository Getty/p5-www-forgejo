# ABSTRACT: Forgejo Repo Flags API
# PODNAME: WWW::Forgejo::API::Repo::Flags

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Flags;

use Moo;
use Log::Any qw($log);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\$self->owner}/${\\$self->repo}/flags/" . join('/', @path);
}

=method list

    my @flags = $self->list;

List all repository flags.

=cut

sub list {
    my ($self) = @_;
    my $data = $self->{client}->get($self->_path_for);
    return @$data;
}

=method add

    $self->add(['security', 'performance']);

Add flags to a repository.

=cut

sub add {
    my ($self, $flag) = @_;
    my $data = $self->{client}->post($self->_path_for, { flag => $flag });
    return $data;
}

=method remove

    $self->remove('flag-name');

Remove a flag from a repository.

=cut

sub remove {
    my ($self, $flag) = @_;
    $self->{client}->delete($self->_path_for($flag));
    return;
}

1;
__END__

=cut
