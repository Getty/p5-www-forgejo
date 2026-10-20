# ABSTRACT: Forgejo Repos API
# PODNAME: WWW::Forgejo::API::Repos

use strict;
use warnings;

package WWW::Forgejo::API::Repos;

use Moo;
use Carp qw(croak);
use WWW::Forgejo::URL qw( escape_component );
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
    return join '/', '/repos', escape_component($owner), escape_component($repo), @path;
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

=method search_issues

    my $result = $forgejo->repos->search_issues(q => 'forgejo', limit => 10);
    my $result = $forgejo->repos->search_issues('forgejo');   # same as q => 'forgejo'

Search issues in all repositories of the instance (C<GET /repos/issues/search>).
Named arguments are sent as the query string of the request; a single argument
is shorthand for the search term C<q>. Returns the decoded response as sent by
the server, an object whose C<data> member holds the issues, not
L<WWW::Forgejo::Entity::Issue> objects.

=cut

sub search_issues {
    my ($self, @args) = @_;
    my %params = @args % 2 ? (q => $args[0]) : @args;
    return $self->client->get('/repos/issues/search', params => \%params);
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

=method get_by_id

    my $repo = $forgejo->repos->get_by_id(42);

Get a single repository by its ID (C<GET /repositories/{id}>). Returns a
L<WWW::Forgejo::Entity::Repo>, which also gives access to the per-repository
controllers (issues, pulls, branches, ...).

=cut

sub get_by_id {
    my ($self, $id) = @_;
    croak "Repository ID required" unless defined $id && length $id;
    my $data = $self->client->get('/repositories/' . escape_component($id));
    return $self->_repo($data);
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
    return $self->_repo($self->client->post("/orgs/" . escape_component($org) . "/repos", \%params));
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
    $self->client->delete($self->_repo_path($owner, $repo, 'push_mirrors', escape_component($name)));
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
    my $data = $self->client->get("/orgs/" . escape_component($org) . "/repos", params => \%params);
    return [
        map {
            WWW::Forgejo::Entity::Repo->new(client => $self->client, owner => $org, repo => $_->{name}, data => $_)
        } @{$data}
    ];
}

=method edit

    my $repo = $forgejo->repos->edit('owner', 'repo-name',
        description => 'A new description',
    );

Edit a repository (C<PATCH /repos/{owner}/{repo}>). The key/value pairs are
sent as the JSON body. Returns the repository as a
L<WWW::Forgejo::Entity::Repo>.

=cut

sub edit {
    my ($self, $owner, $repo, %params) = @_;
    return $self->_repo($self->client->patch($self->_repo_path($owner, $repo), \%params));
}

=method set_avatar

    $forgejo->repos->set_avatar('owner', 'repo-name', image => $base64);

Set the avatar of a repository (C<POST /repos/{owner}/{repo}/avatar>). The
named arguments are sent as the JSON body; the API expects the image in
C<image>, as a base64 encoded string. Returns true.

=cut

sub set_avatar {
    my ($self, $owner, $repo, %params) = @_;
    croak "Avatar image required" unless defined $params{image} && length $params{image};
    $self->client->post($self->_repo_path($owner, $repo, 'avatar'), \%params);
    return 1;
}

=method delete_avatar

    $forgejo->repos->delete_avatar('owner', 'repo-name');

Delete the avatar of a repository (C<DELETE /repos/{owner}/{repo}/avatar>); the
repository gets the default avatar. Returns true.

=cut

sub delete_avatar {
    my ($self, $owner, $repo) = @_;
    $self->client->delete($self->_repo_path($owner, $repo, 'avatar'));
    return 1;
}

=method activities

    my $activities = $forgejo->repos->activities('owner', 'repo-name');

Get the activity feed of a repository
(C<GET /repos/{owner}/{repo}/activities/feeds>). Further named arguments are
sent as the query string of the request (C<date>, C<page>, C<limit>).

=cut

sub activities {
    my ($self, $owner, $repo, %params) = @_;
    return $self->client->get($self->_repo_path($owner, $repo, 'activities', 'feeds'), params => \%params);
}

=method times

    my $times = $forgejo->repos->times('owner', 'repo-name');

Get the times of the contributors of a repository
(C<GET /repos/{owner}/{repo}/times>). Named arguments are sent as the query
string of the request (C<user>, C<since>, C<before>, C<page>, C<limit>). The
times are returned as plain structures in an arrayref.

=cut

sub times {
    my ($self, $owner, $repo, %params) = @_;
    my $data = $self->client->get($self->_repo_path($owner, $repo, 'times'), params => \%params);
    return [@$data];
}

=method times_by_user

    my $times = $forgejo->repos->times_by_user('owner', 'repo-name', 'user');

Get the times of one contributor of a repository
(C<GET /repos/{owner}/{repo}/times/{user}>). The times are returned as plain
structures in an arrayref.

=cut

sub times_by_user {
    my ($self, $owner, $repo, $user) = @_;
    croak "User name required" unless defined $user && length $user;
    my $data = $self->client->get(
        $self->_repo_path($owner, $repo, 'times', escape_component($user)));
    return [@$data];
}

=method commits

    my $commits = $forgejo->repos->commits('owner', 'repo-name');
    my $commits = $forgejo->repos->commits('owner', 'repo-name', sha => 'main');

List the commits of a repository (C<GET /repos/{owner}/{repo}/commits>). Named
arguments are sent as the query string of the request (C<sha>, C<path>,
C<stat>, C<verification>, C<files>, C<page>, C<limit>, C<not>).

=cut

sub commits {
    my ($self, $owner, $repo, %params) = @_;
    return $self->client->get($self->_repo_path($owner, $repo, 'commits'), params => \%params);
}

=method commit_pull

    my $pull = $forgejo->repos->commit_pull('owner', 'repo-name', $sha);

Get the pull request a commit belongs to
(C<GET /repos/{owner}/{repo}/commits/{sha}/pull>). The commit is addressed by
its SHA.

=cut

sub commit_pull {
    my ($self, $owner, $repo, $sha) = @_;
    return $self->client->get($self->_repo_path($owner, $repo, 'commits', escape_component($sha), 'pull'));
}

=method commit_statuses

    my $statuses = $forgejo->repos->commit_statuses('owner', 'repo-name', $ref);

List the statuses of a commit
(C<GET /repos/{owner}/{repo}/commits/{ref}/statuses>). The commit is addressed
by its SHA or by a reference. Further named arguments are sent as the query
string of the request (C<sort>, C<state>, C<page>, C<limit>).

=cut

sub commit_statuses {
    my ($self, $owner, $repo, $ref, %params) = @_;
    return $self->client->get(
        $self->_repo_path($owner, $repo, 'commits', escape_component($ref), 'statuses'),
        params => \%params);
}

=method compare

    my $comparison = $forgejo->repos->compare('owner', 'repo-name', 'main...feature');

Compare two references of a repository
(C<GET /repos/{owner}/{repo}/compare/{basehead}>). The two references are given
as one argument, separated by three dots.

=cut

sub compare {
    my ($self, $owner, $repo, $basehead) = @_;
    return $self->client->get($self->_repo_path($owner, $repo, 'compare', escape_component($basehead)));
}

=method editorconfig

    my $config = $forgejo->repos->editorconfig('owner', 'repo-name', 'src/main.pl');

Get the editor configuration of a file of the repository
(C<GET /repos/{owner}/{repo}/editorconfig/{filepath}>). The file is named by
its path in the repository; every part of the path is escaped on its own, the
slashes between them stay. Further named arguments are sent as the query
string of the request (C<ref>).

=cut

sub editorconfig {
    my ($self, $owner, $repo, $filepath, %params) = @_;
    my @parts = map { escape_component($_) } split m{/}, $filepath;
    return $self->client->get(
        $self->_repo_path($owner, $repo, 'editorconfig', @parts),
        params => \%params);
}

=method issue_config

    my $config = $forgejo->repos->issue_config('owner', 'repo-name');

Get the issue configuration of the repository
(C<GET /repos/{owner}/{repo}/issue_config>).

=cut

sub issue_config {
    my ($self, $owner, $repo) = @_;
    return $self->client->get($self->_repo_path($owner, $repo, 'issue_config'));
}

=method validate_issue_config

    my $config = $forgejo->repos->validate_issue_config('owner', 'repo-name');

Validate the issue configuration of the repository
(C<GET /repos/{owner}/{repo}/issue_config/validate>).

=cut

sub validate_issue_config {
    my ($self, $owner, $repo) = @_;
    return $self->client->get($self->_repo_path($owner, $repo, 'issue_config', 'validate'));
}

=method issue_templates

    my $templates = $forgejo->repos->issue_templates('owner', 'repo-name');

List the issue templates of the repository
(C<GET /repos/{owner}/{repo}/issue_templates>).

=cut

sub issue_templates {
    my ($self, $owner, $repo) = @_;
    return $self->client->get($self->_repo_path($owner, $repo, 'issue_templates'));
}

=method languages

    my $languages = $forgejo->repos->languages('owner', 'repo-name');

Get the languages of the repository
(C<GET /repos/{owner}/{repo}/languages>).

=cut

sub languages {
    my ($self, $owner, $repo) = @_;
    return $self->client->get($self->_repo_path($owner, $repo, 'languages'));
}

=method new_pin_allowed

    my $allowed = $forgejo->repos->new_pin_allowed('owner', 'repo-name');

Tell whether the user of the token may pin a new issue of the repository
(C<GET /repos/{owner}/{repo}/new_pin_allowed>).

=cut

sub new_pin_allowed {
    my ($self, $owner, $repo) = @_;
    return $self->client->get($self->_repo_path($owner, $repo, 'new_pin_allowed'));
}

=method push_mirror

    my $mirror = $forgejo->repos->push_mirror('owner', 'repo-name', 'mirror-name');

Get one push mirror of a repository
(C<GET /repos/{owner}/{repo}/push_mirrors/{name}>).

=cut

sub push_mirror {
    my ($self, $owner, $repo, $name) = @_;
    return $self->client->get($self->_repo_path($owner, $repo, 'push_mirrors', escape_component($name)));
}

=method signing_key

    my $key = $forgejo->repos->signing_key('owner', 'repo-name');

Get the signing key of the repository
(C<GET /repos/{owner}/{repo}/signing-key.gpg>). The key is armored; it is
returned as the body of the response, as bytes.

=cut

sub signing_key {
    my ($self, $owner, $repo) = @_;
    return $self->client->get($self->_repo_path($owner, $repo, 'signing-key.gpg'), raw => 1);
}

=method sync_fork

    my $state = $forgejo->repos->sync_fork('owner', 'repo-name');

Get the state of the synchronisation of the fork
(C<GET /repos/{owner}/{repo}/sync_fork>).

=cut

sub sync_fork {
    my ($self, $owner, $repo) = @_;
    return $self->client->get($self->_repo_path($owner, $repo, 'sync_fork'));
}

=method sync_fork_branch

    my $state = $forgejo->repos->sync_fork_branch('owner', 'repo-name', 'main');

Get the state of the synchronisation of the fork of a branch
(C<GET /repos/{owner}/{repo}/sync_fork/{branch}>).

=cut

sub sync_fork_branch {
    my ($self, $owner, $repo, $branch) = @_;
    return $self->client->get($self->_repo_path($owner, $repo, 'sync_fork', escape_component($branch)));
}

=method convert

    my $task = $forgejo->repos->convert('owner', 'repo-name');

Convert the repository to another type
(C<POST /repos/{owner}/{repo}/convert>). The key/value pairs are sent as the
JSON body; the API takes C<type> and C<new_owner>.

=cut

sub convert {
    my ($self, $owner, $repo, %params) = @_;
    return $self->client->post($self->_repo_path($owner, $repo, 'convert'), \%params);
}

=method diffpatch

    my $files = $forgejo->repos->diffpatch('owner', 'repo-name',
        content   => $diff,
        message   => 'Apply the patch',
        branch    => 'main',
    );

Apply a diffpatch to the repository
(C<POST /repos/{owner}/{repo}/diffpatch>). The named arguments are sent as the
JSON body; the API takes C<content> (the patch), C<message>, C<branch> and
C<sha> of the commit the patch applies to.

=cut

sub diffpatch {
    my ($self, $owner, $repo, %params) = @_;
    return $self->client->post($self->_repo_path($owner, $repo, 'diffpatch'), \%params);
}

=method push_mirrors_sync

    $forgejo->repos->push_mirrors_sync('owner', 'repo-name');

Start the synchronisation of the push mirrors of a repository
(C<POST /repos/{owner}/{repo}/push_mirrors-sync>).

=cut

sub push_mirrors_sync {
    my ($self, $owner, $repo) = @_;
    return $self->client->post($self->_repo_path($owner, $repo, 'push_mirrors-sync'));
}

=method start_sync_fork

    $forgejo->repos->start_sync_fork('owner', 'repo-name');

Start the synchronisation of the fork of a repository
(C<POST /repos/{owner}/{repo}/sync_fork>).

=cut

sub start_sync_fork {
    my ($self, $owner, $repo) = @_;
    return $self->client->post($self->_repo_path($owner, $repo, 'sync_fork'));
}

=method start_sync_fork_branch

    $forgejo->repos->start_sync_fork_branch('owner', 'repo-name', 'main');

Start the synchronisation of the fork of a branch of a repository
(C<POST /repos/{owner}/{repo}/sync_fork/{branch}>).

=cut

sub start_sync_fork_branch {
    my ($self, $owner, $repo, $branch) = @_;
    return $self->client->post($self->_repo_path($owner, $repo, 'sync_fork', escape_component($branch)));
}

=method accept_transfer

    $forgejo->repos->accept_transfer('owner', 'repo-name');

Accept the transfer of a repository to another owner
(C<POST /repos/{owner}/{repo}/transfer/accept>). Only the new owner of the
repository may do this.

=cut

sub accept_transfer {
    my ($self, $owner, $repo) = @_;
    return $self->client->post($self->_repo_path($owner, $repo, 'transfer', 'accept'));
}

=method reject_transfer

    $forgejo->repos->reject_transfer('owner', 'repo-name');

Reject the transfer of a repository to another owner
(C<POST /repos/{owner}/{repo}/transfer/reject>). Only the new owner of the
repository may do this.

=cut

sub reject_transfer {
    my ($self, $owner, $repo) = @_;
    return $self->client->post($self->_repo_path($owner, $repo, 'transfer', 'reject'));
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
