# ABSTRACT: Forgejo Repo Subscribers API
# PODNAME: WWW::Forgejo::API::Repo::Subscribers

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Subscribers;

use Moo;
use Log::Any qw($log);
use URI::Escape;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\uri_escape($self->owner)}/${\uri_escape($self->repo)}/subscribers/" . join('/', @path);
}

=method list

    my @subscribers = $self->list;

List all subscribers.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, %params);
    return @$data;
}

1;
__END__

=cut
