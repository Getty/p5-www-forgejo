# ABSTRACT: Forgejo Hook Entity
# PODNAME: WWW::Forgejo::Entity::Hook

use strict;
use warnings;

package WWW::Forgejo::Entity::Hook;

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

sub id { shift->data->{id} }
sub type { shift->data->{type} }
sub config { shift->data->{config} }
sub events { shift->data->{events} }
sub active { shift->data->{active} }

=method id

The C<id> field of the webhook data.

=method type

The C<type> field of the webhook data.

=method config

The C<config> field of the webhook data.

=method events

The C<events> field of the webhook data.

=method active

The C<active> field of the webhook data.

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

    my $hook = $repo->hooks->get(1);
    print $hook->type, "\n" if $hook->active;

=head1 DESCRIPTION

Wraps the decoded JSON object of a webhook as returned by
L<WWW::Forgejo::API::Repo::Hooks>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Hooks>, L<WWW::Forgejo::Entity>

=cut
