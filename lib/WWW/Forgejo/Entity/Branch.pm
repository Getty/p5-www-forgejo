# ABSTRACT: Forgejo Branch Entity
# PODNAME: WWW::Forgejo::Entity::Branch

use strict;
use warnings;

package WWW::Forgejo::Entity::Branch;

use Moo;
use JSON::MaybeXS qw(encode_json);

has client => (is => 'ro', required => 1);
has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has data   => (is => 'ro', required => 1);

sub name { shift->data->{name} }
sub commit { shift->data->{commit} }
sub protected { shift->data->{protected} }

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Branches>

=cut