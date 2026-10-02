# ABSTRACT: Forgejo Workflow Run Entity
# PODNAME: WWW::Forgejo::Entity::WorkflowRun

use strict;
use warnings;

package WWW::Forgejo::Entity::WorkflowRun;

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

sub id           { shift->data->{id} }
sub title         { shift->data->{title} }
sub prettyref  { shift->data->{prettyref} }
sub commit_sha     { shift->data->{commit_sha} }
sub status       { shift->data->{status} }
sub workflow_id   { shift->data->{workflow_id} }
sub created   { shift->data->{created} }
sub updated   { shift->data->{updated} }

=method id

The C<id> field of the workflow run data.

=method title

The C<title> field of the workflow run data.

=method prettyref

The C<prettyref> field of the workflow run data.

=method commit_sha

The C<commit_sha> field of the workflow run data.

=method status

The C<status> field of the workflow run data.

=method workflow_id

The C<workflow_id> field of the workflow run data.

=method created

The C<created> field of the workflow run data.

=method updated

The C<updated> field of the workflow run data.

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

    my $run = $repo->actions->get_run($run_id);
    print $run->status, "\n";

=head1 DESCRIPTION

Wraps the decoded JSON object of a workflow run as returned by
L<WWW::Forgejo::API::Repo::Actions>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::Actions>, L<WWW::Forgejo::Entity>

=cut
