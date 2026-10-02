# ABSTRACT: Forgejo Release Entity
# PODNAME: WWW::Forgejo::Entity::Release

use strict;
use warnings;

package WWW::Forgejo::Entity::Release;

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

sub id { shift->data->{id} }
sub tag_name { shift->data->{tag_name} }
sub name { shift->data->{name} }
sub body { shift->data->{body} }
sub target_commitish { shift->data->{target_commitish} }

=method id

The C<id> field of the release data.

=method tag_name

The C<tag_name> field of the release data.

=method name

The C<name> field of the release data.

=method body

The C<body> field of the release data.

=method target_commitish

The C<target_commitish> field of the release data.

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

    my $release = $repo->releases->get_by_tag('v1.0.0');
    print $release->name, "\n";

=head1 DESCRIPTION

Wraps the decoded JSON object of a release as returned by
L<WWW::Forgejo::API::Repo::Releases>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Releases>, L<WWW::Forgejo::Entity>

=cut
