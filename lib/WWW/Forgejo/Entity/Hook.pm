# ABSTRACT: Forgejo Hook Entity
# PODNAME: WWW::Forgejo::Entity::Hook

use strict;
use warnings;

package WWW::Forgejo::Entity::Hook;

use Moo;
extends 'WWW::Forgejo::Entity';
use JSON::MaybeXS qw(encode_json);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);

sub id { shift->data->{id} }
sub type { shift->data->{type} }
sub config { shift->data->{config} }
sub events { shift->data->{events} }
sub active { shift->data->{active} }

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Hooks>

=cut