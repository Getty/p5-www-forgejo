# ABSTRACT: Forgejo Repo Stargazers API
# PODNAME: WWW::Forgejo::API::Repo::Stargazers

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Stargazers;

use Moo;
use Log::Any qw($log);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\$self->owner}/${\\$self->repo}/stargazers/" . join('/', @path);
}

=method list

    my @stargazers = $self->list;

List all stargazers.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, %params);
    return @$data;
}

1;
__END__

=cut
