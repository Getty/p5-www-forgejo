# ABSTRACT: Forgejo Milestone Entity
# PODNAME: WWW::Forgejo::Entity::Milestone

use strict;
use warnings;

package WWW::Forgejo::Entity::Milestone;

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

sub id          { shift->data->{id} }
sub title       { shift->data->{title} }
sub description { shift->data->{description} }
sub state       { shift->data->{state} }
sub due_on    { shift->data->{due_on} }
sub closed_at   { shift->data->{closed_at} }
sub created_at  { shift->data->{created_at} }
sub updated_at  { shift->data->{updated_at} }

=method id

The C<id> field of the milestone data.

=method title

The C<title> field of the milestone data.

=method description

The C<description> field of the milestone data.

=method state

The C<state> field of the milestone data.

=method due_on

The C<due_on> field of the milestone data.

=method closed_at

The C<closed_at> field of the milestone data.

=method created_at

The C<created_at> field of the milestone data.

=method updated_at

The C<updated_at> field of the milestone data.

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

    my $milestone = $repo->milestones->get(1);
    print $milestone->title, "\n";

=head1 DESCRIPTION

Wraps the decoded JSON object of a milestone as returned by
L<WWW::Forgejo::API::Repo::Milestones>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Milestones>, L<WWW::Forgejo::Entity>

=cut
