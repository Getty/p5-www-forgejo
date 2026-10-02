#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);

subtest 'delete can carry a JSON body' => sub {
    my ($client, $io) = mock_client();
    $io->add(204, '');
    $client->delete('/user/emails', { emails => ['a@example.com'] });
    my $req = $io->last;
    is($req->method, 'DELETE', 'method');
    ok($req->has_content, 'request has content');
    is_deeply(decode_json($req->content), { emails => ['a@example.com'] }, 'body');
};

subtest 'delete without data sends no body' => sub {
    my ($client, $io) = mock_client();
    $io->add(204, '');
    $client->delete('/orgs/x');
    ok(!$io->last->has_content, 'no content');
};

subtest 'query parameters work on every verb' => sub {
    for my $verb (qw(post put patch delete)) {
        my ($client, $io) = mock_client();
        $io->add(200, '{}');
        $client->$verb('/notifications', undef, params => { all => 'true', 'to-status' => 'read' });
        my $req = $io->last;
        is($req->method, uc $verb, "$verb: method");
        like($req->url, qr{/notifications\?all=true&to-status=read$}, "$verb: query string appended");
        ok(!$req->has_content, "$verb: no body when data is undef");
    }
};

subtest 'query parameters are emitted in sorted order' => sub {
    my ($client, $io) = mock_client();
    $client->get('/x', params => { zeta => 1, alpha => 2, mid => 3 });
    like($io->last->url, qr{/x\?alpha=2&mid=3&zeta=1$}, 'sorted by key');
};

subtest 'error with a JSON array body still croaks cleanly' => sub {
    my ($client, $io) = mock_client();
    $io->add(422, '["first problem","second problem"]');
    my $err = do { local $@; eval { $client->get('/x') }; $@ };
    like($err, qr{^Forgejo API error: 422}, 'status code in the message');
    unlike($err, qr{Not a HASH reference}, 'no Perl error leaks out');
};

subtest 'error with a JSON object body uses its message' => sub {
    my ($client, $io) = mock_client();
    $io->add(404, '{"message":"repo does not exist"}');
    my $err = do { local $@; eval { $client->get('/x') }; $@ };
    like($err, qr{^Forgejo API error: repo does not exist}, 'message');
};

subtest 'a non-JSON body is returned as it is' => sub {
    my ($client, $io) = mock_client();
    $io->add(200, "<h1>Hello</h1>\n", 'Content-Type' => 'text/html');
    is($client->post('/markdown', { Text => '# Hello' }), "<h1>Hello</h1>\n", 'raw content');

    $io->add(204, '');
    is($client->delete('/x'), undef, 'empty body yields undef');

    $io->add(200, '{"a":1}');
    is_deeply($client->get('/x'), { a => 1 }, 'JSON object still decoded');

    $io->add(200, '  [1,2]');
    is_deeply($client->get('/x'), [ 1, 2 ], 'JSON array still decoded');
};

subtest 'check: 2xx is true, 404 is false, anything else croaks' => sub {
    my ($client, $io) = mock_client();

    $io->add(204, '');
    is($client->check('/repos/o/r/collaborators/u'), 1, '204 => true');
    is($io->last->method, 'GET', 'check is a GET');

    $io->add(404, '{"message":"not found"}');
    is($client->check('/repos/o/r/collaborators/u'), 0, '404 => false');

    $io->add(500, '{"message":"boom"}');
    my $err = do { local $@; eval { $client->check('/x') }; $@ };
    like($err, qr{^Forgejo API error: boom}, '500 croaks');

    my ($anon) = mock_client(token => '');
    $err = do { local $@; eval { $anon->check('/x') }; $@ };
    like($err, qr{No API token configured}, 'check needs a token too');
};

subtest 'upload sends multipart/form-data' => sub {
    my ($client, $io) = mock_client();
    $io->add(201, '{"id":7,"name":"notes.txt"}');
    my $res = $client->post('/repos/o/r/releases/1/assets', undef,
        params => { name => 'notes.txt' },
        upload => { field => 'attachment', filename => 'notes.txt', content => "release notes\n" },
    );
    my $req = $io->last;
    is($req->method, 'POST', 'method');
    like($req->url, qr{/releases/1/assets\?name=notes\.txt$}, 'query string');
    like($req->headers->{'Content-Type'}, qr{^multipart/form-data; boundary=}, 'multipart content type');
    like($req->content, qr{name="attachment"; filename="notes\.txt"}, 'form field with filename');
    like($req->content, qr{release notes}, 'file content in the body');
    is($req->headers->{Authorization}, 'token test-token', 'still authenticated');
    is($res->{id}, 7, 'response decoded');
};

subtest 'upload from a file on disk' => sub {
    my ($client, $io) = mock_client();
    $io->add(201, '{}');
    $client->post('/x', undef, upload => { field => 'attachment', file => 't/fixtures/user.json' });
    my $req = $io->last;
    like($req->content, qr{filename="user\.json"}, 'filename taken from the path');
    like($req->content, qr{"login"}, 'file content in the body');
};

subtest 'a JSON request keeps its content type' => sub {
    my ($client, $io) = mock_client();
    $client->post('/x', { a => 1 });
    is($io->last->headers->{'Content-Type'}, 'application/json', 'content type');
    is_deeply(decode_json($io->last->content), { a => 1 }, 'body');
};

subtest 'no token croaks before any request' => sub {
    my ($client, $io) = mock_client(token => '');
    my $err = do { local $@; eval { $client->get('/x') }; $@ };
    like($err, qr{No API token configured}, 'croak');
    is($io->count, 0, 'nothing sent');
};

done_testing;
