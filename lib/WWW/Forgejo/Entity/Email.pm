package WWW::Forgejo::Entity::Email;
# ABSTRACT: Forgejo Email Entity
# PODNAME: WWW::Forgejo::Entity::Email

use Moo;
use Log::Any qw($log);

has client => (is => 'ro', required => 1);
has data => (is => 'ro', required => 1);

sub email { shift->data->{email} }
sub primary { shift->data->{primary} }
sub verified { shift->data->{verified} }
sub visibility { shift->data->{visibility} }

1;

__END__

=head1 DESCRIPTION

Represents a Forgejo email entity.

=head1 ATTRIBUTES

=head2 email

The email address.

=head2 primary

Whether this is the primary email address.

=head2 verified

Whether the email is verified.

=head2 visibility

The email's visibility (e.g., public, private).

=head1 SEE ALSO

L<WWW::Forgejo::Entity>

=cut