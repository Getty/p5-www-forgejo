package WWW::Forgejo::Entity::Email;
# ABSTRACT: Forgejo Email Entity
# PODNAME: WWW::Forgejo::Entity::Email

use Moo;
extends 'WWW::Forgejo::Entity';
use Log::Any qw($log);
use namespace::clean;

our $VERSION = '0.001';

sub email { shift->data->{email} }
sub primary { shift->data->{primary} }
sub verified { shift->data->{verified} }

1;

__END__

=head1 SYNOPSIS

    my $email = WWW::Forgejo::Entity::Email->new(
        client => $forgejo,
        data   => \%email,     # one decoded email object
    );
    print $email->email, "\n" if $email->verified;

=head1 DESCRIPTION

Wraps the decoded JSON object of an email address. None of the controllers returns this class
yet; they hand out the plain decoded data, which can be wrapped as shown in the
L</SYNOPSIS>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=method email

The email address.

=method primary

Whether this is the primary email address.

=method verified

Whether the email is verified.

=head1 SEE ALSO

L<WWW::Forgejo::Entity>

=cut
