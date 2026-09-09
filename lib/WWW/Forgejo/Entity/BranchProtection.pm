# ABSTRACT: Forgejo Branch Protection Entity
# PODNAME: WWW::Forgejo::Entity::BranchProtection

use strict;
use warnings;

package WWW::Forgejo::Entity::BranchProtection;

use Moo;
extends 'WWW::Forgejo::Entity';
use JSON::MaybeXS qw(encode_json);

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);

sub id { shift->data->{id} }
sub branch_name { shift->data->{branch_name} }
sub rule_name { shift->data->{rule_name} }

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::BranchProtections>

=cut