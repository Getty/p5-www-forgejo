# ABSTRACT: Forgejo Release Asset Entity
# PODNAME: WWW::Forgejo::Entity::ReleaseAsset

use strict;
use warnings;

package WWW::Forgejo::Entity::ReleaseAsset;

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

sub id         { shift->data->{id} }
sub name       { shift->data->{name} }
sub size       { shift->data->{size} }
sub downloads   { shift->data->{download_count} }
sub type { shift->data->{type} }
sub created_at  { shift->data->{created_at} }
sub browser_download_url { shift->data->{browser_download_url} }

=method id

The C<id> field of the release asset data.

=method name

The C<name> field of the release asset data.

=method size

The C<size> field of the release asset data.

=method downloads

The C<download_count> field of the release asset data.

=method type

The C<type> field of the release asset data.

=method created_at

The C<created_at> field of the release asset data.

=method browser_download_url

The C<browser_download_url> field of the release asset data.

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

    my $release = $repo->releases->latest;
    for my $asset ($repo->releases->assets($release->id)) {
        print $asset->name, ' ', $asset->browser_download_url, "\n";
    }

=head1 DESCRIPTION

Wraps the decoded JSON object of a release asset as returned by
L<WWW::Forgejo::API::Repo::Releases>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Releases>, L<WWW::Forgejo::Entity>

=cut
