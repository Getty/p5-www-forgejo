package WWW::Forgejo::Entity::User;
# ABSTRACT: Forgejo User Entity
# PODNAME: WWW::Forgejo::Entity::User

use Moo;
extends 'WWW::Forgejo::Entity';
use Log::Any qw($log);
use namespace::clean;

our $VERSION = '0.001';

sub id             { shift->data->{id} }
sub login          { shift->data->{login} }
sub full_name      { shift->data->{full_name} }
sub email          { shift->data->{email} }
sub avatar_url     { shift->data->{avatar_url} }
sub description    { shift->data->{description} }
sub active         { shift->data->{active} }
sub is_admin          { shift->data->{is_admin} }
sub created        { shift->data->{created} }

1;

__END__

=head1 SYNOPSIS

    my $user = WWW::Forgejo::Entity::User->new(
        client => $forgejo,
        data   => $forgejo->users->get('getty'),
    );
    print $user->login, "\n";

=head1 DESCRIPTION

Wraps the decoded JSON object of an user. None of the controllers returns this class
yet; they hand out the plain decoded data, which can be wrapped as shown in the
L</SYNOPSIS>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=method id

The user's ID.

=method login

The user's login name.

=method full_name

The user's full name.

=method email

The user's email address.

=method avatar_url

URL to the user's avatar.

=method description

User profile description.

=method active

Whether the user is active.

=method is_admin

Whether the user is an admin.

=method created

Timestamp when the user was created.

=head1 SEE ALSO

L<WWW::Forgejo::Entity>

=cut
