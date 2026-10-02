# ABSTRACT: Forgejo Collaborator Entity
# PODNAME: WWW::Forgejo::Entity::Collaborator

use strict;
use warnings;

package WWW::Forgejo::Entity::Collaborator;

use Moo;
extends 'WWW::Forgejo::Entity';
use JSON::MaybeXS qw(encode_json);
use namespace::clean;

our $VERSION = '0.001';

has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);

=attr owner

Owner (user or organization name) of the repository this object belongs to.
Required.

=attr repo

Name of the repository this object belongs to. Required.

=cut

sub login { shift->data->{login} }
sub id { shift->data->{id} }

=method login

The C<login> field of the collaborator data.

=method id

The C<id> field of the collaborator data.

=cut

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

=method data_json

Returns L<data|WWW::Forgejo::Entity/data> encoded as a JSON string.

=cut

1;

__END__

=head1 SYNOPSIS

    for my $collaborator ($repo->collaborators->list) {
        print $collaborator->login, "\n";
    }

=head1 DESCRIPTION

Wraps the decoded JSON object of a collaborator as returned by
L<WWW::Forgejo::API::Repo::Collaborators>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Collaborators>, L<WWW::Forgejo::Entity>

=cut
