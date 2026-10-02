package WWW::Forgejo::Entity::QuotaGroup;
# ABSTRACT: Forgejo QuotaGroup Entity
# PODNAME: WWW::Forgejo::Entity::QuotaGroup

use Moo;
extends 'WWW::Forgejo::Entity';
use Log::Any qw($log);
use namespace::clean;

our $VERSION = '0.001';

sub name  { shift->data->{name} }
sub rules { shift->data->{rules} }

1;

__END__

=head1 SYNOPSIS

    my $group = WWW::Forgejo::Entity::QuotaGroup->new(
        client => $forgejo,
        data   => $forgejo->admin->quota->get_group($name),
    );
    print $group->name, "\n";

=head1 DESCRIPTION

Wraps the decoded JSON object of a quota group. None of the controllers returns this class
yet; they hand out the plain decoded data, which can be wrapped as shown in the
L</SYNOPSIS>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=method name

The quota group's name.

=method rules

Arrayref of the quota rules of the group, as plain structures.

=head1 SEE ALSO

L<WWW::Forgejo::Entity>

=cut
