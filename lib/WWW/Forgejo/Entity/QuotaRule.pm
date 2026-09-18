package WWW::Forgejo::Entity::QuotaRule;
# ABSTRACT: Forgejo QuotaRule Entity
# PODNAME: WWW::Forgejo::Entity::QuotaRule

use Moo;
extends 'WWW::Forgejo::Entity';
use Log::Any qw($log);

sub id        { shift->data->{id} }
sub name      { shift->data->{name} }
sub rule_type { shift->data->{rule_type} }
sub value     { shift->data->{value} }

1;

__END__

=head1 DESCRIPTION

Represents a Forgejo quota rule entity.

=head1 ATTRIBUTES

=head2 id

The rule's ID.

=head2 name

The rule's name.

=head2 rule_type

The rule type (e.g., size, count).

=head2 value

The rule's value.

=head1 SEE ALSO

L<WWW::Forgejo::Entity>

=cut