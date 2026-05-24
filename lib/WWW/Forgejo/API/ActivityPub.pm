# ABSTRACT: Forgejo ActivityPub API
# PODNAME: WWW::Forgejo::API::ActivityPub

use strict;
use warnings;

package WWW::Forgejo::API::ActivityPub;

use Moo;
use Log::Any qw($log);


=method actor

    my $actor = $self->{client}->actor($username);

Get ActivityPub actor information for a user.

=cut

sub actor {
    my ($self, $username) = @_;
    return $self->{client}->get("/activitypub/user/$username");
}

=method inbox

    my $result = $self->{client}->inbox($username, $activity);

Send an activity to a user's inbox.

=cut

sub inbox {
    my ($self, $username, $activity) = @_;
    return $self->{client}->post("/activitypub/user/$username/inbox", $activity);
}

=method outbox

    my $outbox = $self->{client}->outbox($username);

Get ActivityPub outbox for a user.

=cut

sub outbox {
    my ($self, $username) = @_;
    return $self->{client}->get("/activitypub/user/$username/outbox");
}

1;