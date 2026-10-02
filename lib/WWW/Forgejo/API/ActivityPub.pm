# ABSTRACT: Forgejo ActivityPub API
# PODNAME: WWW::Forgejo::API::ActivityPub

use strict;
use warnings;

package WWW::Forgejo::API::ActivityPub;

use Moo;
use URI::Escape qw(uri_escape);
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

=method actor

    my $actor = $forgejo->activitypub->actor($user_id);

Get the ActivityPub actor of a user (C<GET /activitypub/user-id/{user-id}>).
The user is addressed by numeric ID.

=cut

sub actor {
    my ($self, $user_id) = @_;
    return $self->client->get("/activitypub/user-id/" . uri_escape($user_id));
}

=method inbox

    my $result = $forgejo->activitypub->inbox($user_id, $activity);

Send an activity to the inbox of a user
(C<POST /activitypub/user-id/{user-id}/inbox>). The hashref is sent as the JSON
body.

=cut

sub inbox {
    my ($self, $user_id, $activity) = @_;
    return $self->client->post("/activitypub/user-id/" . uri_escape($user_id) . "/inbox", $activity);
}

=method outbox

    my $outbox = $forgejo->activitypub->outbox($user_id);

Get the ActivityPub outbox of a user
(C<GET /activitypub/user-id/{user-id}/outbox>).

=cut

sub outbox {
    my ($self, $user_id) = @_;
    return $self->client->get("/activitypub/user-id/" . uri_escape($user_id) . "/outbox");
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $actor  = $forgejo->activitypub->actor($user_id);
    my $outbox = $forgejo->activitypub->outbox($user_id);

=head1 DESCRIPTION

The ActivityPub endpoints for users (C</activitypub/user-id/{user-id}>).
Available as C<< $forgejo->activitypub >>.

All methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo>

=cut
