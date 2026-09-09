package WWW::Forgejo::Entity::QuotaGroup;
# ABSTRACT: Forgejo QuotaGroup Entity
# PODNAME: WWW::Forgejo::Entity::QuotaGroup

use Moo;
extends 'WWW::Forgejo::Entity';
use Log::Any qw($log);

sub name        { shift->data->{name} }
sub description { shift->data->{description} }
sub counters    { shift->data->{counters} }

1;

__END__

=head1 DESCRIPTION

Represents a Forgejo quota group entity.

=head1 ATTRIBUTES

=head2 name

The quota group's name.

=head2 description

The quota group's description.

=head2 counters

The group's counters.

=head1 SEE ALSO

L<WWW::Forgejo::Entity>

=cut