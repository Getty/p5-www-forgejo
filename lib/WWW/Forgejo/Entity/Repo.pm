# ABSTRACT: Forgejo Repo Entity
# PODNAME: WWW::Forgejo::Entity::Repo

use strict;
use warnings;

package WWW::Forgejo::Entity::Repo;

use Moo;
extends 'WWW::Forgejo::Entity';
use JSON::MaybeXS qw(encode_json);
use URI::Escape qw(uri_escape);
use WWW::Forgejo::API::Repo::Branches;
use WWW::Forgejo::API::Repo::BranchProtections;
use WWW::Forgejo::API::Repo::Tags;
use WWW::Forgejo::API::Repo::TagProtections;
use WWW::Forgejo::API::Repo::Releases;
use WWW::Forgejo::API::Repo::Issues;
use WWW::Forgejo::API::Repo::PullRequests;
use WWW::Forgejo::API::Repo::Hooks;
use WWW::Forgejo::API::Repo::Collaborators;
use WWW::Forgejo::API::Repo::Contents;
use WWW::Forgejo::API::Repo::Git;
use WWW::Forgejo::API::Repo::Wiki;
use WWW::Forgejo::API::Repo::Actions;
use WWW::Forgejo::API::Repo::Labels;
use WWW::Forgejo::API::Repo::Milestones;
use WWW::Forgejo::API::Repo::Topics;
use WWW::Forgejo::API::Repo::Keys;
use WWW::Forgejo::API::Repo::Forks;
use WWW::Forgejo::API::Repo::Stargazers;
use WWW::Forgejo::API::Repo::Subscribers;
use WWW::Forgejo::API::Repo::Subscription;
use WWW::Forgejo::API::Repo::Assignees;
use WWW::Forgejo::API::Repo::Reviewers;
use WWW::Forgejo::API::Repo::Flags;
use WWW::Forgejo::API::Repo::Statuses;
use namespace::clean;

our $VERSION = '0.001';

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);

=attr owner

Owner (user or organization name) of the repository this object belongs to.
Required.

=attr repo

Name of the repository this object belongs to. Required.

=cut

# Sub-resource accessors and the controller class each one hands out.
my %CONTROLLER = (
    branches           => 'WWW::Forgejo::API::Repo::Branches',
    branch_protections => 'WWW::Forgejo::API::Repo::BranchProtections',
    tags               => 'WWW::Forgejo::API::Repo::Tags',
    tag_protections    => 'WWW::Forgejo::API::Repo::TagProtections',
    releases           => 'WWW::Forgejo::API::Repo::Releases',
    issues             => 'WWW::Forgejo::API::Repo::Issues',
    pulls              => 'WWW::Forgejo::API::Repo::PullRequests',
    hooks              => 'WWW::Forgejo::API::Repo::Hooks',
    collaborators      => 'WWW::Forgejo::API::Repo::Collaborators',
    contents           => 'WWW::Forgejo::API::Repo::Contents',
    git                => 'WWW::Forgejo::API::Repo::Git',
    wiki               => 'WWW::Forgejo::API::Repo::Wiki',
    actions            => 'WWW::Forgejo::API::Repo::Actions',
    labels             => 'WWW::Forgejo::API::Repo::Labels',
    milestones         => 'WWW::Forgejo::API::Repo::Milestones',
    topics             => 'WWW::Forgejo::API::Repo::Topics',
    keys               => 'WWW::Forgejo::API::Repo::Keys',
    forks              => 'WWW::Forgejo::API::Repo::Forks',
    stargazers         => 'WWW::Forgejo::API::Repo::Stargazers',
    subscribers        => 'WWW::Forgejo::API::Repo::Subscribers',
    subscription       => 'WWW::Forgejo::API::Repo::Subscription',
    assignees          => 'WWW::Forgejo::API::Repo::Assignees',
    reviewers          => 'WWW::Forgejo::API::Repo::Reviewers',
    flags              => 'WWW::Forgejo::API::Repo::Flags',
    statuses           => 'WWW::Forgejo::API::Repo::Statuses'
);

for my $name (sort keys %CONTROLLER) {
    has $name => (
        is       => 'lazy',
        init_arg => undef,
        builder  => sub { $_[0]->_controller($CONTROLLER{$name}) },
    );
}

sub _controller {
    my ($self, $class) = @_;
    return $class->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
    );
}

=attr branches

The L<WWW::Forgejo::API::Repo::Branches> controller for this repository. Built lazily.

