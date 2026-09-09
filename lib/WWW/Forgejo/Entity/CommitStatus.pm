# ABSTRACT: Forgejo Commit Status Entity
# PODNAME: WWW::Forgejo::Entity::CommitStatus

use strict;
use warnings;

package WWW::Forgejo::Entity::CommitStatus;

use Moo;
extends 'WWW::Forgejo::Entity';
use JSON::MaybeXS qw(encode_json);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);

sub id { shift->data->{id} }
sub state { shift->data->{state} }
sub description { shift->data->{description} }
sub target_url { shift->data->{target_url} }
sub context { shift->data->{context} }

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Statuses>

=cut