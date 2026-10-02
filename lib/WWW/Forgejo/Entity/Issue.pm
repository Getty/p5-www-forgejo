# ABSTRACT: Forgejo Issue Entity
# PODNAME: WWW::Forgejo::Entity::Issue

use strict;
use warnings;

package WWW::Forgejo::Entity::Issue;

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
sub number { shift->data->{number} }
sub title { shift->data->{title} }
sub body { shift->data->{body} }
sub state { shift->data->{state} }
sub labels { shift->data->{labels} }

=method id

The C<id> field of the issue data.

=method number

The C<number> field of the issue data.

=method title

The C<title> field of the issue data.

=method body

The C<body> field of the issue data.

=method state

The C<state> field of the issue data.

=method labels

The C<labels> field of the issue data.

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

    my $issue = $repo->issues->get(1);
    printf "#%d %s (%s)\n", $issue->number, $issue->title, $issue->state;

=head1 DESCRIPTION

Wraps the decoded JSON object of an issue as returned by
L<WWW::Forgejo::API::Repo::Issues>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Issues>, L<WWW::Forgejo::Entity>

=cut
