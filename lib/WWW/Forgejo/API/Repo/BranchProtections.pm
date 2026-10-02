# ABSTRACT: Forgejo Repo Branch Protections API
# PODNAME: WWW::Forgejo::API::Repo::BranchProtections

use strict;
use warnings;

package WWW::Forgejo::API::Repo::BranchProtections;

use Moo;
use URI::Escape qw(uri_escape);
use WWW::Forgejo::Entity::BranchProtection;
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
    return $self->_repo_path('branch_protections', @path);
}

sub _protection {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::BranchProtection->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method list

    my @protections = $repo->branch_protections->list;

List all branch protections as L<WWW::Forgejo::Entity::BranchProtection>
objects. Named arguments are sent as the query string.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return map { $self->_protection($_) } @$data;
}

=method get

    my $protection = $repo->branch_protections->get($name);

Get a specific branch protection by its name.

=cut

sub get {
    my ($self, $name) = @_;
    return $self->_protection($self->client->get($self->_path_for(uri_escape($name))));
}

=method create

    my $protection = $repo->branch_protections->create({
        rule_name          => 'main',
        required_approvals => 1,
    });

Create a new branch protection rule.

=cut

sub create {
    my ($self, $data) = @_;
    return $self->_protection($self->client->post($self->_path_for, $data));
}

=method update

    my $protection = $repo->branch_protections->update($name, { required_approvals => 2 });

Update a branch protection rule.

=cut

sub update {
    my ($self, $name, $data) = @_;
    return $self->_protection($self->client->patch($self->_path_for(uri_escape($name)), $data));
}

=method edit

Alias for L</update>.

=cut

sub edit { shift->update(@_) }

=method delete

    $repo->branch_protections->delete($name);

Delete a branch protection rule.

=cut

sub delete {
    my ($self, $name) = @_;
    return $self->client->delete($self->_path_for(uri_escape($name)));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @protections = $repo->branch_protections->list;

    my $protection = $repo->branch_protections->get('main');

    $protection = $repo->branch_protections->create({
        rule_name          => 'main',
        required_approvals => 1,
    });

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/branch_protections> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/branch_protections>, which binds it to
that repository; every method then addresses that repository.

Depending on the method, results are L<WWW::Forgejo::Entity::BranchProtection>
objects or the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::BranchProtection>, L<WWW::Forgejo>

=cut
