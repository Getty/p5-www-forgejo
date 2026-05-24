# ABSTRACT: Forgejo Release Asset Entity
# PODNAME: WWW::Forgejo::Entity::ReleaseAsset

use strict;
use warnings;

package WWW::Forgejo::Entity::ReleaseAsset;

use Moo;
use JSON::MaybeXS qw(encode_json);

has client => (is => 'ro', required => 1);
has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has data   => (is => 'ro', required => 1);

sub id         { shift->data->{id} }
sub name       { shift->data->{name} }
sub size       { shift->data->{size} }
sub downloads   { shift->data->{download_count} }
sub content_type { shift->data->{content_type} }
sub created_at  { shift->data->{created_at} }
sub browser_download_url { shift->data->{browser_download_url} }

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Releases>

=cut