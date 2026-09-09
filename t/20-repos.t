use strict;
use warnings;
use Test::More;
use lib 'lib';
use HTTP::Response;
use WWW::Forgejo;
use WWW::Forgejo::HTTPResponse;
use WWW::Forgejo::Role::IO;
use WWW::Forgejo::Entity::Repo;

# In-memory mock IO backend (mirrors t/02-http-mock.t).
{
    package Test::MockIO;
    use Moo;
    with 'WWW::Forgejo::Role::IO';

    our @responses;
    our @requests;

    sub call {
        my ($self, $req) = @_;
        push @requests, $req;
        my $res = shift @responses // HTTP::Response->new(500, 'No mock response');
        return WWW::Forgejo::HTTPResponse->new(
            status  => $res->code,
            content => $res->decoded_content // '',
            headers => { $res->headers->flatten },
        );
    }
}

my $mock_io = Test::MockIO->new;
my $client = WWW::Forgejo->new(
    url   => 'https://test.example',
    token => 'test-token',
    io    => $mock_io,
);

sub add_response {
    my ($code, $content, %headers) = @_;
    push @Test::MockIO::responses, HTTP::Response->new(
        $code, 'OK', ['Content-Type' => 'application/json', %headers],
        $content
    );
}

sub clear_responses {
    @Test::MockIO::responses = ();
    @Test::MockIO::requests  = ();
}

sub last_req { $Test::MockIO::requests[-1] }

my $repos = $client->repos;

# ===========================================================================
# Repos controller operations that t/02 omits.
# (t/02 already covers list_for_org, get, create_for_user.)
# ===========================================================================

subtest 'repos search' => sub {
    clear_responses;
    add_response(200,
        '{"ok":true,"data":[{"id":1,"name":"repo1"},{"id":2,"name":"repo2"}]}');

    my $res = $repos->search(query => 'test', limit => 5);
    ok($res->{ok}, 'search response ok flag');
    is(ref $res->{data}, 'ARRAY', 'data is arrayref');
    is(scalar @{$res->{data}}, 2, 'two results');

    my $req = last_req;
    is($req->method, 'GET', 'search => GET');
    like($req->url, qr{/repos/search}, 'search path');
    like($req->url, qr{query=test}, 'query param present');
    like($req->url, qr{limit=5}, 'limit param present');
};

subtest 'repos search (single positional query)' => sub {
    clear_responses;
    add_response(200, '{"ok":true,"data":[]}');

    $repos->search('needle');
    my $req = last_req;
    is($req->method, 'GET', 'positional search => GET');
    like($req->url, qr{query=needle}, 'odd arg becomes query param');
};

subtest 'repos create_from_template => Entity::Repo' => sub {
    clear_responses;
    add_response(201,
        '{"id":50,"name":"from-tpl","full_name":"me/from-tpl","owner":{"login":"me"}}');

    my $repo = $repos->create_from_template('tpl-owner', 'tpl-repo',
        name => 'from-tpl', owner => 'me');
    isa_ok($repo, 'WWW::Forgejo::Entity::Repo');
    is($repo->owner, 'me', 'entity owner from response owner.login');
    is($repo->repo, 'from-tpl', 'entity repo from response name');
    is($repo->data->{full_name}, 'me/from-tpl', 'data round-trips');

    my $req = last_req;
    is($req->method, 'POST', 'create_from_template => POST');
    like($req->url, qr{/repos/tpl-owner/tpl-repo/generate$}, 'generate path');
    like($req->content, qr{from-tpl}, 'body carries new name');
};

subtest 'repos migrate => Entity::Repo' => sub {
    clear_responses;
    add_response(201, '{"id":60,"name":"migrated","owner":{"login":"me"}}');

    my $repo = $repos->migrate(
        clone_addr => 'https://github.com/example/repo.git',
        repo_name  => 'migrated',
        repo_owner => 'me',
    );
    isa_ok($repo, 'WWW::Forgejo::Entity::Repo');
    is($repo->repo, 'migrated', 'migrated repo name');
    is($repo->owner, 'me', 'migrated owner');

    my $req = last_req;
    is($req->method, 'POST', 'migrate => POST');
    like($req->url, qr{/repos/migrations$}, 'migrations path');
    like($req->content, qr{clone_addr}, 'body carries clone_addr');
};

subtest 'repos delete' => sub {
    clear_responses;
    add_response(204, '');

    my $ok = $repos->delete('testorg', 'old-repo');
    is($ok, 1, 'delete returns 1');

    my $req = last_req;
    is($req->method, 'DELETE', 'delete => DELETE');
    like($req->url, qr{/repos/testorg/old-repo$}, 'delete path');
};

subtest 'repos transfer => Entity::Repo' => sub {
    clear_responses;
    add_response(200, '{"id":1,"name":"test-repo","owner":{"login":"newowner"}}');

    my $repo = $repos->transfer('testorg', 'test-repo', new_owner => 'newowner');
    isa_ok($repo, 'WWW::Forgejo::Entity::Repo');
    is($repo->owner, 'newowner', 'transferred to new owner');

    my $req = last_req;
    is($req->method, 'POST', 'transfer => POST');
    like($req->url, qr{/repos/testorg/test-repo/transfer$}, 'transfer path');
    like($req->content, qr{new_owner}, 'body carries new_owner');
};

subtest 'repos fork => Entity::Repo' => sub {
    clear_responses;
    add_response(202, '{"id":2,"name":"test-repo","owner":{"login":"me"}}');

    my $fork = $repos->fork('testorg', 'test-repo', organization => 'myorg');
    isa_ok($fork, 'WWW::Forgejo::Entity::Repo');
    is($fork->owner, 'me', 'fork owner');

    my $req = last_req;
    is($req->method, 'POST', 'fork => POST');
    like($req->url, qr{/repos/testorg/test-repo/forks$}, 'forks path');
    like($req->content, qr{organization}, 'body carries organization');
};

