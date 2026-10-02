# ABSTRACT: Forgejo Pull Request Review Entity
# PODNAME: WWW::Forgejo::Entity::PullRequestReview

use strict;
use warnings;

package WWW::Forgejo::Entity::PullRequestReview;

use Moo;
extends 'WWW::Forgejo::Entity';
use JSON::MaybeXS qw(encode_json);
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

sub id           { shift->data->{id} }
sub body         { shift->data->{body} }
sub state        { shift->data->{state} }
sub user         { shift->data->{user} }
sub submitted_at { shift->data->{submitted_at} }

=method id

The C<id> field of the pull request review data.

=method body

The C<body> field of the pull request review data.

=method state

The C<state> field of the pull request review data.

=method user

The C<user> field of the pull request review data.

=method submitted_at

The C<submitted_at> field of the pull request review data.

=cut

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

=method data_json

Returns L<data|WWW::Forgejo::Entity/data> encoded as a JSON string.

=cut

1;

__END__

=head1 SYNOPSIS

    for my $review ($repo->pulls->reviews(1)) {
        print $review->state, "\n";
    }

=head1 DESCRIPTION

Wraps the decoded JSON object of a pull request review as returned by
L<WWW::Forgejo::API::Repo::PullRequests>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::PullRequests>, L<WWW::Forgejo::Entity>

=cut
