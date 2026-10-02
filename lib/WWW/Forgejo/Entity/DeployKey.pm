# ABSTRACT: Forgejo Deploy Key Entity
# PODNAME: WWW::Forgejo::Entity::DeployKey

use strict;
use warnings;

package WWW::Forgejo::Entity::DeployKey;

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
sub title { shift->data->{title} }
sub key { shift->data->{key} }
sub read_only { shift->data->{read_only} }

=method id

The C<id> field of the deploy key data.

=method title

The C<title> field of the deploy key data.

=method key

The C<key> field of the deploy key data.

=method read_only

The C<read_only> field of the deploy key data.

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

    my $key = $repo->keys->get(1);
    print $key->title, "\n";

=head1 DESCRIPTION

Wraps the decoded JSON object of a deploy key as returned by
L<WWW::Forgejo::API::Repo::Keys>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Keys>, L<WWW::Forgejo::Entity>

=cut
