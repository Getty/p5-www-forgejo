#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use HTTP::Response;
use IO::Compress::Gzip qw(gzip $GzipError);
use WWW::Forgejo;
use WWW::Forgejo::LWPIO;
use WWW::Forgejo::HTTPRequest;
use WWW::Forgejo::API::Repo::Issues;

# A stand-in for LWP::UserAgent: records the HTTP::Request objects it is given
# and answers with real HTTP::Response objects, headers included. This drives
# the default backend itself, not a mock IO.
{
    package FakeUA;
    sub new { bless { requests => [], responses => [] }, shift }
    sub add {
        my ($self, $code, $content, @headers) = @_;
        my %given = @headers;
        unshift @headers, 'Content-Type' => 'application/json' unless exists $given{'Content-Type'};
        push @{ $self->{responses} }, HTTP::Response->new($code, 'X', \@headers, $content);
    }
    sub request {
        my ($self, $req) = @_;
        push @{ $self->{requests} }, $req;
        return shift @{ $self->{responses} } || HTTP::Response->new(500, 'no response queued');
    }
}

subtest 'call passes method, url, headers and content to the user agent' => sub {
    my $ua = FakeUA->new;
    $ua->add(201, '{"id":1}');
    my $io = WWW::Forgejo::LWPIO->new(ua => $ua);

    my $res = $io->call(WWW::Forgejo::HTTPRequest->new(
        method  => 'POST',
        url     => 'https://forgejo.test/api/v1/user/repos',
        headers => { Authorization => 'token abc', 'Content-Type' => 'application/json' },
        content => '{"name":"x"}',
    ));

    my $sent = $ua->{requests}[0];
    is($sent->method, 'POST', 'method');
    is($sent->uri, 'https://forgejo.test/api/v1/user/repos', 'url');
    is($sent->header('Authorization'), 'token abc', 'authorization header');
    is($sent->content, '{"name":"x"}', 'content');

    isa_ok($res, 'WWW::Forgejo::HTTPResponse');
    is($res->status, 201, 'status');
    is($res->content, '{"id":1}', 'content');
};

subtest 'call copies the response headers' => sub {
    my $ua = FakeUA->new;
    $ua->add(200, '[]', 'X-Total-Count' => 42, 'Link' => '<a>; rel="next"');
    my $io = WWW::Forgejo::LWPIO->new(ua => $ua);

    my $res = $io->call(WWW::Forgejo::HTTPRequest->new(method => 'GET', url => 'https://forgejo.test/x'));

    is($res->headers->{'x-total-count'}, 42, 'X-Total-Count reaches the response object');
    is($res->headers->{'link'}, '<a>; rel="next"', 'other headers too');
    is($res->headers->{'content-type'}, 'application/json', 'content type too');
};

subtest 'a request without content sends none' => sub {
    my $ua = FakeUA->new;
    $ua->add(204, '');
    my $io = WWW::Forgejo::LWPIO->new(ua => $ua);
    my $res = $io->call(WWW::Forgejo::HTTPRequest->new(method => 'DELETE', url => 'https://forgejo.test/x'));
    is($ua->{requests}[0]->content, '', 'no content');
    is($res->status, 204, 'status');
    is($res->content, '', 'empty content');
};

subtest 'call hands on the body bytes, whatever charset the response declares' => sub {
    # Found against a live Forgejo 15: a UTF-8 text file read through
    # contents->raw came back as characters, not as the bytes of the file.
    my $ua    = FakeUA->new;
    my $bytes = "Gr\xc3\xbc\xc3\x9fe \xe2\x9c\x93\n";
    $ua->add(200, $bytes, 'Content-Type' => 'text/plain; charset=utf-8');
    my $io  = WWW::Forgejo::LWPIO->new(ua => $ua);
    my $res = $io->call(WWW::Forgejo::HTTPRequest->new(method => 'GET', url => 'https://forgejo.test/raw/a.txt'));
    is($res->content, $bytes, 'the bytes as sent');
    ok(!utf8::is_utf8($res->content), 'not decoded to characters');

    my $gzipped;
    gzip(\$bytes => \$gzipped) or die $GzipError;
    $ua->add(200, $gzipped, 'Content-Type' => 'text/plain; charset=utf-8', 'Content-Encoding' => 'gzip');
    $res = $io->call(WWW::Forgejo::HTTPRequest->new(method => 'GET', url => 'https://forgejo.test/raw/a.txt'));
    is($res->content, $bytes, 'a Content-Encoding is still undone');
};

subtest 'pagination works through the default backend' => sub {
    my $ua = FakeUA->new;
    $ua->add(200, '[{"id":1},{"id":2}]', 'X-Total-Count' => 5);
    $ua->add(200, '[{"id":3},{"id":4}]', 'X-Total-Count' => 5);
    $ua->add(200, '[{"id":5}]',          'X-Total-Count' => 5);

    my $client = WWW::Forgejo->new(
        url   => 'https://forgejo.test',
        token => 'test-token',
        io    => WWW::Forgejo::LWPIO->new(ua => $ua),
    );

    my $items = $client->get('/orgs');

    is_deeply([ map { $_->{id} } @$items ], [ 1 .. 5 ], 'all three pages merged in order');
    is(scalar @{ $ua->{requests} }, 3, 'three requests');
    like($ua->{requests}[1]->uri, qr{[?&]page=2(?:&|$)}, 'second request asks for page 2');
    like($ua->{requests}[1]->uri, qr{[?&]limit=2(?:&|$)}, 'second request keeps the page size');
    like($ua->{requests}[2]->uri, qr{[?&]page=3(?:&|$)}, 'third request asks for page 3');
};

subtest 'a controller list collects all pages through the default backend' => sub {
    my $ua = FakeUA->new;
    $ua->add(200, '[{"number":1},{"number":2}]', 'X-Total-Count' => 3);
    $ua->add(200, '[{"number":3}]',              'X-Total-Count' => 3);

    my $client = WWW::Forgejo->new(
        url   => 'https://forgejo.test',
        token => 'test-token',
        io    => WWW::Forgejo::LWPIO->new(ua => $ua),
    );
    my $issues = WWW::Forgejo::API::Repo::Issues->new(client => $client, owner => 'o', repo => 'r');
    my @issues = $issues->list(state => 'open');

    is_deeply([ map { $_->number } @issues ], [ 1, 2, 3 ], 'issues of both pages');
    like($ua->{requests}[1]->uri, qr{state=open}, 'filter kept on the follow-up page');
};

subtest 'default user agent' => sub {
    my $io = WWW::Forgejo::LWPIO->new(timeout => 7);
    isa_ok($io->ua, 'LWP::UserAgent');
    is($io->ua->timeout, 7, 'timeout handed to the user agent');
    like($io->ua->agent, qr{^WWW-Forgejo/}, 'agent string');
};

done_testing;
