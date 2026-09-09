# ABSTRACT: Forgejo Milestone Entity
# PODNAME: WWW::Forgejo::Entity::Milestone

use strict;
use warnings;

package WWW::Forgejo::Entity::Milestone;

use Moo;
extends 'WWW::Forgejo::Entity';
use JSON::MaybeXS qw(encode_json);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);

sub id          { shift->data->{id} }
sub number      { shift->data->{number} }
sub title       { shift->data->{title} }
sub description { shift->data->{description} }
sub state       { shift->data->{state} }
sub due_date    { shift->data->{due_date} }
sub closed_at   { shift->data->{closed_at} }
sub created_at  { shift->data->{created_at} }
sub updated_at  { shift->data->{updated_at} }

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Milestones>

=cut