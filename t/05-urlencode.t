use strict;
use warnings;
use Test::More;
use lib 'lib';
use WWW::Forgejo;
use WWW::Forgejo::HTTPResponse;
use WWW::Forgejo::Role::IO;
use WWW::Forgejo::API::Repo::Labels;

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
    like($path, qr/%E4/i, 'non-ASCII byte encoded as %E4');
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
