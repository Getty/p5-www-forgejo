# ABSTRACT: Forgejo Deploy Key Entity
# PODNAME: WWW::Forgejo::Entity::DeployKey

use strict;
use warnings;

package WWW::Forgejo::Entity::DeployKey;

use Moo;
extends 'WWW::Forgejo::Entity';
use JSON::MaybeXS qw(encode_json);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);

sub id { shift->data->{id} }
sub title { shift->data->{title} }
sub key { shift->data->{key} }
sub read_only { shift->data->{read_only} }

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Keys>

=cut