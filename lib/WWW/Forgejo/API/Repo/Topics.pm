# ABSTRACT: Forgejo Repo Topics API
# PODNAME: WWW::Forgejo::API::Repo::Topics

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Topics;

use Moo;
use Log::Any qw($log);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\$self->owner}/${\\$self->repo}/topics/" . join('/', @path);
}

=method list

    my @topics = $self->list;

List all repository topics.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, %params);
    return $data->{topics} // [];
}

=method add

    $self->add(['perl', 'cpan']);

Add topics to a repository.

=cut

sub add {
    my ($self, $topics) = @_;
    my $data = $self->{client}->put($self->_path_for, { topics => $topics });
    return $data->{topics} // [];
}

=method remove

    $self->remove('old-topic');

Remove a topic from a repository.

=cut

sub remove {
    my ($self, $topic) = @_;
    $self->{client}->delete($self->_path_for($topic));
    return;
}

1;
__END__

=cut
