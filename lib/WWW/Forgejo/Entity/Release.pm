# ABSTRACT: Forgejo Release Entity
# PODNAME: WWW::Forgejo::Entity::Release

use strict;
use warnings;

package WWW::Forgejo::Entity::Release;

use Moo;
use JSON::MaybeXS qw(encode_json);

has client => (is => 'ro', required => 1);
has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has data   => (is => 'ro', required => 1);

sub id { shift->data->{id} }
sub tag_name { shift->data->{tag_name} }
sub name { shift->data->{name} }
sub body { shift->data->{body} }
sub target_commitish { shift->data->{target_commitish} }

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Releases>

=cut