# ABSTRACT: Forgejo ActivityPub API
# PODNAME: WWW::Forgejo::API::ActivityPub

use strict;
use warnings;

package WWW::Forgejo::API::ActivityPub;

use Moo;
use WWW::Forgejo::URL qw( escape_component );
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
    return $self->client->get("/activitypub/user-id/" . escape_component($user_id));
}

=method inbox

    my $result = $forgejo->activitypub->inbox($user_id,
        type  => 'Follow',
        actor => 'https://other.test/users/a',
    );

Send an activity to the inbox of a user
(C<POST /activitypub/user-id/{user-id}/inbox>). The named arguments are sent
as the JSON body.

=cut

sub inbox {
    my ($self, $user_id, %params) = @_;
    return $self->client->post("/activitypub/user-id/" . escape_component($user_id) . "/inbox", \%params);
}

=method outbox

    my $outbox = $forgejo->activitypub->outbox($user_id);

Get the ActivityPub outbox of a user
(C<GET /activitypub/user-id/{user-id}/outbox>).

=cut

sub outbox {
    my ($self, $user_id) = @_;
    return $self->client->get("/activitypub/user-id/" . escape_component($user_id) . "/outbox");
}

=method instance_actor

    my $actor = $forgejo->activitypub->instance_actor;

Get the actor of the instance itself (C<GET /activitypub/actor>). This is the
only endpoint of the group that is served without a signature, so it is the one
that works against a federating instance.

=cut

sub instance_actor {
    my ($self) = @_;
    return $self->client->get('/activitypub/actor');
}

=method instance_inbox

    $forgejo->activitypub->instance_inbox(
        type  => 'Follow',
        actor => 'https://other.test/users/a',
    );

Send an activity to the inbox of the instance
(C<POST /activitypub/actor/inbox>). The named arguments are sent as the JSON
body.

=cut

sub instance_inbox {
    my ($self, %params) = @_;
    return $self->client->post('/activitypub/actor/inbox', \%params);
}

=method instance_outbox

    $forgejo->activitypub->instance_outbox;

Show the outbox of the instance (C<POST /activitypub/actor/outbox>). The
outbox of the instance is always empty. The named arguments are sent as the
JSON body.

=cut

sub instance_outbox {
    my ($self, %params) = @_;
    return $self->client->post('/activitypub/actor/outbox', \%params);
}

=method repository_actor

    my $actor = $forgejo->activitypub->repository_actor($repository_id);

Get the ActivityPub actor of a repository
(C<GET /activitypub/repository-id/{repository-id}>). The repository is
addressed by numeric ID.

=cut

sub repository_actor {
    my ($self, $repository_id) = @_;
    return $self->client->get("/activitypub/repository-id/" . escape_component($repository_id));
}

=method repository_inbox

    $forgejo->activitypub->repository_inbox($repository_id,
        type  => 'Follow',
        actor => 'https://other.test/users/a',
    );

Send an activity to the inbox of a repository
(C<POST /activitypub/repository-id/{repository-id}/inbox>). The named
arguments are sent as the JSON body.

=cut

sub repository_inbox {
    my ($self, $repository_id, %params) = @_;
    return $self->client->post(
        "/activitypub/repository-id/" . escape_component($repository_id) . "/inbox", \%params);
}

=method repository_outbox

    my $outbox = $forgejo->activitypub->repository_outbox($repository_id);

Show the outbox of a repository
(C<POST /activitypub/repository-id/{repository-id}/outbox>). The named
arguments are sent as the JSON body.

=cut

sub repository_outbox {
    my ($self, $repository_id, %params) = @_;
    return $self->client->post(
        "/activitypub/repository-id/" . escape_component($repository_id) . "/outbox", \%params);
}

=method activity

    my $activity = $forgejo->activitypub->activity($user_id, $activity_id);

Get one activity of a user
(C<GET /activitypub/user-id/{user-id}/activities/{activity-id}/activity>). The
user and the activity are addressed by numeric ID.

=cut

sub activity {
    my ($self, $user_id, $activity_id) = @_;
    return $self->client->get(
        "/activitypub/user-id/" . escape_component($user_id)
        . "/activities/" . escape_component($activity_id) . "/activity");
}

=method activity_object

    my $object = $forgejo->activitypub->activity_object($user_id, $activity_id);

Get the object of one activity of a user
(C<GET /activitypub/user-id/{user-id}/activities/{activity-id}>). The user and
the activity are addressed by numeric ID.

=cut

sub activity_object {
    my ($self, $user_id, $activity_id) = @_;
    return $self->client->get(
        "/activitypub/user-id/" . escape_component($user_id)
        . "/activities/" . escape_component($activity_id));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $actor  = $forgejo->activitypub->actor($user_id);
    my $outbox = $forgejo->activitypub->outbox($user_id);

=head1 DESCRIPTION

The ActivityPub endpoints for users (C</activitypub/user-id/{user-id}>), for
repositories (C</activitypub/repository-id/{repository-id}>) and for the instance
itself (C</activitypub/actor>). Available as C<< $forgejo->activitypub >>.

The paths are relative to the API base URL of the client (C</api/v1>), so
C<actor> asks the instance for C</api/v1/activitypub/user-id/{user-id}>.

All methods return the decoded JSON response as plain Perl data.

=over 4

=item * The boundary of this client

Forgejo registers these endpoints only when federation is switched on
(C<[federation] ENABLED = true> in the configuration of the instance). With
federation off the paths do not exist and the request fails with a C<404>.

With federation on, Forgejo wants every request to the actor, the inbox and
the outbox signed with an HTTP signature, which this client does not make: an
unsigned request is answered with C<400> and the message C<request signature
verification failed>, which the client turns into the croak C<Forgejo API
error: request signature verification failed>.

These methods therefore only work against an instance that does not ask for a
signature; against a federating instance they fail with that croak. The
instance actor (C</activitypub/actor>) is the one endpoint of the group that is
served without a signature, so L</instance_actor> is the one that works
against a federating instance.

=item * A bug of the instance

Forgejo 15.0.7 panics when it is asked for the note of an activity that does
not exist (C</activitypub/user-id/{user-id}/activities/{activity-id}>): the
answer carries the JSON error C<The target couldn't be found.> and, in the
same body, the HTML page of the internal server error the instance rendered
for the panic. The body is no valid JSON, so the client cannot read the
message of the error and croaks with C<Forgejo API error: 404>. The activity
itself (C</activitypub/user-id/{user-id}/activities/{activity-id}/activity>)
answers with a plain 404 and the same croak.

=back

=head1 SEE ALSO

L<WWW::Forgejo>

=cut