=attr branch_protections

The L<WWW::Forgejo::API::Repo::BranchProtections> controller for this repository. Built lazily.

=attr tags

The L<WWW::Forgejo::API::Repo::Tags> controller for this repository. Built lazily.

=attr tag_protections

The L<WWW::Forgejo::API::Repo::TagProtections> controller for this repository. Built lazily.

=attr releases

The L<WWW::Forgejo::API::Repo::Releases> controller for this repository. Built lazily.

=attr issues

The L<WWW::Forgejo::API::Repo::Issues> controller for this repository. Built lazily.

=attr pulls

The L<WWW::Forgejo::API::Repo::PullRequests> controller for this repository. Built lazily.

=attr hooks

The L<WWW::Forgejo::API::Repo::Hooks> controller for this repository. Built lazily.

=attr collaborators

The L<WWW::Forgejo::API::Repo::Collaborators> controller for this repository. Built lazily.

=attr contents

The L<WWW::Forgejo::API::Repo::Contents> controller for this repository. Built lazily.

=attr git

The L<WWW::Forgejo::API::Repo::Git> controller for this repository. Built lazily.

=attr wiki

The L<WWW::Forgejo::API::Repo::Wiki> controller for this repository. Built lazily.

=attr actions

The L<WWW::Forgejo::API::Repo::Actions> controller for this repository. Built lazily.

=attr labels

The L<WWW::Forgejo::API::Repo::Labels> controller for this repository. Built lazily.

=attr milestones

The L<WWW::Forgejo::API::Repo::Milestones> controller for this repository. Built lazily.

=attr topics

The L<WWW::Forgejo::API::Repo::Topics> controller for this repository. Built lazily.

=attr keys

The L<WWW::Forgejo::API::Repo::Keys> controller for this repository. Built lazily.

=attr forks

The L<WWW::Forgejo::API::Repo::Forks> controller for this repository. Built lazily.

=attr stargazers

The L<WWW::Forgejo::API::Repo::Stargazers> controller for this repository. Built lazily.

=attr subscribers

The L<WWW::Forgejo::API::Repo::Subscribers> controller for this repository. Built lazily.

=attr subscription

The L<WWW::Forgejo::API::Repo::Subscription> controller for this repository. Built lazily.

=attr assignees

The L<WWW::Forgejo::API::Repo::Assignees> controller for this repository. Built lazily.

=attr reviewers

The L<WWW::Forgejo::API::Repo::Reviewers> controller for this repository. Built lazily.

=attr flags

The L<WWW::Forgejo::API::Repo::Flags> controller for this repository. Built lazily.

=attr statuses

The L<WWW::Forgejo::API::Repo::Statuses> controller for this repository. Built lazily.

=cut

sub _path {
    my ($self) = @_;
    return join '/', '/repos', uri_escape($self->owner), uri_escape($self->repo);
}

=method update

    my $updated = $repo->update({ description => 'Updated description' });

Update repository settings (C<PATCH /repos/{owner}/{repo}>). Returns a new
L<WWW::Forgejo::Entity::Repo> carrying the data from the response; the
object it was called on keeps its old data.

=cut

sub update {
    my ($self, $data) = @_;
    my $result = $self->client->patch($self->_path, $data);
    return (ref $self)->new(
        client => $self->client,
        owner  => $self->owner,
        repo   => $self->repo,
        data   => $result,
    );
}

=method delete

    $repo->delete;

Delete this repository. Returns true.

=cut

sub delete {
    my ($self) = @_;
    $self->client->delete($self->_path);
    return 1;
}

=method data_json

    my $json = $repo->data_json;

Returns the repository data (L<WWW::Forgejo::Entity/data>) encoded as a JSON string.

=cut

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);
    my $repo    = $forgejo->repos->get('owner', 'repo-name');

    print $repo->data->{full_name}, "\n";

    my @issues   = $repo->issues->list(state => 'open');
    my @branches = $repo->branches->list;
    my $release  = $repo->releases->get_by_tag('v1.0.0');

=head1 DESCRIPTION

A repository as returned by L<WWW::Forgejo::API::Repos>. Besides the decoded
repository data (L<data|WWW::Forgejo::Entity/data>) it is the entry point to
everything inside the repository: each of the controller attributes below
returns a C<WWW::Forgejo::API::Repo::*> object bound to this repository's
L</owner> and L</repo>.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Repos>, L<WWW::Forgejo::Entity>, L<WWW::Forgejo>

=cut
