#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use WWW::Forgejo;
use WWW::Forgejo::HTTPResponse;
use WWW::Forgejo::Role::IO;
use WWW::Forgejo::API::Repo::Labels;
use WWW::Forgejo::API::Repo::Contents;

# In-memory mock IO backend that records the requests it is handed.
{
    package Test::MockIO;
    use Moo;
    with 'WWW::Forgejo::Role::IO';

    our @requests;

    sub call {
        my ($self, $req) = @_;
        push @requests, $req;
        return WWW::Forgejo::HTTPResponse->new(
            status  => 200,
            content => '{"ok":1}',
            headers => {},
        );
    }
}

my $mock_io = Test::MockIO->new;
my $client  = WWW::Forgejo->new(
    url   => 'https://test.example',
    token => 'test-token',
    io    => $mock_io,
);

# A single owner value that carries a space, a slash, and a Latin-1 non-ASCII
# byte. All three must survive as percent-encoded forms, none as raw chars.
my $weird = "a b/c\xE4";    # space, slash, and 0xE4 (non-ASCII byte)

# The two kinds of non-ASCII text a name can carry: a character that still
# fits into a byte (U+00E4, here the byte 0xE4) and one that does not
# (U+65E5). Both have to reach the API as UTF-8 - the way the JSON body
# sends them - and neither may make the escaping croak.
my $latin1 = "\xE4";        # the character U+00E4
my $wide   = "\x{65E5}";    # a character above U+00FF

# ---------------------------------------------------------------------------
# _path_for helper: owner/repo path segments must be percent-encoded
# ---------------------------------------------------------------------------
subtest 'repo _path_for encodes owner and repo segments' => sub {
    my $labels = WWW::Forgejo::API::Repo::Labels->new(
        owner  => $weird,
        repo   => $weird,
        client => $client,
    );
    my $path = $labels->_path_for('42');

    like($path, qr/%20/, 'space encoded as %20');
    like($path, qr/%2F/i, 'slash within a segment encoded as %2F');
    like($path, qr/%C3%A4/i, 'non-ASCII character encoded as UTF-8');
    unlike($path, qr/a b/, 'raw space+text not present');
    like($path, qr{/labels/42\z}, 'trailing literal segment preserved unescaped');
    # The fixed "/repos/" ... "/labels/" scaffolding keeps its real slashes.
    like($path, qr{^/repos/}, 'leading /repos/ literal preserved');
};

subtest 'repo _path_for leaves plain ASCII owner/repo untouched' => sub {
    my $labels = WWW::Forgejo::API::Repo::Labels->new(
        owner  => 'octocat',
        repo   => 'hello',
        client => $client,
    );
    is(
        $labels->_path_for('42'),
        '/repos/octocat/hello/labels/42',
        'plain names unchanged, no stray encoding',
    );
};

# ---------------------------------------------------------------------------
# Non-ASCII characters: UTF-8, not Latin-1, and no croak above U+00FF
# ---------------------------------------------------------------------------
subtest 'path segments carry their non-ASCII characters as UTF-8' => sub {
    my $labels = WWW::Forgejo::API::Repo::Labels->new(
        owner  => $latin1,
        repo   => $wide,
        client => $client,
    );

    my $path = eval { $labels->_path_for('42') };
    diag $@ unless defined $path;
    ok(defined $path, 'a character above U+00FF does not make the escaping croak') or return;
    like($path, qr/%C3%A4/, 'the Latin-1 character goes out as UTF-8');
    like($path, qr/%E6%97%A5/, 'the wide character goes out as UTF-8');
    unlike($path, qr/%E4\b/, 'not as a single Latin-1 byte');
};

subtest 'query keys and values carry their non-ASCII characters as UTF-8' => sub {
    my $req = eval {
        $client->_build_request(
            'GET', '/repos/search',
            params => { 'q' => $latin1, $wide => 'value' },
        );
    };
    diag $@ unless $req;
    ok($req, 'a character above U+00FF does not make the escaping croak') or return;
    like($req->url, qr/q=%C3%A4/, 'the Latin-1 query value goes out as UTF-8');
    like($req->url, qr/%E6%97%A5=value/, 'the wide query key goes out as UTF-8');
};

subtest 'a method argument carries its non-ASCII characters as UTF-8' => sub {
    @Test::MockIO::requests = ();
    my $ok = eval { $client->users->get($wide); 1 };
    diag $@ unless $ok;
    ok($ok, 'a character above U+00FF does not make the escaping croak') or return;
    my $req = $Test::MockIO::requests[-1];
    like($req->url, qr{/users/%E6%97%A5\z}, 'the wide character goes out as UTF-8');
    unlike($req->url, qr{/users/\x{65E5}\z}, 'not as a raw character');
};

subtest 'a file path carries its non-ASCII characters as UTF-8' => sub {
    my $contents = WWW::Forgejo::API::Repo::Contents->new(
        owner  => 'octocat',
        repo   => 'hello',
        client => $client,
    );

    @Test::MockIO::requests = ();
    my $ok = eval { $contents->get("docs/\x{dc}bersicht.md"); 1 };
    diag $@ unless $ok;
    ok($ok, 'the Latin-1 character does not make the escaping croak') or return;
    like(
        $Test::MockIO::requests[-1]->url,
        qr{/docs/%C3%9Cbersicht\.md\z},
        'the Latin-1 character goes out as UTF-8',
    );

    @Test::MockIO::requests = ();
    $ok = eval { $contents->get("docs/\x{65e5}\x{672c}.md"); 1 };
    diag $@ unless $ok;
    ok($ok, 'a character above U+00FF does not make the escaping croak') or return;
    like(
        $Test::MockIO::requests[-1]->url,
        qr{/docs/%E6%97%A5%E6%9C%AC\.md\z},
        'the wide characters go out as UTF-8',
    );
};

# ---------------------------------------------------------------------------
# _build_request: GET query-param keys and values must be percent-encoded
# ---------------------------------------------------------------------------
subtest '_build_request encodes query params' => sub {
    my $req = $client->_build_request(
        'GET', '/repos/search',
        params => { 'q key' => 'a b/c' },
    );
    like($req->url, qr/q%20key=a%20b%2Fc/i, 'key and value both encoded');
    unlike($req->url, qr/q key/, 'raw space in key not present');
};

# ---------------------------------------------------------------------------
# Top-level controller: method-arg segment must be encoded in the built URL
# ---------------------------------------------------------------------------
subtest 'top-level controller encodes username segment' => sub {
    @Test::MockIO::requests = ();
    $client->users->get('weird user/name');
    my $req = $Test::MockIO::requests[-1];
    like($req->url, qr/%20/, 'space in username encoded');
    like($req->url, qr/%2F/i, 'slash in username encoded');
    unlike($req->url, qr{weird user}, 'raw space in username not present');
};

subtest 'top-level controller leaves plain ASCII username untouched' => sub {
    @Test::MockIO::requests = ();
    $client->users->get('octocat');
    my $req = $Test::MockIO::requests[-1];
    like($req->url, qr{/users/octocat\z}, 'plain username unchanged');
};

done_testing;
