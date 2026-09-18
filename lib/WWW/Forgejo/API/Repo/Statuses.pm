# ABSTRACT: Forgejo Repo Statuses API
# PODNAME: WWW::Forgejo::API::Repo::Statuses

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Statuses;

use Moo;
use Log::Any qw($log);
use URI::Escape;
use WWW::Forgejo::Entity::CommitStatus;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\uri_escape($self->owner)}/${\uri_escape($self->repo)}/statuses/" . join('/', @path);
}

=method list

    my @statuses = $self->list('abc123');

List commit statuses.

=cut

sub list {
    my ($self, $sha) = @_;
    my $data = $self->{client}->get($self->_path_for(uri_escape($sha)));
    return map {
        WWW::Forgejo::Entity::CommitStatus->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

=method create

    my $status = $self->create('abc123', {
        state      => 'success',
        target_url => 'https://ci.example.com/build/123',
        description => 'Build passed',
        context    => 'ci/jenkins',
    });

Create a commit status.

=cut

sub create {
    my ($self, $sha, $data) = @_;
    my $status = $self->{client}->post($self->_path_for(uri_escape($sha)), $data);
    return WWW::Forgejo::Entity::CommitStatus->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $status,
    );
}

=method get_latest

    my $latest = $self->get_latest('main');

Get latest status for a ref.

=cut

sub get_latest {
    my ($self, $ref) = @_;
    my $data = $self->{client}->get($self->_path_for("latest/$ref"));
    return $data;
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::Entity::CommitStatus>

=cut
