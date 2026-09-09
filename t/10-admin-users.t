use strict;
use warnings;
use Test::More;
use lib 'lib';
use HTTP::Response;
use WWW::Forgejo;
use WWW::Forgejo::HTTPResponse;
use WWW::Forgejo::Role::IO;

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

my $users = $client->admin->users;

# ===========================================================================
# Admin::Users operations that t/02 omits.
# (t/02 already covers list, create, list_keys, list_orgs, list_repos.)
# ===========================================================================

subtest 'admin users get' => sub {
    clear_responses;
    add_response(200, '{"id":1,"login":"someuser","email":"s@e.com"}');

    my $u = $users->get('someuser');
    is($u->{login}, 'someuser', 'get returns user data');

    my $req = last_req;
    is($req->method, 'GET', 'get => GET');
    # NOTE: admin->users->get hits the public /users/:name endpoint,
    # not /admin/users/:name (Forgejo has no admin GET-one endpoint).
    like($req->url, qr{/users/someuser$}, 'get path is /users/:name');
    unlike($req->url, qr{/admin/users/someuser}, 'get does NOT use /admin/users path');
};

subtest 'admin users edit' => sub {
    clear_responses;
    add_response(200, '{"id":1,"login":"someuser","admin":true}');

    my $u = $users->edit('someuser', login_name => 'someuser', admin => 1);
    is($u->{login}, 'someuser', 'edit returns user data');

    my $req = last_req;
    is($req->method, 'PUT', 'edit => PUT');
    like($req->url, qr{/admin/users/someuser$}, 'edit path');
    like($req->content, qr{"admin"}, 'body carries admin key');
};

subtest 'admin users delete_user' => sub {
    clear_responses;
    add_response(204, '');

    # The delete method is named delete_user (see BUG note below).
    $users->delete_user('someuser');
    my $req = last_req;
    is($req->method, 'DELETE', 'delete_user => DELETE');
    like($req->url, qr{/admin/users/someuser$}, 'delete_user path');
};

subtest 'admin users delete method-name mismatch (documents current behavior)' => sub {
    # BUG: the POD documents the method as `delete`, but the sub is named
    # `delete_user`, and the class does not extend Entity, so there is no
    # `delete` method. Asserting current behavior; reported, not fixed.
    ok( WWW::Forgejo::API::Admin::Users->can('delete_user'),
        'delete_user method exists' );
    ok( !WWW::Forgejo::API::Admin::Users->can('delete'),
        'no delete method despite POD documenting delete()' );
};

subtest 'admin users rename' => sub {
    clear_responses;
    add_response(200, '{"id":1,"login":"newname"}');

    my $u = $users->rename('oldname', 'newname');
    is($u->{login}, 'newname', 'rename returns renamed user');

    my $req = last_req;
    is($req->method, 'POST', 'rename => POST');
    like($req->url, qr{/admin/users/oldname/rename$}, 'rename path');
    like($req->content, qr{"new_name"}, 'body carries new_name key');
    like($req->content, qr{newname}, 'body carries new name value');
};

subtest 'admin users add_email' => sub {
    clear_responses;
    add_response(201, '[{"email":"new@e.com","primary":false}]');

    my $r = $users->add_email('someuser', 'new@e.com');
    is(ref $r, 'ARRAY', 'add_email returns email list');

    my $req = last_req;
    is($req->method, 'POST', 'add_email => POST');
    like($req->url, qr{/admin/users/someuser/emails$}, 'add_email path');
    like($req->content, qr{"email"}, 'body carries email key');
    like($req->content, qr{new\@e\.com}, 'body carries email value');
};

subtest 'admin users delete_email (URL-encoded segment)' => sub {
    clear_responses;
    add_response(204, '');

    $users->delete_email('someuser', 'old@e.com');
    my $req = last_req;
    is($req->method, 'DELETE', 'delete_email => DELETE');
    # @ is percent-encoded (%40) in the path segment (ticket #4).
    like($req->url, qr{/admin/users/someuser/emails/old%40e\.com$},
        'email path segment is URL-encoded');
};

subtest 'admin users search_emails' => sub {
    clear_responses;
    add_response(200, '[{"email":"s@e.com","username":"someuser"}]');

    my $r = $users->search_emails(q => 'example');
    is(ref $r, 'ARRAY', 'search_emails returns arrayref');

    my $req = last_req;
    is($req->method, 'GET', 'search_emails => GET');
    like($req->url, qr{/admin/users/emails/search}, 'search_emails path');
    like($req->url, qr{q=example}, 'query param present');
};

subtest 'admin users add_key' => sub {
    clear_responses;
    add_response(201, '{"id":9,"key":"ssh-rsa AAA","title":"my key"}');

    my $k = $users->add_key('someuser', title => 'my key', key => 'ssh-rsa AAA');
    is($k->{id}, 9, 'add_key returns key data');

    my $req = last_req;
    is($req->method, 'POST', 'add_key => POST');
    like($req->url, qr{/admin/users/someuser/keys$}, 'add_key path');
    like($req->content, qr{ssh-rsa}, 'body carries key');
};

subtest 'admin users delete_key' => sub {
    clear_responses;
    add_response(204, '');

    $users->delete_key('someuser', 9);
    my $req = last_req;
    is($req->method, 'DELETE', 'delete_key => DELETE');
    like($req->url, qr{/admin/users/someuser/keys/9$}, 'delete_key path');
};

subtest 'admin users create_org_for' => sub {
    clear_responses;
    add_response(201, '{"id":3,"username":"neworg"}');

    my $o = $users->create_org_for('someuser', username => 'neworg');
    is($o->{username}, 'neworg', 'create_org_for returns org data');

    my $req = last_req;
    is($req->method, 'POST', 'create_org_for => POST');
    like($req->url, qr{/admin/users/someuser/orgs$}, 'create_org_for path');
    like($req->content, qr{neworg}, 'body carries org username');
};

subtest 'admin users create_repo_for' => sub {
    clear_responses;
    add_response(201, '{"id":4,"name":"newrepo"}');

    my $r = $users->create_repo_for('someuser', name => 'newrepo');
    is($r->{name}, 'newrepo', 'create_repo_for returns repo data');

    my $req = last_req;
    is($req->method, 'POST', 'create_repo_for => POST');
    like($req->url, qr{/admin/users/someuser/repos$}, 'create_repo_for path');
    like($req->content, qr{newrepo}, 'body carries repo name');
};

subtest 'admin users quota' => sub {
    clear_responses;
    add_response(200, '{"used":{"size":100},"limit":1000}');

    my $q = $users->quota('someuser');
    ok($q, 'quota returns data');
    is($q->{limit}, 1000, 'quota limit');

    my $req = last_req;
    is($req->method, 'GET', 'quota => GET');
    like($req->url, qr{/admin/users/someuser/quota$}, 'quota path');
};

subtest 'admin users add_to_quota_group' => sub {
    clear_responses;
    add_response(204, '');

    $users->add_to_quota_group('someuser', 'premium');
    my $req = last_req;
    is($req->method, 'POST', 'add_to_quota_group => POST');
    like($req->url, qr{/admin/users/someuser/quota/group$}, 'quota group path');
    like($req->content, qr{"group_name"}, 'body carries group_name key');
    like($req->content, qr{premium}, 'body carries group value');
};

done_testing;
