# ABSTRACT: Forgejo Repo Entity
# PODNAME: WWW::Forgejo::Entity::Repo

use strict;
use warnings;

package WWW::Forgejo::Entity::Repo;

use Moo;
use Log::Any qw($log);
use JSON::MaybeXS qw(encode_json decode_json);

has client => (is => 'ro', required => 1);
has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has data   => (is => 'ro', required => 1);

# Sub-resource accessors - lazy loaded
has branches => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Branches;
        return WWW::Forgejo::API::Repo::Branches->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has branch_protections => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::BranchProtections;
        return WWW::Forgejo::API::Repo::BranchProtections->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has tags => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Tags;
        return WWW::Forgejo::API::Repo::Tags->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has tag_protections => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::TagProtections;
        return WWW::Forgejo::API::Repo::TagProtections->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has releases => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Releases;
        return WWW::Forgejo::API::Repo::Releases->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has issues => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Issues;
        return WWW::Forgejo::API::Repo::Issues->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has pulls => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::PullRequests;
        return WWW::Forgejo::API::Repo::PullRequests->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has hooks => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Hooks;
        return WWW::Forgejo::API::Repo::Hooks->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has collaborators => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Collaborators;
        return WWW::Forgejo::API::Repo::Collaborators->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has contents => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Contents;
        return WWW::Forgejo::API::Repo::Contents->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has git => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Git;
        return WWW::Forgejo::API::Repo::Git->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has wiki => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Wiki;
        return WWW::Forgejo::API::Repo::Wiki->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has actions => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Actions;
        return WWW::Forgejo::API::Repo::Actions->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has labels => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Labels;
        return WWW::Forgejo::API::Repo::Labels->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has milestones => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Milestones;
        return WWW::Forgejo::API::Repo::Milestones->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has topics => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Topics;
        return WWW::Forgejo::API::Repo::Topics->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has keys => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Keys;
        return WWW::Forgejo::API::Repo::Keys->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has forks => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Forks;
        return WWW::Forgejo::API::Repo::Forks->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has stargazers => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Stargazers;
        return WWW::Forgejo::API::Repo::Stargazers->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has subscribers => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Subscribers;
        return WWW::Forgejo::API::Repo::Subscribers->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has subscription => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Subscription;
        return WWW::Forgejo::API::Repo::Subscription->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has assignees => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Assignees;
        return WWW::Forgejo::API::Repo::Assignees->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has reviewers => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Reviewers;
        return WWW::Forgejo::API::Repo::Reviewers->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

has flags => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        require WWW::Forgejo::API::Repo::Flags;
        return WWW::Forgejo::API::Repo::Flags->new(
            client => $self->client,
            owner  => $self->owner,
            repo   => $self->repo,
        );
    },
);

=method update

    $self->update({ description => 'Updated description' });

Update repository settings.

=cut

sub update {
    my ($self, $data) = @_;
    my $result = $self->client->patch("/repos/${\$self->owner}/${\$self->repo}", $data);
    return $self->new(%$self, data => $result);
}

=method delete

    $self->delete;

Delete this repository.

=cut

sub delete {
    my ($self) = @_;
    $self->client->delete("/repos/${\$self->owner}/${\$self->repo}");
    return 1;
}

=method data

    my $json = $self->data;

Returns the repository data serialized as JSON.

=cut

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::API::Repos>

=cut