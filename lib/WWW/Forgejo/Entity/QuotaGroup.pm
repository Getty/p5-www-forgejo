package WWW::Forgejo::Entity::QuotaGroup;
# ABSTRACT: Forgejo QuotaGroup Entity
# PODNAME: WWW::Forgejo::Entity::QuotaGroup

use strict;
use warnings;

use Moo;
extends 'WWW::Forgejo::Entity';
use WWW::Forgejo::Entity::QuotaRule;
use namespace::clean;

our $VERSION = '0.001';

=method name

    my $name = $group->name;

The name of the quota group.

=cut

sub name { shift->data->{name} }

=method rules

    my $rules = $group->rules;

The quota rules of the group, as an arrayref of
L<WWW::Forgejo::Entity::QuotaRule> objects.

=cut

sub rules {
    my ($self) = @_;
    my $rules = $self->data->{rules} || [];
    return [
        map { WWW::Forgejo::Entity::QuotaRule->new(client => $self->client, data => $_) } @$rules
    ];
}

1;

__END__

=head1 SYNOPSIS

    my $group = WWW::Forgejo::Entity::QuotaGroup->new(
        client => $forgejo,
        data   => $forgejo->admin->quota->get_group($name)->data,
    );
    print $group->name, "\n";

=head1 DESCRIPTION

A quota group as returned by L<WWW::Forgejo::API::Admin::Quota>. It gives the
name of the group (L</name>) and the quota rules it holds (L</rules>).

The accessors read single fields from L<data|WWW::Forgejo::Entity/data>, which
always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Admin::Quota>, L<WWW::Forgejo::Entity::QuotaRule>,
L<WWW::Forgejo::Entity>

=cut
