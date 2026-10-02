# ABSTRACT: Forgejo Repos API
# PODNAME: WWW::Forgejo::API::Repos

use strict;
use warnings;

package WWW::Forgejo::API::Repos;

use Moo;
use Carp qw(croak);
use URI::Escape qw(uri_escape);
use WWW::Forgejo::Entity::Repo;
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

sub _repo_path {
    my ($self, $owner, $repo, @path) = @_;
    croak "Repository owner required" unless defined $owner && length $owner;
    croak "Repository name required"  unless defined $repo  && length $repo;
    return join '/', '/repos', uri_escape($owner), uri_escape($repo), @path;
}

# Wrap repository data as returned by the API; owner and name are taken from
# the data itself.
sub _repo {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::Repo->new(
        client => $self->client,
        owner  => $data->{owner}{login},
        repo   => $data->{name},
        data   => $data,
    );
}

=method search

    my $result = $forgejo->repos->search(q => 'forgejo', limit => 10);
    my $result = $forgejo->repos->search('forgejo');   # same as q => 'forgejo'

Search repositories (C<GET /repos/search>). Named arguments are sent as the
query string of the request; a single argument is shorthand for the search
term C<q>. Returns the decoded response as sent by the server, an object whose
C<data> member holds the repositories, not L<WWW::Forgejo::Entity::Repo>
objects.

=cut

sub search {
    my ($self, @args) = @_;
    my %params = @args % 2 ? (q => $args[0]) : @args;
    return $self->client->get('/repos/search', params => \%params);
}

=method get

    my $repo = $forgejo->repos->get('owner', 'repo-name');

Get a single repository as a L<WWW::Forgejo::Entity::Repo>, which also
gives access to the per-repository controllers (issues, pulls, branches, ...).

=cut

sub get {
    my ($self, $owner, $repo) = @_;
    my $data = $self->client->get($self->_repo_path($owner, $repo));
    return WWW::Forgejo::Entity::Repo->new(
        client => $self->client,
        owner  => $owner,
        repo   => $repo,
        data   => $data,
    );
}

=method create

    my $repo = $forgejo->repos->create(
        name        => 'new-repo',
        description => 'A new repository',
    );

Create a repository for the user the token belongs to (C<POST /user/repos>).
The key/value pairs are sent as the JSON body. Returns a
L<WWW::Forgejo::Entity::Repo>.

To create a repository for another user see
L<WWW::Forgejo::API::Admin::Users/create_repo_for>.

=cut

sub create {
    my ($self, %params) = @_;
    return $self->_repo($self->client->post('/user/repos', \%params));
}

=method create_for_org

    my $repo = $forgejo->repos->create_for_org('my-org',
        name        => 'new-repo',
        description => 'A new repository',
    );

Create a repository in an organization (C<POST /orgs/{org}/repos>). The
key/value pairs are sent as the JSON body. Returns a
L<WWW::Forgejo::Entity::Repo>.

=cut

sub create_for_org {
    my ($self, $org, %params) = @_;
    croak "Organization name required" unless $org;
    return $self->_repo($self->client->post("/orgs/" . uri_escape($org) . "/repos", \%params));
}

=method create_from_template

    my $repo = $forgejo->repos->create_from_template('template-owner', 'template-repo',
        owner => 'new-owner',
        name  => 'new-repo-from-template',
    );

Create a repository from a template repository
(C<POST /repos/{owner}/{repo}/generate>). The key/value pairs are sent as
the JSON body; the API requires C<owner> and C<name> of the new repository.
Returns a L<WWW::Forgejo::Entity::Repo>.

=cut

sub create_from_template {
    my ($self, $template_owner, $template_repo, %params) = @_;
    return $self->_repo($self->client->post($self->_repo_path($template_owner, $template_repo, 'generate'), \%params));
}

=method migrate

    my $repo = $forgejo->repos->migrate(
        clone_addr => 'https://example.com/example/repo.git',
        repo_name  => 'migrated-repo',
        repo_owner => 'myuser',
    );

Migrate a repository from another location (C<POST /repos/migrate>).
The key/value pairs are sent as the JSON body; the API requires C<clone_addr>
and C<repo_name>. Returns a L<WWW::Forgejo::Entity::Repo>.

=cut

sub migrate {
    my ($self, %params) = @_;
    return $self->_repo($self->client->post('/repos/migrate', \%params));
}

