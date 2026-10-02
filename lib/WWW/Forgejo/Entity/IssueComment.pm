# ABSTRACT: Forgejo Issue Comment Entity
# PODNAME: WWW::Forgejo::Entity::IssueComment

use strict;
use warnings;

package WWW::Forgejo::Entity::IssueComment;

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
sub body        { shift->data->{body} }
sub user        { shift->data->{user} }
sub created_at  { shift->data->{created_at} }
sub updated_at  { shift->data->{updated_at} }

=method id

The C<id> field of the issue comment data.

=method body

The C<body> field of the issue comment data.

=method user

The C<user> field of the issue comment data.

=method created_at

The C<created_at> field of the issue comment data.

=method updated_at

The C<updated_at> field of the issue comment data.

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

    for my $comment ($repo->issues->list_comments(1)) {
        print $comment->body, "\n";
    }

=head1 DESCRIPTION

Wraps the decoded JSON object of an issue comment as returned by
L<WWW::Forgejo::API::Repo::Issues>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Issues>, L<WWW::Forgejo::Entity>

=cut
