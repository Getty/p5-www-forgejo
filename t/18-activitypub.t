#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);
use WWW::Forgejo::API::ActivityPub;

# The ActivityPub endpoints the client did not cover yet: the actor of the
# instance with its inbox and its outbox, the actor of a repository with its
# inbox and its outbox, and the activities of a user.
#
# Every call is made in an eval, so a method that does not exist shows up as a
# failed test instead of a dead file.

my ($client, $io) = mock_client();
my $base = 'https://forgejo.test/api/v1';

my $ap = WWW::Forgejo::API::ActivityPub->new(client => $client);

sub request {
    my $last = $io->last or return '(no request)';
    my $url = substr($last->url, length $base);
    $url =~ s/\?.*//;
    return $last->method . ' ' . $url;
}

sub body {
    my $last = $io->last or return undef;
    return $last->has_content ? decode_json($last->content) : undef;
}

# The value of an expression, or undef when it dies.
sub value { return eval { $_[0]->() } }

# ---------------------------------------------------------------------------
# The instance
# ---------------------------------------------------------------------------

subtest 'the actor of the instance' => sub {
    $io->reset->add(200, '{"id":"http://forgejo.test/actor"}');
    my $actor = value(sub { $ap->instance_actor });
    is(request(), 'GET /activitypub/actor', 'GET /activitypub/actor');
    is(ref $actor, 'HASH', 'instance_actor returns the plain actor') or return;
    is($actor->{id}, 'http://forgejo.test/actor', 'the id of the actor');
};

subtest 'the inbox and the outbox of the instance' => sub {
    $io->reset->add(204, '');
    value(sub { $ap->instance_inbox(type => 'Follow', actor => 'https://other.test/users/a') });
    is(request(), 'POST /activitypub/actor/inbox', 'POST /activitypub/actor/inbox');
    is_deeply(body(), { type => 'Follow', actor => 'https://other.test/users/a' },
        'the activity is the body of the request');

    $io->reset->add(200, '{"orderedItems":[]}');
    my $outbox = value(sub { $ap->instance_outbox });
    is(request(), 'POST /activitypub/actor/outbox', 'POST /activitypub/actor/outbox');
    is(ref $outbox, 'HASH', 'instance_outbox returns the outbox');
};

# ---------------------------------------------------------------------------
# A repository
# ---------------------------------------------------------------------------

subtest 'the actor of a repository' => sub {
    $io->reset->add(200, '{"id":"http://forgejo.test/repo"}');
    my $actor = value(sub { $ap->repository_actor(7) });
    is(request(), 'GET /activitypub/repository-id/7',
        'GET /activitypub/repository-id/{repository-id}');
    is(ref $actor, 'HASH', 'repository_actor returns the plain actor') or return;
};

subtest 'the inbox and the outbox of a repository' => sub {
    $io->reset->add(204, '');
    value(sub { $ap->repository_inbox(7, type => 'Follow') });
    is(request(), 'POST /activitypub/repository-id/7/inbox',
        'POST /activitypub/repository-id/{repository-id}/inbox');
    is_deeply(body(), { type => 'Follow' }, 'the activity is the body of the request');

    $io->reset->add(200, '{"orderedItems":[]}');
    my $outbox = value(sub { $ap->repository_outbox(7) });
    is(request(), 'POST /activitypub/repository-id/7/outbox',
        'POST /activitypub/repository-id/{repository-id}/outbox');
    is(ref $outbox, 'HASH', 'repository_outbox returns the outbox');
};

# ---------------------------------------------------------------------------
# The activities of a user
# ---------------------------------------------------------------------------

subtest 'the activities of a user' => sub {
    $io->reset->add(200, '{"type":"Like"}');
    my $activity = value(sub { $ap->activity(3, 9) });
    is(request(), 'GET /activitypub/user-id/3/activities/9/activity',
        'GET /activitypub/user-id/{user-id}/activities/{activity-id}/activity');
    is(ref $activity, 'HASH', 'activity returns the plain activity') or return;
    is($activity->{type}, 'Like', 'the type of the activity');

    $io->reset->add(200, '{"type":"Note"}');
    my $object = value(sub { $ap->activity_object(3, 9) });
    is(request(), 'GET /activitypub/user-id/3/activities/9',
        'GET /activitypub/user-id/{user-id}/activities/{activity-id}');
    is(ref $object, 'HASH', 'activity_object returns the plain object') or return;
    is($object->{type}, 'Note', 'the type of the object');
};

# ---------------------------------------------------------------------------
# The names of the paths are escaped
# ---------------------------------------------------------------------------

subtest 'the names of the paths are escaped' => sub {
    $io->reset->add(200, '{}');
    value(sub { $ap->activity('a b', 'c d') });
    is(request(), 'GET /activitypub/user-id/a%20b/activities/c%20d/activity',
        'the parts of the path are escaped');
};

done_testing;
