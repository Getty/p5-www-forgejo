# ABSTRACT: Forgejo Repo Forks API
# PODNAME: WWW::Forgejo::API::Repo::Forks

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Forks;

use Moo;
use Log::Any qw($log);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\$self->owner}/${\\$self->repo}/forks/" . join('/', @path);
}

=method list

    my @forks = $self->list;

List all forks.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, %params);
    return @$data;
}

=method create

    my $fork = $self->create({
        organization => 'myorg',
    });

Fork a repository.

=cut

sub create {
    my ($self, $data) = @_;
    my $fork_data = $self->{client}->post($self->_path_for, $data);
    return $fork_data;
}

1;
__END__

=cut
