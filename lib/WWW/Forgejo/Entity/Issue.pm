# ABSTRACT: Forgejo Issue Entity
# PODNAME: WWW::Forgejo::Entity::Issue

use strict;
use warnings;

package WWW::Forgejo::Entity::Issue;

use Moo;
extends 'WWW::Forgejo::Entity';
use JSON::MaybeXS qw(encode_json);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);

sub id { shift->data->{id} }
sub number { shift->data->{number} }
sub title { shift->data->{title} }
sub body { shift->data->{body} }
sub state { shift->data->{state} }
sub labels { shift->data->{labels} }

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Issues>

=cut