# ABSTRACT: Forgejo Repo Flags API
# PODNAME: WWW::Forgejo::API::Repo::Flags

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Flags;

use Moo;
use URI::Escape qw(uri_escape);
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);
has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=attr owner

Owner (user or organization name) of the repository this controller works on.
Required.

=attr repo

Name of the repository this controller works on. Required.

=cut

# /repos/{owner}/{repo}/... of the repository this controller is bound to.
sub _repo_path {
    my ($self, @path) = @_;
    return join '/', '/repos', uri_escape($self->owner), uri_escape($self->repo), @path;
}

sub _path_for {
    my ($self, @path) = @_;
    return $self->_repo_path('flags', @path);
}

=method list

    my @flags = $repo->flags->list;

List the flags of the repository, as strings.

=cut

sub list {
    my ($self) = @_;
    my $data = $self->client->get($self->_path_for);
    return @$data;
}

=method add

    $repo->flags->add($flag);

Add a flag to the repository.

=cut

sub add {
    my ($self, $flag) = @_;
    $self->client->put($self->_path_for(uri_escape($flag)));
    return;
}

=method remove

    $repo->flags->remove($flag);

Remove a flag from the repository.

=cut

sub remove {
    my ($self, $flag) = @_;
    $self->client->delete($self->_path_for(uri_escape($flag)));
    return;
}

=method check

    my $bool = $repo->flags->check($flag);

Whether the repository has the given flag.

=cut

sub check {
    my ($self, $flag) = @_;
    return $self->client->check($self->_path_for(uri_escape($flag)));
}

=method replace

    $repo->flags->replace([ 'flag-one', 'flag-two' ]);

Replace all flags of the repository with the given list.

=cut

sub replace {
    my ($self, $flags) = @_;
    $self->client->put($self->_path_for, { flags => $flags });
    return;
}

=method remove_all

    $repo->flags->remove_all;

Remove all flags from the repository.

=cut

sub remove_all {
    my ($self) = @_;
    $self->client->delete($self->_path_for);
    return;
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @flags = $repo->flags->list;

    $repo->flags->add('flag-name');

    $repo->flags->remove('flag-name');

    if ($repo->flags->check('flag-name')) { ... }

    $repo->flags->replace([ 'flag-one', 'flag-two' ]);

    $repo->flags->remove_all;

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/flags> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/flags>, which binds it to
that repository; every method then addresses that repository.

L</list> returns the flags as plain strings and L</check> a boolean; the
other methods return nothing.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo>

=cut
