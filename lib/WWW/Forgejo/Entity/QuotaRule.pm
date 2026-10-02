package WWW::Forgejo::Entity::QuotaRule;
# ABSTRACT: Forgejo QuotaRule Entity
# PODNAME: WWW::Forgejo::Entity::QuotaRule

use Moo;
extends 'WWW::Forgejo::Entity';
use Log::Any qw($log);
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
        data   => \%rule,      # one decoded quota rule object
    );
    print $rule->name, "\n";

=head1 DESCRIPTION

Wraps the decoded JSON object of a quota rule. None of the controllers returns this class
yet; they hand out the plain decoded data, which can be wrapped as shown in the
L</SYNOPSIS>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=method name

The rule's name.

=method limit

The limit the rule sets.

=method subjects

Arrayref of the subjects the limit applies to.

=head1 SEE ALSO

L<WWW::Forgejo::Entity>

=cut
