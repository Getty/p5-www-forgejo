# ABSTRACT: Forgejo Pull Request Review Entity
# PODNAME: WWW::Forgejo::Entity::PullRequestReview

use strict;
use warnings;

package WWW::Forgejo::Entity::PullRequestReview;

use Moo;
extends 'WWW::Forgejo::Entity';
use JSON::MaybeXS qw(encode_json);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);

sub id           { shift->data->{id} }
sub body         { shift->data->{body} }
sub state        { shift->data->{state} }
sub user         { shift->data->{user} }
sub submitted_at { shift->data->{submitted_at} }

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::PullRequests>

=cut