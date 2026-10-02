# ABSTRACT: Forgejo Commit Status Entity
# PODNAME: WWW::Forgejo::Entity::CommitStatus

use strict;
use warnings;

package WWW::Forgejo::Entity::CommitStatus;

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
sub status { shift->data->{status} }
sub description { shift->data->{description} }
sub target_url { shift->data->{target_url} }
sub context { shift->data->{context} }

=method id

The C<id> field of the commit status data.

=method status

The C<status> field of the commit status data.

=method description

The C<description> field of the commit status data.

=method target_url

The C<target_url> field of the commit status data.

=method context

The C<context> field of the commit status data.

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

    my $repo = $forgejo->repos->get('owner', 'repo-name');
    for my $status ($repo->statuses->list($sha)) {
        printf "%s: %s\n", $status->context, $status->status;
    }

=head1 DESCRIPTION

Wraps the decoded JSON object of a commit status as returned by
L<WWW::Forgejo::API::Repo::Statuses>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Statuses>, L<WWW::Forgejo::Entity>

=cut
