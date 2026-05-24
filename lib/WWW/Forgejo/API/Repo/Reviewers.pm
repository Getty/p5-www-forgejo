# ABSTRACT: Forgejo Repo Reviewers API
# PODNAME: WWW::Forgejo::API::Repo::Reviewers

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Reviewers;

use Moo;
use Log::Any qw($log);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\$self->owner}/${\\$self->repo}/reviewers/" . join('/', @path);
}

=method list

    my @reviewers = $self->list(1);

List reviewers for a pull request.

=cut

sub list {
    my ($self, $index) = @_;
    my $data = $self->{client}->get($self->_path_for("../pulls/$index/reviewers"));
    return @$data;
}

=method add

    $self->add(1, ['user1', 'user2']);

Add reviewers to a pull request.

=cut

sub add {
    my ($self, $index, $reviewers) = @_;
    my $data = $self->{client}->post($self->_path_for("../pulls/$index/reviewers"), { reviewers => $reviewers });
    return $data;
}

=method remove

    $self->remove(1, 'username');

Remove a reviewer from a pull request.

=cut

sub remove {
    my ($self, $index, $username) = @_;
    $self->{client}->delete($self->_path_for("../pulls/$index/reviewers/$username"));
    return;
}

1;
__END__

=cut
