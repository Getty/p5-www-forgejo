# ABSTRACT: Forgejo Pull Request Entity
# PODNAME: WWW::Forgejo::Entity::PullRequest

use strict;
use warnings;

package WWW::Forgejo::Entity::PullRequest;

use Moo;
use JSON::MaybeXS qw(encode_json);

has client => (is => 'ro', required => 1);
has owner  => (is => 'ro', required => 1);
has repo   => (is => 'ro', required => 1);
has data   => (is => 'ro', required => 1);

sub id           { shift->data->{id} }
sub number       { shift->data->{number} }
sub title        { shift->data->{title} }
sub body         { shift->data->{body} }
sub state        { shift->data->{state} }
sub html_url     { shift->data->{html_url} }
sub user         { shift->data->{user} }
sub head         { shift->data->{head} }
sub base         { shift->data->{base} }
sub merged       { shift->data->{merged} }
sub merged_at    { shift->data->{merged_at} }
sub comments     { shift->data->{comments} }
sub commits      { shift->data->{commits} }
sub additions    { shift->data->{additions} }
sub deletions    { shift->data->{deletions} }
sub changed_files { shift->data->{changed_files} }

sub data_json {
    my ($self) = @_;
    return encode_json($self->data);
}

1;
__END__

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::PullRequests>

=cut