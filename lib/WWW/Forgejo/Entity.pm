package WWW::Forgejo::Entity;
# ABSTRACT: Base entity class for Forgejo objects
# PODNAME: WWW::Forgejo::Entity

use Moo;
use Log::Any qw($log);
use Carp qw(croak);
use namespace::clean;

our $VERSION = '0.001';

=attr client

The L<WWW::Forgejo> client this object came from. Required.

=cut

has client => (
    is       => 'ro',
    required => 1,
);

=attr data

Hashref with the decoded JSON object as returned by the API. Defaults to an
empty hashref.

=cut

has data => (
    is      => 'ro',
    default => sub { {} },
);

=method update

    $entity->update(%params);

Update the object on the server. The base class only croaks with
C<update not implemented for ...>; entity classes that support it (for example
L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::Org> and
L<WWW::Forgejo::Entity::Team>) override it.

=cut

sub update {
    my ($self, %params) = @_;
    croak "update not implemented for " . ref $self;
}

=method delete

    $entity->delete;

Delete the object on the server. As with L</update>, the base class only croaks
and the entity classes that support it override it.

=cut

sub delete {
    my ($self) = @_;
    croak "delete not implemented for " . ref $self;
}

=head1 SYNOPSIS

    my $user = WWW::Forgejo::Entity::User->new(
        client => $forgejo,
        data   => { id => 1, login => 'test' },
    );

    print $user->login, "\n";            # an accessor of the subclass
    print $user->data->{id}, "\n";       # the complete decoded structure

=cut

1;

__END__

=head1 DESCRIPTION

Base class of the C<WWW::Forgejo::Entity::*> classes. An entity is a thin
object around one decoded JSON object of the API: L</data> holds the complete
structure, the subclasses add accessors for commonly used fields and, where it
makes sense, methods that act on the object.

=head1 SEE ALSO

L<WWW::Forgejo>, L<WWW::Forgejo::Entity::Repo>, L<WWW::Forgejo::Entity::Org>,
L<WWW::Forgejo::Entity::Team>

=cut
