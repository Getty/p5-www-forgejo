# ABSTRACT: Forgejo Collaborator Entity
# PODNAME: WWW::Forgejo::Entity::Collaborator

use strict;
use warnings;

package WWW::Forgejo::Entity::Collaborator;

use Moo;
extends 'WWW::Forgejo::Entity';
use JSON::MaybeXS qw(encode_json);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);

sub login { shift->data->{login} }
sub id { shift->data->{id} }
sub permissions { shift->data->{permissions} }

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Collaborators>

=cut