subtest 'repos generate (raw content)' => sub {
    clear_responses;
    add_response(201, '{"content":"README"}');

    my $r = $repos->generate('testorg', 'test-repo',
        filename => 'README.md', content => 'x');
    ok($r, 'generate returns data');

    my $req = last_req;
    is($req->method, 'POST', 'generate => POST');
    like($req->url, qr{/repos/testorg/test-repo/generate$}, 'generate path');
};

subtest 'repos mirror_sync' => sub {
    clear_responses;
    add_response(200, '{}');

    $repos->mirror_sync('testorg', 'test-repo');
    my $req = last_req;
    is($req->method, 'POST', 'mirror_sync => POST');
    like($req->url, qr{/repos/testorg/test-repo/mirror_sync$}, 'mirror_sync path');
    ok(!$req->has_content, 'mirror_sync sends no body');
};

subtest 'repos push_mirrors' => sub {
    clear_responses;
    add_response(200, '[{"remote_name":"backup","remote_address":"https://x/y.git"}]');

    my $mirrors = $repos->push_mirrors('testorg', 'test-repo');
    is(ref $mirrors, 'ARRAY', 'push_mirrors returns arrayref');
    is($mirrors->[0]{remote_name}, 'backup', 'mirror data');
    is(scalar @Test::MockIO::requests, 1, 'no X-Total-Count => single call');

    my $req = last_req;
    is($req->method, 'GET', 'push_mirrors => GET');
    like($req->url, qr{/repos/testorg/test-repo/push_mirrors$}, 'push_mirrors path');
};

subtest 'repos add_push_mirror' => sub {
    clear_responses;
    add_response(200, '{"remote_name":"backup"}');

    my $m = $repos->add_push_mirror('testorg', 'test-repo',
        remote_address => 'https://github.com/example/repo.git',
        remote_username => 'u');
    is($m->{remote_name}, 'backup', 'created mirror data');

    my $req = last_req;
    is($req->method, 'POST', 'add_push_mirror => POST');
    like($req->url, qr{/repos/testorg/test-repo/push_mirrors$}, 'add_push_mirror path');
    like($req->content, qr{remote_address}, 'body carries remote_address');
};

subtest 'repos delete_push_mirror' => sub {
    clear_responses;
    add_response(204, '');

    my $ok = $repos->delete_push_mirror('testorg', 'test-repo', 'backup');
    is($ok, 1, 'delete_push_mirror returns 1');

    my $req = last_req;
    is($req->method, 'DELETE', 'delete_push_mirror => DELETE');
    like($req->url, qr{/repos/testorg/test-repo/push_mirrors/backup$}, 'delete_push_mirror path');
};

# ===========================================================================
# Entity::Repo round-trip: data, sub-resource controller types, update, delete.
# ===========================================================================

subtest 'Entity::Repo data + sub-resource accessors (direct construction)' => sub {
    my $repo = WWW::Forgejo::Entity::Repo->new(
        client => $client,
        owner  => 'testorg',
        repo   => 'test-repo',
        data   => {
            id => 1, name => 'test-repo', full_name => 'testorg/test-repo',
            description => 'a repo',
        },
    );
    is($repo->client, $client, 'weak client ref stays populated');
    is($repo->owner, 'testorg', 'owner');
    is($repo->repo, 'test-repo', 'repo');
    is($repo->data->{full_name}, 'testorg/test-repo', 'data accessor');
    like($repo->data_json, qr{test-repo}, 'data_json serializes');

    isa_ok($repo->branches, 'WWW::Forgejo::API::Repo::Branches');
    isa_ok($repo->issues, 'WWW::Forgejo::API::Repo::Issues');
    isa_ok($repo->pulls, 'WWW::Forgejo::API::Repo::PullRequests');
    isa_ok($repo->releases, 'WWW::Forgejo::API::Repo::Releases');
    isa_ok($repo->labels, 'WWW::Forgejo::API::Repo::Labels');

    is($repo->branches->owner, 'testorg', 'sub-resource carries owner');
    is($repo->pulls->repo, 'test-repo', 'sub-resource carries repo');
};

subtest 'Entity::Repo update (PATCH)' => sub {
    clear_responses;
    add_response(200, '{"id":1,"name":"test-repo","description":"updated"}');

    my $repo = WWW::Forgejo::Entity::Repo->new(
        client => $client, owner => 'testorg', repo => 'test-repo',
        data => { name => 'test-repo', description => 'old' },
    );
    my $updated = $repo->update({ description => 'updated' });
    isa_ok($updated, 'WWW::Forgejo::Entity::Repo');
    is($updated->data->{description}, 'updated', 'updated description in returned entity');

    my $req = last_req;
    is($req->method, 'PATCH', 'update => PATCH');
    like($req->url, qr{/repos/testorg/test-repo$}, 'update path');
    like($req->content, qr{updated}, 'body carries new description');
};

subtest 'Entity::Repo delete (DELETE)' => sub {
    clear_responses;
    add_response(204, '');

    my $repo = WWW::Forgejo::Entity::Repo->new(
        client => $client, owner => 'testorg', repo => 'test-repo',
        data => { name => 'test-repo' },
    );
    is($repo->delete, 1, 'delete returns 1');

    my $req = last_req;
    is($req->method, 'DELETE', 'delete => DELETE');
    like($req->url, qr{/repos/testorg/test-repo$}, 'delete path');
};

done_testing;