=method delete

    $forgejo->repos->delete('owner', 'repo-name');

Delete a repository. Returns true.

=cut

sub delete {
    my ($self, $owner, $repo) = @_;
    $self->client->delete($self->_repo_path($owner, $repo));
    return 1;
}

=method transfer

    my $repo = $forgejo->repos->transfer('owner', 'repo-name',
        new_owner => 'new-owner',
    );

Transfer a repository to another owner. The key/value pairs are sent as
the JSON body. Returns a L<WWW::Forgejo::Entity::Repo>.

=cut

sub transfer {
    my ($self, $owner, $repo, %params) = @_;
    return $self->_repo($self->client->post($self->_repo_path($owner, $repo, 'transfer'), \%params));
}

=method fork

    my $fork = $forgejo->repos->fork('owner', 'repo-name',
        organization => 'myorg',
    );

Fork a repository. The key/value pairs are sent as the JSON body. Returns
the fork as a L<WWW::Forgejo::Entity::Repo>.

=cut

sub fork {
    my ($self, $owner, $repo, %params) = @_;
    return $self->_repo($self->client->post($self->_repo_path($owner, $repo, 'forks'), \%params));
}

=method mirror_sync

    $forgejo->repos->mirror_sync('owner', 'repo-name');

Sync a pull mirror repository (C<POST /repos/{owner}/{repo}/mirror-sync>).

=cut

sub mirror_sync {
    my ($self, $owner, $repo) = @_;
    return $self->client->post($self->_repo_path($owner, $repo, 'mirror-sync'));
}

=method push_mirrors

    my $mirrors = $forgejo->repos->push_mirrors('owner', 'repo-name');

Get push mirrors for a repository. Further named arguments are sent as the
query string of the request.

=cut

sub push_mirrors {
    my ($self, $owner, $repo, %params) = @_;
    return $self->client->get($self->_repo_path($owner, $repo, 'push_mirrors'), params => \%params);
}

=method add_push_mirror

    my $mirror = $forgejo->repos->add_push_mirror('owner', 'repo-name',
        remote_address => 'https://example.com/example/repo.git',
        interval       => '8h0m0s',
    );

Add a push mirror to a repository. The key/value pairs are sent as the
JSON body. Returns the decoded response.

=cut

sub add_push_mirror {
    my ($self, $owner, $repo, %params) = @_;
    return $self->client->post($self->_repo_path($owner, $repo, 'push_mirrors'), \%params);
}

=method delete_push_mirror

    $forgejo->repos->delete_push_mirror('owner', 'repo-name', 'mirror-name');

Delete a push mirror from a repository. Returns true.

=cut

sub delete_push_mirror {
    my ($self, $owner, $repo, $name) = @_;
    $self->client->delete($self->_repo_path($owner, $repo, 'push_mirrors', uri_escape($name)));
    return 1;
}

=method list_for_org

    my $repos = $forgejo->repos->list_for_org('myorg');
    my $repos = $forgejo->repos->list_for_org('myorg', limit => 50);

List the repositories of an organization. Further named arguments are sent as
the query string of the request. Returns an arrayref of
L<WWW::Forgejo::Entity::Repo> objects. Croaks without an organization name.

=cut

sub list_for_org {
    my ($self, $org, %params) = @_;
    croak "Organization name required" unless $org;
    my $data = $self->client->get("/orgs/" . uri_escape($org) . "/repos", params => \%params);
    return [
        map {
            WWW::Forgejo::Entity::Repo->new(client => $self->client, owner => $org, repo => $_->{name}, data => $_)
        } @{$data}
    ];
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $repo   = $forgejo->repos->get('owner', 'repo-name');
    my $new    = $forgejo->repos->create(name => 'new-repo');
    my $result = $forgejo->repos->search(q => 'forgejo', limit => 10);
    my $repos  = $forgejo->repos->list_for_org('my-org');

=head1 DESCRIPTION

Repository-level endpoints: search, fetch, create, migrate, fork, transfer
and delete repositories, and manage mirrors. Available as
C<< $forgejo->repos >>.

Single repositories are returned as L<WWW::Forgejo::Entity::Repo> objects.
Such an object is also the entry point to everything inside a repository:
its accessors (C<issues>, C<pulls>, C<branches>, C<releases>, ...) return the
C<WWW::Forgejo::API::Repo::*> controllers bound to that repository.

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo>

=cut
