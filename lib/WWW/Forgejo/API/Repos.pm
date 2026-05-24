# ABSTRACT: Forgejo Repos API
# PODNAME: WWW::Forgejo::API::Repos

use strict;
use warnings;

package WWW::Forgejo::API::Repos;

use Moo;
use Log::Any qw($log);
use Carp qw(croak);
use WWW::Forgejo::Entity::Repo;

has client => (
    is       => 'ro',
    init_arg => 'client',
);

=method search

    my @repos = $self->search({
        owner => 'myorg',
        limit => 10,
    });

Search repositories.

=cut

sub search {
    my ($self, @args) = @_;
    my %params = @args % 2 ? (query => $args[0]) : @args;
    return $self->{client}->get('/repos/search', params => \%params);
}

=method get

    my $repo = $self->get('owner', 'repo-name');

Get a single repository.

=cut

sub get {
    my ($self, $owner, $repo) = @_;
    my $data = $self->{client}->get("/repos/$owner/$repo");
    return WWW::Forgejo::Entity::Repo->new(
        client => $self->{client},
        owner  => $owner,
        repo   => $repo,
        data   => $data,
    );
}

=method create_for_user

    my $repo = $self->create_for_user('username', {
        name        => 'new-repo',
        description => 'A new repository',
        private     => 0,
    });

Create a repository for a user.

=cut

sub create_for_user {
    my ($self, $user, %params) = @_;
    my $result = $self->{client}->post("/user/repos", \%params);
    return WWW::Forgejo::Entity::Repo->new(
        client => $self->{client},
        owner  => $result->{owner}->{login},
        repo   => $result->{name},
        data   => $result,
    );
}

=method create_from_template

    my $repo = $self->create_from_template('template-owner', 'template-repo', {
        name => 'new-repo-from-template',
    });

Create a repository from a template.

=cut

sub create_from_template {
    my ($self, $template_owner, $template_repo, %params) = @_;
    my $result = $self->{client}->post("/repos/$template_owner/$template_repo/generate", \%params);
    return WWW::Forgejo::Entity::Repo->new(
        client => $self->{client},
        owner  => $result->{owner}->{login},
        repo   => $result->{name},
        data   => $result,
    );
}

=method migrate

    my $repo = $self->migrate({
        clone_addr    => 'https://github.com/example/repo.git',
        repo_name     => 'migrated-repo',
        repo_owner    => 'myuser',
    });

Migrate a repository from another platform.

=cut

sub migrate {
    my ($self, %params) = @_;
    my $result = $self->{client}->post('/repos/migrations', \%params);
    return WWW::Forgejo::Entity::Repo->new(
        client => $self->{client},
        owner  => $result->{owner}->{login},
        repo   => $result->{name},
        data   => $result,
    );
}

=method delete

    $self->delete('owner', 'repo-name');

Delete a repository.

=cut

sub delete {
    my ($self, $owner, $repo) = @_;
    $self->{client}->delete("/repos/$owner/$repo");
    return 1;
}

=method transfer

    my $repo = $self->transfer('owner', 'repo-name', {
        new_owner => 'new-owner',
    });

Transfer a repository to another owner.

=cut

sub transfer {
    my ($self, $owner, $repo, %params) = @_;
    my $result = $self->{client}->post("/repos/$owner/$repo/transfer", \%params);
    return WWW::Forgejo::Entity::Repo->new(
        client => $self->{client},
        owner  => $result->{owner}->{login},
        repo   => $result->{name},
        data   => $result,
    );
}

=method fork

    my $fork = $self->fork('owner', 'repo-name', {
        organization => 'myorg',
    });

Fork a repository.

=cut

sub fork {
    my ($self, $owner, $repo, %params) = @_;
    my $result = $self->{client}->post("/repos/$owner/$repo/forks", \%params);
    return WWW::Forgejo::Entity::Repo->new(
        client => $self->{client},
        owner  => $result->{owner}->{login},
        repo   => $result->{name},
        data   => $result,
    );
}

=method generate

    my $content = $self->generate('owner', 'repo-name', {
        filename    => 'README.md',
        content     => 'base64_encoded_content',
    });

Generate repository content.

=cut

sub generate {
    my ($self, $owner, $repo, %params) = @_;
    return $self->{client}->post("/repos/$owner/$repo/generate", \%params);
}

=method mirror_sync

    my $result = $self->mirror_sync('owner', 'repo-name');

Sync a mirror repository.

=cut

sub mirror_sync {
    my ($self, $owner, $repo) = @_;
    return $self->{client}->post("/repos/$owner/$repo/mirror_sync");
}

=method push_mirrors

    my $mirrors = $self->push_mirrors('owner', 'repo-name');

Get push mirrors for a repository.

=cut

sub push_mirrors {
    my ($self, $owner, $repo) = @_;
    return $self->{client}->get("/repos/$owner/$repo/push_mirrors");
}

=method add_push_mirror

    my $mirror = $self->add_push_mirror('owner', 'repo-name', {
        remote_url => 'https://github.com/example/repo.git',
        name       => 'backup',
    });

Add a push mirror to a repository.

=cut

sub add_push_mirror {
    my ($self, $owner, $repo, %params) = @_;
    return $self->{client}->post("/repos/$owner/$repo/push_mirrors", \%params);
}

=method delete_push_mirror

    $self->delete_push_mirror('owner', 'repo-name', 'mirror-name');

Delete a push mirror from a repository.

=cut

sub delete_push_mirror {
    my ($self, $owner, $repo, $name) = @_;
    $self->{client}->delete("/repos/$owner/$repo/push_mirrors/$name");
    return 1;
}

=method list_for_org

    my @repos = $self->list_for_org('myorg');

List repositories for an organization.

=cut

sub list_for_org {
    my ($self, $org, %params) = @_;
    croak "Organization name required" unless $org;
    my $data = $self->{client}->get("/orgs/$org/repos", %params);
    return [ map { WWW::Forgejo::Entity::Repo->new(client => $self->{client}, owner => $org, repo => $_->{name}, data => $_) } @{$data} ];
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::Entity::Repo>

=cut