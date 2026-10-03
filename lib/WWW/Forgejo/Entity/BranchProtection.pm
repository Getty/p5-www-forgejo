# ABSTRACT: Forgejo Branch Protection Entity
# PODNAME: WWW::Forgejo::Entity::BranchProtection

use strict;
use warnings;

package WWW::Forgejo::Entity::BranchProtection;

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

sub branch_name { shift->data->{branch_name} }
sub rule_name { shift->data->{rule_name} }

=method branch_name

The C<branch_name> field of the branch protection data. Deprecated by Forgejo
in favour of C<rule_name>; it is empty for a rule that is a pattern
(C<release/*>).

=method rule_name

The C<rule_name> field of the branch protection data: the branch name or
pattern the rule applies to.

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

    my $protection = $repo->branch_protections->get('main');
    print $protection->rule_name, "\n";

=head1 DESCRIPTION

Wraps the decoded JSON object of a branch protection as returned by
L<WWW::Forgejo::API::Repo::BranchProtections>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::BranchProtections>, L<WWW::Forgejo::Entity>

=cut
