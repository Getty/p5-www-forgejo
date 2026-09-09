# ABSTRACT: Forgejo Workflow Run Entity
# PODNAME: WWW::Forgejo::Entity::WorkflowRun

use strict;
use warnings;

package WWW::Forgejo::Entity::WorkflowRun;

use Moo;
extends 'WWW::Forgejo::Entity';
use JSON::MaybeXS qw(encode_json);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);

sub id           { shift->data->{id} }
sub name         { shift->data->{name} }
sub head_branch  { shift->data->{head_branch} }
sub head_sha     { shift->data->{head_sha} }
sub status       { shift->data->{status} }
sub conclusion   { shift->data->{conclusion} }
sub workflow_id   { shift->data->{workflow_id} }
sub created_at   { shift->data->{created_at} }
sub updated_at   { shift->data->{updated_at} }

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Actions>

=cut