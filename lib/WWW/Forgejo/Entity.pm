package WWW::Forgejo::Entity;
# ABSTRACT: Base entity class for Forgejo objects
# PODNAME: WWW::Forgejo::Entity

use Moo;
use Log::Any qw($log);
use Carp qw(croak);

=attr client

Weak reference to the API client.

=cut

has client => (
    is       => 'ro',
    weak_ref => 1,
    required => 1,
);

=attr data

Hashref of raw entity data from the API.

=cut

has data => (
    is      => 'ro',
    default => sub { {} },
);

=method update

Update the entity via API (PUT). Returns updated data.

=cut

sub update {
    my ($self, %params) = @_;
    croak "update not implemented for " . ref $self;
}

=method delete

Delete the entity via API (DELETE).

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

=cut

1;

__END__

=head1 DESCRIPTION

Base entity class for Forgejo objects. Provides common attributes and
methods for interacting with API data.

=head1 ATTRIBUTES

=head2 client

Weak reference to the API client.

=head2 data

Hashref of raw entity data from the API.

=head1 METHODS

=head2 update

    $item->update(%params);

Update the entity via API (PUT). Returns updated data.

=head2 delete

    $item->delete;

Delete the entity via API (DELETE).

=cut