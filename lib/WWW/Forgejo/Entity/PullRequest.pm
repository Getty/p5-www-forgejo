# ABSTRACT: Forgejo Pull Request Entity
# PODNAME: WWW::Forgejo::Entity::PullRequest

use strict;
use warnings;

package WWW::Forgejo::Entity::PullRequest;

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
sub additions    { shift->data->{additions} }
sub deletions    { shift->data->{deletions} }
sub changed_files { shift->data->{changed_files} }

=method id

The C<id> field of the pull request data.

=method number

The C<number> field of the pull request data.

=method title

The C<title> field of the pull request data.

=method body

The C<body> field of the pull request data.

=method state

The C<state> field of the pull request data.

=method html_url

The C<html_url> field of the pull request data.

=method user

The C<user> field of the pull request data.

=method head

The C<head> field of the pull request data.

=method base

The C<base> field of the pull request data.

=method merged

The C<merged> field of the pull request data.

=method merged_at

The C<merged_at> field of the pull request data.

=method comments

The C<comments> field of the pull request data.

=method additions

The C<additions> field of the pull request data.

=method deletions

The C<deletions> field of the pull request data.

=method changed_files

The C<changed_files> field of the pull request data.

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

    my $pr = $repo->pulls->get(1);
    printf "#%d %s (%s)\n", $pr->number, $pr->title, $pr->state;

=head1 DESCRIPTION

Wraps the decoded JSON object of a pull request as returned by
L<WWW::Forgejo::API::Repo::PullRequests>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=head1 SEE ALSO

L<WWW::Forgejo::API::Repo::PullRequests>, L<WWW::Forgejo::Entity>

=cut
