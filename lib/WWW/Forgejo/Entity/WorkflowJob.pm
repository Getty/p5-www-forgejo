# ABSTRACT: Forgejo Workflow Job Entity
# PODNAME: WWW::Forgejo::Entity::WorkflowJob

use strict;
use warnings;

package WWW::Forgejo::Entity::WorkflowJob;

use Moo;
extends 'WWW::Forgejo::Entity';
use JSON::MaybeXS qw(encode_json);
use namespace::clean;

our $VERSION = '0.001';

sub id          { shift->data->{id} }
sub name        { shift->data->{name} }
sub status      { shift->data->{status} }

=method id

The C<id> field of the workflow job data.

=method name

The C<name> field of the workflow job data.

=method status

The C<status> field of the workflow job data.

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

    for my $job ($repo->actions->get_run_jobs($run_id)) {
        printf "%s: %s\n", $job->name, $job->status;
    }

=head1 DESCRIPTION

Wraps the decoded JSON object of a workflow job as returned by
L<WWW::Forgejo::API::Repo::Actions>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Actions>, L<WWW::Forgejo::Entity>

=cut
