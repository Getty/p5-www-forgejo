package WWW::Forgejo::Entity::User;
# ABSTRACT: Forgejo User Entity
# PODNAME: WWW::Forgejo::Entity::User

use Moo;
extends 'WWW::Forgejo::Entity';
use Log::Any qw($log);

sub id             { shift->data->{id} }
sub login          { shift->data->{login} }
sub full_name      { shift->data->{full_name} }
sub email          { shift->data->{email} }
sub avatar_url     { shift->data->{avatar_url} }
sub description    { shift->data->{description} }
sub login_type     { shift->data->{login_type} }
sub active         { shift->data->{active} }
sub admin          { shift->data->{admin} }
sub allow_git_hook { shift->data->{allow_git_hook} }
sub allow_local_network { shift->data->{allow_local_network} }
sub created        { shift->data->{created} }
sub updated        { shift->data->{updated} }

1;

__END__

=head1 DESCRIPTION

Represents a Forgejo user entity.

=head1 ATTRIBUTES

=head2 id

The user's ID.

=head2 login

The user's login name.

=head2 full_name

The user's full name.

=head2 email

The user's email address.

=head2 avatar_url

URL to the user's avatar.

=head2 description

User profile description.

=head2 login_type

Type of login (e.g., oauth2, plain).

=head2 active

Whether the user is active.

=head2 admin

Whether the user is an admin.

=head2 allow_git_hook

Whether the user is allowed to create git hooks.

=head2 allow_local_network

Whether the user is allowed to access local network.

=head2 created

Timestamp when the user was created.

=head2 updated

Timestamp when the user was last updated.

=head1 SEE ALSO

L<WWW::Forgejo::Entity>

=cut