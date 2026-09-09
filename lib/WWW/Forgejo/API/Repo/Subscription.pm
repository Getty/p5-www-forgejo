# ABSTRACT: Forgejo Repo Subscription API
# PODNAME: WWW::Forgejo::API::Repo::Subscription

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Subscription;

use Moo;
use Log::Any qw($log);
use URI::Escape;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\uri_escape($self->owner)}/${\uri_escape($self->repo)}/subscription/" . join('/', @path);
}

=method get

    my $sub = $self->get;

Get subscription status.

=cut

sub get {
    my ($self) = @_;
    my $data = $self->{client}->get($self->_path_for);
    return $data;
}

=method subscribe

    $self->subscribe;

Subscribe to a repository.

=cut

sub subscribe {
    my ($self) = @_;
    my $data = $self->{client}->put($self->_path_for, { subscribed => \1, ignored => \0 });
    return $data;
}

=method unsubscribe

    $self->unsubscribe;

Unsubscribe from a repository.

=cut

sub unsubscribe {
    my ($self) = @_;
    $self->{client}->delete($self->_path_for);
    return;
}

1;
__END__

=cut
