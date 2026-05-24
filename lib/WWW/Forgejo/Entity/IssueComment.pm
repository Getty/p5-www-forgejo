# ABSTRACT: Forgejo Issue Comment Entity
# PODNAME: WWW::Forgejo::Entity::IssueComment

use strict;
use warnings;

package WWW::Forgejo::Entity::IssueComment;

use Moo;
use JSON::MaybeXS qw(encode_json);

has client => (is => 'ro', required => 1);
has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has data   => (is => 'ro', required => 1);

sub id          { shift->data->{id} }
sub body        { shift->data->{body} }
sub user        { shift->data->{user} }
sub created_at  { shift->data->{created_at} }
sub updated_at  { shift->data->{updated_at} }

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Issues>

=cut