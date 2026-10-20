#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);
use WWW::Forgejo::API::CurrentUser;

# The endpoints of the user the token belongs to the client did not cover yet:
# the token to sign a commit with, the verification of a GPG key, the avatar,
# the OAuth2 applications and the follow of an actor of the fediverse.
#
# Every call is made in an eval, so a method that does not exist shows up as a
# failed test instead of a dead file.

my ($client, $io) = mock_client();
my $base = 'https://forgejo.test/api/v1';

my $user = WWW::Forgejo::API::CurrentUser->new(client => $client);

sub request {
    my $last = $io->last or return '(no request)';
    return $last->method . ' ' . path();
}

sub path {
    my $last = $io->last or return '(no request)';
    my $url = substr($last->url, length $base);
    $url =~ s/\?.*//;
    return $url;
}

sub body {
    my $last = $io->last or return {};
    return $last->has_content ? decode_json($last->content) : {};
}

# The value of an expression, or undef when it dies.
sub value { return eval { $_[0]->() } }

# The message of the exception of an expression, or the empty string.
sub error {
    my $err = '';
    eval { $_[0]->() };
    $err = $@ if $@;
    return $err;
}

# ---------------------------------------------------------------------------
# The GPG key
# ---------------------------------------------------------------------------

subtest 'the token to sign a commit' => sub {
    $io->reset->add(200, '{"id":1,"token":"TOKEN"}');
    my $token = value(sub { $user->gpg_key_token });
    is(request(), 'GET /user/gpg_key_token', 'GET /user/gpg_key_token');
    is($token->{token}, 'TOKEN', 'the token is decoded');
};

subtest 'the verification of a GPG key' => sub {
    $io->reset->add(200, '{"verified":true}');
    my $key = value(sub {
        $user->verify_gpg_key(armored_signature => 'SIGNATURE', key_id => 'KEY');
    });
    is(request(), 'POST /user/gpg_key_verify', 'POST /user/gpg_key_verify');
    is(body()->{armored_signature}, 'SIGNATURE', 'the signature is sent in the body');
    is(body()->{key_id}, 'KEY', 'the key is sent in the body');
    ok($key->{verified}, 'the answer is decoded');
};

subtest 'the verification needs a signature and a key' => sub {
    $io->reset;
    ok(error(sub { $user->verify_gpg_key(key_id => 'KEY') }), 'a missing signature dies');
    ok(error(sub { $user->verify_gpg_key(armored_signature => 'SIGNATURE') }), 'a missing key dies');
    is($io->count, 0, 'no request was sent');
};

# ---------------------------------------------------------------------------
# The avatar
# ---------------------------------------------------------------------------

subtest 'the avatar is set' => sub {
    $io->reset->add(200, '{}');
    my $set = value(sub { $user->set_avatar(image => 'YmFzZTY0') });
    is(request(), 'POST /user/avatar', 'POST /user/avatar');
    is(body()->{image}, 'YmFzZTY0', 'the image is sent in the body');
    is($set, 1, 'the method returns true');
};

subtest 'the avatar needs an image' => sub {
    $io->reset;
    ok(error(sub { $user->set_avatar(image => '') }), 'an empty image dies');
    ok(error(sub { $user->set_avatar() }), 'a missing image dies');
    is($io->count, 0, 'no request was sent');
};

subtest 'the avatar is deleted' => sub {
    $io->reset->add(200, '{}');
    my $deleted = value(sub { $user->delete_avatar });
    is(request(), 'DELETE /user/avatar', 'DELETE /user/avatar');
    is($deleted, 1, 'the method returns true');
};

# ---------------------------------------------------------------------------
# The OAuth2 applications
# ---------------------------------------------------------------------------

subtest 'one OAuth2 application' => sub {
    $io->reset->add(200, '{"id":5,"name":"My app"}');
    my $app = value(sub { $user->get_application(5) });
    is(request(), 'GET /user/applications/oauth2/5', 'GET /user/applications/oauth2/{id}');
    is($app->{name}, 'My app', 'the application is decoded');
};

subtest 'an OAuth2 application is edited' => sub {
    $io->reset->add(200, '{"id":5,"name":"New name"}');
    my $app = value(sub { $user->edit_application(5, name => 'New name') });
    is(request(), 'PATCH /user/applications/oauth2/5', 'PATCH /user/applications/oauth2/{id}');
    is(body()->{name}, 'New name', 'the name is sent in the body');
    is($app->{name}, 'New name', 'the application is decoded');
};

subtest 'the ID of an OAuth2 application is required' => sub {
    $io->reset;
    ok(error(sub { $user->get_application() }), 'a missing ID dies');
    ok(error(sub { $user->edit_application(undef, name => 'x') }), 'a missing ID dies');
    is($io->count, 0, 'no request was sent');
};

# ---------------------------------------------------------------------------
# The fediverse
# ---------------------------------------------------------------------------

subtest 'an actor of the fediverse is followed' => sub {
    $io->reset->add(200, '{}');
    my $followed = value(sub { $user->activitypub_follow(target => 'https://example.com/user') });
    is(request(), 'POST /user/activitypub/follow', 'POST /user/activitypub/follow');
    is(body()->{target}, 'https://example.com/user', 'the target is sent in the body');
    is($followed, 1, 'the method returns true');
};

subtest 'the target of the follow is required' => sub {
    $io->reset;
    ok(error(sub { $user->activitypub_follow() }), 'a missing target dies');
    ok(error(sub { $user->activitypub_follow(target => '') }), 'an empty target dies');
    is($io->count, 0, 'no request was sent');
};

done_testing;
