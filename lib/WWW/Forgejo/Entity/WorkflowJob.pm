# ABSTRACT: Forgejo Workflow Job Entity
# PODNAME: WWW::Forgejo::Entity::WorkflowJob

use strict;
use warnings;

package WWW::Forgejo::Entity::WorkflowJob;

use Moo;
extends 'WWW::Forgejo::Entity';
use JSON::MaybeXS qw(encode_json);

sub id          { shift->data->{id} }
sub name        { shift->data->{name} }
sub status      { shift->data->{status} }
sub conclusion  { shift->data->{conclusion} }
sub started_at  { shift->data->{started_at} }
sub completed_at { shift->data->{completed_at} }

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Actions>

=cut