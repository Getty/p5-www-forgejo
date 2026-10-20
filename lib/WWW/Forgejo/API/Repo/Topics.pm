# ABSTRACT: Forgejo Repo Topics API
# PODNAME: WWW::Forgejo::API::Repo::Topics

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Topics;

use Moo;
use WWW::Forgejo::URL qw( escape_component );
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
    return join '/', '/repos', escape_component($self->owner), escape_component($self->repo), @path;
}

sub _path_for {
    my ($self, @path) = @_;
    return $self->_repo_path('topics', @path);
}

=method list

    my $topics = $repo->topics->list;

List the topics of the repository. Returns an arrayref of topic names. Named
arguments are sent as the query string.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return $data->{topics} // [];
}

=method add

    $repo->topics->add($topic);

Add one topic to the repository, keeping the others.

=cut

sub add {
    my ($self, $topic) = @_;
    $self->client->put($self->_path_for(escape_component($topic)));
    return;
}

=method replace

    $repo->topics->replace(topics => ['perl', 'cpan']);

Replace the whole list of topics of the repository with the given one. The
named arguments are sent as the JSON body.

=cut

sub replace {
    my ($self, %params) = @_;
    $self->client->put($self->_path_for, \%params);
    return;
}

=method remove

    $repo->topics->remove($topic);

Remove one topic from the repository.

=cut

sub remove {
    my ($self, $topic) = @_;
    $self->client->delete($self->_path_for(escape_component($topic)));
    return;
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my $topics = $repo->topics->list;

    $repo->topics->add('perl');

    $repo->topics->replace(topics => ['perl', 'cpan']);

    $repo->topics->remove('old-topic');

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/topics> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/topics>, which binds it to
that repository; every method then addresses that repository.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo>

=cut
