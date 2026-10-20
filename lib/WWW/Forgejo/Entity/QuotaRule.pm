package WWW::Forgejo::Entity::QuotaRule;
# ABSTRACT: Forgejo QuotaRule Entity
# PODNAME: WWW::Forgejo::Entity::QuotaRule

use Moo;
extends 'WWW::Forgejo::Entity';
use namespace::clean;

our $VERSION = '0.001';

sub name     { shift->data->{name} }
sub limit    { shift->data->{limit} }
sub subjects { shift->data->{subjects} }

1;

__END__

=head1 SYNOPSIS

    my $rule = WWW::Forgejo::Entity::QuotaRule->new(
        client => $forgejo,
        data   => $forgejo->admin->quota->get_rule($name)->data,
    );
    print $rule->name, "\n";

=head1 DESCRIPTION

A quota rule as returned by L<WWW::Forgejo::API::Admin::Quota>. It gives the
name of the rule (L</name>), the limit it sets (L</limit>) and the subjects it
applies to (L</subjects>).

The accessors read single fields from L<data|WWW::Forgejo::Entity/data>, which
always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=method name

The rule's name.

=method limit

The limit the rule sets.

=method subjects

Arrayref of the subjects the limit applies to.

=head1 SEE ALSO

L<WWW::Forgejo::API::Admin::Quota>, L<WWW::Forgejo::Entity>

=cut
