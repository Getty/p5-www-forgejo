# ABSTRACT: Forgejo Repo Branches API
# PODNAME: WWW::Forgejo::API::Repo::Branches

use strict;
use warnings;

package WWW::Forgejo::API::Repo::Branches;

use Moo;
use URI::Escape qw(uri_escape);
use WWW::Forgejo::Entity::Branch;
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
    return $self->_repo_path('branches', @path);
}

sub _branch {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::Branch->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $data,
    );
}

=method list

    my @branches = $repo->branches->list;
    my @branches = $repo->branches->list(page => 2, limit => 50);

List all branches as L<WWW::Forgejo::Entity::Branch> objects. Named arguments
are sent as the query string.

=cut

sub list {
    my ($self, %params) = @_;
    my $data = $self->client->get($self->_path_for, params => \%params);
    return map { $self->_branch($_) } @$data;
}

=method get

    my $branch = $repo->branches->get($branch_name);

Get a specific branch as a L<WWW::Forgejo::Entity::Branch>.

=cut

sub get {
    my ($self, $branch) = @_;
    return $self->_branch($self->client->get($self->_path_for(uri_escape($branch))));
}

=method create

    my $branch = $repo->branches->create({
        new_branch_name => 'new-branch',
        old_ref_name    => 'main',
    });

Create a new branch; the API requires C<new_branch_name>. Returns the
L<WWW::Forgejo::Entity::Branch>.

=cut

sub create {
    my ($self, $data) = @_;
    return $self->_branch($self->client->post($self->_path_for, $data));
}

=method delete

    $repo->branches->delete($branch_name);

Delete a branch.

Branch protection rules are managed through
L<WWW::Forgejo::API::Repo::BranchProtections>; the branches endpoints
themselves have no operations for them.

=cut

sub delete {
    my ($self, $branch) = @_;
    return $self->client->delete($self->_path_for(uri_escape($branch)));
}

=method rename

    $repo->branches->rename($branch_name, $new_name);

Rename a branch (C<PATCH /repos/{owner}/{repo}/branches/{branch}>). Returns
true.

=cut

sub rename {
    my ($self, $branch, $new_name) = @_;
    $self->client->patch($self->_path_for(uri_escape($branch)), { name => $new_name });
    return 1;
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    my @branches = $repo->branches->list;

    my $branch = $repo->branches->get('main');

    my $new = $repo->branches->create({
        new_branch_name => 'new-branch',
        old_ref_name    => 'main',
    });

    $repo->branches->rename('new-branch', 'feature');
    $repo->branches->delete('feature');

=head1 DESCRIPTION

Controller for the C</repos/{owner}/{repo}/branches> endpoints of one repository.
It is obtained through L<WWW::Forgejo::Entity::Repo/branches>, which binds it to
that repository; every method then addresses that repository.

Depending on the method, results are L<WWW::Forgejo::Entity::Branch>
objects or the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::Branch>, L<WWW::Forgejo>

=cut
