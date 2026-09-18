# ABSTRACT: Forgejo Repo Hooks API
# PODNAME: WWW::Forgejo::API::Repo::Hooks

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Hooks;

use Moo;
use Log::Any qw($log);
use URI::Escape;
use WWW::Forgejo::Entity::Hook;

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has client => (is => 'ro', init_arg => 'client');

sub _path_for {
    my ($self, @path) = @_;
    return "/repos/${\uri_escape($self->owner)}/${\uri_escape($self->repo)}/hooks/" . join('/', @path);
}

=method list

    my @hooks = $self->list;

List all hooks.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->{client}->get($self->_path_for, %params);
    return map {
        WWW::Forgejo::Entity::Hook->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
            data   => $_,
        )
    } @$data;
}

=method get

    my $hook = $self->get(1);

Get a hook by ID.

=cut

sub get {
    my ($self, $id) = @_;
    my $data = $self->{client}->get($self->_path_for(uri_escape($id)));
    return WWW::Forgejo::Entity::Hook->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method create

    my $hook = $self->create({
        type         => 'web',
        config       => { url => 'https://example.com/hook' },
        events       => ['push', 'pull_request'],
        active       => 1,
    });

Create a hook.

=cut

sub create {
    my ($self, $data) = @_;
    my $path = $self->_path_for;
    my $result = $self->{client}->post($path, $data);
    return WWW::Forgejo::Entity::Hook->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $result,
    );
}

=method update

    my $hook = $self->update(1, { active => 0 });

Update a hook.

=cut

sub update {
    my ($self, $id, $data) = @_;
    my $path = $self->_path_for(uri_escape($id));
    my $result = $self->{client}->patch($path, $data);
    return WWW::Forgejo::Entity::Hook->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $result,
    );
}

=method edit

    my $hook = $self->edit(1, { active => 0 });

Update a hook (alias for update).

=cut

sub edit {
    my ($self, $id, $data) = @_;
    return $self->update($id, $data);
}

=method delete

    $self->delete(1);

Delete a hook.

=cut

sub delete {
    my ($self, $id) = @_;
    my $path = $self->_path_for(uri_escape($id));
    return $self->{client}->delete($path);
}

=method test

    $self->test(1);

Test a hook.

=cut

sub test {
    my ($self, $id) = @_;
    my $path = $self->_path_for(uri_escape($id), 'tests');
    return $self->{client}->post($path, {});
}

=method ping

    $self->ping(1);

Ping a hook.

=cut

sub ping {
    my ($self, $id) = @_;
    my $path = $self->_path_for(uri_escape($id), 'tests');
    return $self->{client}->post($path, {});
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Hook>

=cut