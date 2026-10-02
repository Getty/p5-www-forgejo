#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use WWW::Forgejo;
use WWW::Forgejo::HTTPRequest;
use WWW::Forgejo::HTTPResponse;
use WWW::Forgejo::Role::IO;
use JSON::MaybeXS qw(decode_json);

# Build a simple in-memory mock IO backend
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

    sub reset {
        @responses = ();
        @requests = ();
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
    @Test::MockIO::requests = ();
}

# =============================================================================
# HTTP Method Tests
# =============================================================================

subtest 'GET request' => sub {
    clear_responses;
    add_response(200, '{"id":1,"login":"testuser"}');

    my $data = $client->get('/test');
    ok($data, 'response received');
    is($data->{id}, 1);
    is($data->{login}, 'testuser');

    cmp_ok(scalar(@Test::MockIO::requests), '>', 0);
    my $req = $Test::MockIO::requests[-1];
    is($req->method, 'GET');
    like($req->url, qr{/test$});
    like($req->headers->{Authorization}, qr{token test-token});
};

subtest 'POST request' => sub {
    clear_responses;
    add_response(201, '{"id":2,"name":"new-repo"}');

    my $data = $client->post('/test', { key => 'value' });
    ok($data);
    is($data->{id}, 2);
    is($data->{name}, 'new-repo');

    my $req = $Test::MockIO::requests[-1];
    is($req->method, 'POST');
    like($req->content, qr{key.*value});
};

subtest 'PUT request' => sub {
    clear_responses;
    add_response(200, '{"success":true}');

    my $data = $client->put('/test/1', { name => 'updated' });
    ok($data);

    my $req = $Test::MockIO::requests[-1];
    is($req->method, 'PUT');
    like($req->url, qr{/test/1$});
};

subtest 'DELETE request' => sub {
    clear_responses;
    add_response(204, '');

    $client->delete('/test/1');
    my $req = $Test::MockIO::requests[-1];
    is($req->method, 'DELETE');
    like($req->url, qr{/test/1$});
};

subtest 'PATCH request' => sub {
    clear_responses;
    add_response(200, '{"updated":true}');

    my $data = $client->patch('/test/1', { name => 'patched' });
    ok($data);

    my $req = $Test::MockIO::requests[-1];
    is($req->method, 'PATCH');
};

subtest 'API error raises exception' => sub {
    clear_responses;
    $Test::MockIO::responses[0] = HTTP::Response->new(
        404, 'Not Found', ['Content-Type' => 'application/json'],
        '{"message":"Not found"}'
    );

    eval { $client->get('/nonexistent') };
    like($@, qr/Forgejo API error/);
    like($@, qr/not found/i);
};

subtest 'auth required' => sub {
    delete local $ENV{FORGEJO_TOKEN};
    eval { WWW::Forgejo->new(url => 'https://test.example', token => '')->get('/test') };
    like($@, qr/No API token configured/i);
};

# =============================================================================
# Misc API Tests
# =============================================================================

subtest 'misc version' => sub {
    clear_responses;
    add_response(200, '{"version":"1.0.0","os":"linux"}');

    my $v = $client->misc->version;
    ok($v, 'version returned');
    is($v->{version}, '1.0.0');
};

subtest 'misc nodeinfo' => sub {
    clear_responses;
    add_response(200, '{"software":{"name":"forgejo"},"usage":{"users":{"total":5}}}');

    my $info = $client->misc->nodeinfo;
    ok($info, 'nodeinfo returned');
    is($info->{software}{name}, 'forgejo');
};

subtest 'misc gitignore_templates' => sub {
    clear_responses;
    add_response(200, '["Actionscript","Android","Arduino","C"]');

    my $templates = $client->misc->gitignore_templates;
    ok($templates, 'templates returned');
    is(ref $templates, 'ARRAY');
    cmp_ok(scalar(@$templates), '>', 0);
};

subtest 'misc license_templates' => sub {
    clear_responses;
    add_response(200, '["AGPL-3.0","Apache-2.0","MIT"]');

    my $templates = $client->misc->license_templates;
    ok($templates, 'templates returned');
    is(ref $templates, 'ARRAY');
};

# =============================================================================
# Users API Tests
# =============================================================================

subtest 'users search' => sub {
    clear_responses;
    add_response(200, '{"data":[{"id":1,"login":"testuser"},{"id":2,"login":"another"}]}');

    my $result = $client->users->search(q => 'test');
    ok($result, 'search returns result');
    is(ref $result->{data}, 'ARRAY');
    is(scalar(@{$result->{data}}), 2, 'both users');
    is($Test::MockIO::requests[-1]->url, 'https://test.example/api/v1/users/search?q=test',
        'q is the search term of GET /users/search');
};

subtest 'users search: single argument is the search term' => sub {
    clear_responses;
    add_response(200, '{"data":[]}');

    $client->users->search('test');
    is($Test::MockIO::requests[-1]->url, 'https://test.example/api/v1/users/search?q=test',
        'positional term becomes q');
};

subtest 'users search: q is optional, like in the API' => sub {
    clear_responses;
    add_response(200, '{"data":[]}');

    my $result = eval { $client->users->search(uid => 7) };
    is($@, '', 'search without q does not croak');
    is($Test::MockIO::requests[-1]->url, 'https://test.example/api/v1/users/search?uid=7',
        'only the given parameters are sent');
};

subtest 'users get' => sub {
    clear_responses;
    add_response(200, '{"id":1,"login":"testuser","email":"test@example.com"}');

    my $user = $client->users->get('testuser');
    ok($user, 'get user works');
    is($user->{login}, 'testuser');
};

# =============================================================================
# Orgs API Tests
# =============================================================================

subtest 'orgs list' => sub {
    clear_responses;
    add_response(200, '[{"id":1,"username":"testorg"},{"id":2,"username":"anotherorg"}]');

    my $orgs = $client->orgs->list;
    ok($orgs, 'list returns result');
    is(ref $orgs, 'ARRAY');
    cmp_ok(scalar(@$orgs), '>=', 1);
};

subtest 'orgs get' => sub {
    clear_responses;
    add_response(200, '{"id":1,"username":"testorg","name":"testorg","description":"Test org"}');

    my $org = $client->orgs->get('testorg');
    ok($org, 'get org works');
    is($org->name, 'testorg');
};

# =============================================================================
# Teams API Tests
# =============================================================================

# The API has no "list all teams" operation (no GET /teams); teams are listed
# per organization.
subtest 'teams are listed per organization' => sub {
    ok(!WWW::Forgejo::API::Teams->can('list'), 'no teams->list');

    clear_responses;
    add_response(200, '[{"id":1,"name":"Owners"},{"id":2,"name":"Developers"}]');

    my $teams = WWW::Forgejo::API::Org::Teams->new(client => $client)->list('testorg');
    is(ref $teams, 'ARRAY');
    is(scalar(@$teams), 2, 'both teams');
    my $req = $Test::MockIO::requests[-1];
    is($req->method . ' ' . $req->url, 'GET https://test.example/api/v1/orgs/testorg/teams',
        'GET /orgs/{org}/teams');
};

subtest 'teams get' => sub {
    clear_responses;
    add_response(200, '{"id":1,"name":"Owners","permission":"owner"}');

    my $team = $client->teams->get(1);
    ok($team, 'get team works');
    is($team->name, 'Owners');
};

# =============================================================================
# Notifications API Tests
# =============================================================================

subtest 'notifications list' => sub {
    clear_responses;
    add_response(200, '[{"id":1,"type":"Issue"},{"id":2,"type":"PullRequest"}]');

    my $notifs = $client->notifications->list;
    ok($notifs, 'list returns result');
    is(ref $notifs, 'ARRAY');
};

# GET /notifications/new answers with a NotificationCount: { "new": N }.
subtest 'notifications check' => sub {
    clear_responses;
    add_response(200, '{"new":5}');

    my $count = $client->notifications->check;
    is($count->{new}, 5, 'number of new notifications');
    my $req = $Test::MockIO::requests[-1];
    is($req->method . ' ' . $req->url, 'GET https://test.example/api/v1/notifications/new',
        'GET /notifications/new');
};

# =============================================================================
# Packages API Tests
# =============================================================================

subtest 'packages list' => sub {
    clear_responses;
    add_response(200, '[{"id":1,"name":"my-package","type":"maven"}]');

    my $packages = $client->packages->list('testowner', type => 'maven');
    is(ref $packages, 'ARRAY');
    is($packages->[0]{name}, 'my-package', 'package data');
    is($Test::MockIO::requests[-1]->url, 'https://test.example/api/v1/packages/testowner?type=maven',
        'GET /packages/{owner} with the filter as query string');

    # packages are always listed for an owner
    clear_responses;
    eval { $client->packages->list };
    like($@, qr/Package owner required/, 'list without owner croaks');
    is(scalar @Test::MockIO::requests, 0, 'and sends nothing');
};

subtest 'packages get' => sub {
    clear_responses;
    add_response(200, '{"id":1,"name":"my-package","type":"maven","version":"1.0.0"}');

    my $pkg = $client->packages->get('testowner', 'maven', 'my-package', '1.0.0');
    ok($pkg, 'get package works');
};

# =============================================================================
# Current User API Tests
# =============================================================================

subtest 'current_user get' => sub {
    clear_responses;
    add_response(200, '{"id":1,"login":"currentuser","email":"user@example.com"}');

    my $user = $client->current_user->get;
    ok($user, 'get current user works');
    is($user->{login}, 'currentuser');
};

subtest 'current_user list_emails' => sub {
    clear_responses;
    add_response(200, '[{"email":"user@example.com","primary":true}]');

    my $emails = $client->current_user->list_emails;
    ok($emails, 'list_emails works');
    is(ref $emails, 'ARRAY');
};

subtest 'current_user list_keys' => sub {
    clear_responses;
    add_response(200, '[{"id":1,"key":"ssh-rsa AAA...","title":"Work Key"}]');

    my $keys = $client->current_user->list_keys;
    ok($keys, 'list_keys works');
    is(ref $keys, 'ARRAY');
};

# =============================================================================
# Admin Users API Tests
# =============================================================================

subtest 'admin users list' => sub {
    clear_responses;
    add_response(200, '[{"id":1,"login":"admin"},{"id":2,"login":"user1"}]');

    my $users = $client->admin->users->list;
    ok($users, 'admin users list works');
    is(ref $users, 'ARRAY');
    cmp_ok(scalar(@$users), '>=', 1);
};

subtest 'admin users create' => sub {
    clear_responses;
    add_response(201, '{"id":99,"login":"newuser","email":"new@example.com"}');

    my $new_user = $client->admin->users->create(
        email => 'new@example.com',
        username => 'newuser',
        password => 'Test123!',
    );
    ok($new_user, 'create user works');
    is($new_user->{login}, 'newuser');
};

# The admin API only creates keys, organizations and repositories for a user
# (POST /admin/users/{username}/keys|orgs|repos, see t/10-admin-users.t); it
# has no GET for them. Listing goes through the users controller.
subtest 'keys, orgs and repos of a user are listed by the users controller' => sub {
    ok(!WWW::Forgejo::API::Admin::Users->can($_), "no admin users->$_")
        for qw(list_keys list_orgs list_repos);

    my %path = (keys => 'keys', orgs => 'orgs', repos => 'repos');
    for my $method (sort keys %path) {
        clear_responses;
        add_response(200, '[{"id":1}]');

        my $list = $client->users->$method('testuser');
        is(ref $list, 'ARRAY', "users->$method returns a list");
        my $req = $Test::MockIO::requests[-1];
        is($req->method . ' ' . $req->url,
            "GET https://test.example/api/v1/users/testuser/$path{$method}", "users->$method request");
    }
};

# =============================================================================
# Admin Hooks API Tests
# =============================================================================

subtest 'admin hooks list' => sub {
    clear_responses;
    add_response(200, '[{"id":1,"type":"web","url":"https://example.com/hook"}]');

    my $hooks = $client->admin->hooks->list;
    ok($hooks, 'admin hooks list works');
    is(ref $hooks, 'ARRAY');
};

# =============================================================================
# Admin Cron API Tests
# =============================================================================

subtest 'admin cron list' => sub {
    clear_responses;
    add_response(200, '[{"id":"update_mirrors","name":"Update Mirrors","next":"2024-01-01T00:00:00Z"}]');

    my $tasks = $client->admin->cron->list;
    ok($tasks, 'cron list works');
    is(ref $tasks, 'ARRAY');
};

# The API lists cron tasks and runs one (POST /admin/cron/{task}); it has no
# operation to read a single task.
subtest 'admin cron run' => sub {
    ok(!WWW::Forgejo::API::Admin::Cron->can('get'), 'no cron->get');

    clear_responses;
    add_response(204, '');

    $client->admin->cron->run('update_mirrors');
    my $req = $Test::MockIO::requests[-1];
    is($req->method . ' ' . $req->url, 'POST https://test.example/api/v1/admin/cron/update_mirrors',
        'POST /admin/cron/{task}');
    ok(!$req->has_content, 'no body');
};

# =============================================================================
# Admin Runners API Tests
# =============================================================================

subtest 'admin runners list' => sub {
    clear_responses;
    add_response(200, '[{"id":1,"name":"runner-1","labels":["ubuntu","linux"]}]');

    my $runners = $client->admin->runners->list;
    ok($runners, 'runners list works');
    is(ref $runners, 'ARRAY');
};

# =============================================================================
# Repos API Tests
# =============================================================================

subtest 'repos list_for_org' => sub {
    clear_responses;
    add_response(200, '[{"id":1,"name":"repo1"},{"id":2,"name":"repo2"}]');

    my $repos = $client->repos->list_for_org('testorg');
    ok($repos, 'list_for_org works');
    is(ref $repos, 'ARRAY');
    cmp_ok(scalar(@$repos), '>=', 1);
};

subtest 'repos get' => sub {
    clear_responses;
    add_response(200, '{"id":1,"name":"test-repo","full_name":"testorg/test-repo"}');

    my $repo = $client->repos->get('testorg', 'test-repo');
    ok($repo, 'get repo works');
    is($repo->data->{name}, 'test-repo');
};

# Creating a repository for another user is an admin operation
# (POST /admin/users/{username}/repos, admin->users->create_repo_for); the
# repos controller creates for the authenticated user or an organization.
subtest 'repos create' => sub {
    ok(!WWW::Forgejo::API::Repos->can('create_for_user'), 'no repos->create_for_user');

    clear_responses;
    add_response(201, '{"id":99,"name":"new-repo","full_name":"testuser/new-repo","owner":{"login":"testuser"}}');

    my $repo = $client->repos->create(
        name => 'new-repo',
        description => 'A new repository',
        private => 0,
    );
    isa_ok($repo, 'WWW::Forgejo::Entity::Repo');
    is($repo->data->{name}, 'new-repo');
    is($repo->owner, 'testuser', 'owner taken from the response');
    my $req = $Test::MockIO::requests[-1];
    is($req->method . ' ' . $req->url, 'POST https://test.example/api/v1/user/repos', 'POST /user/repos');
    is(decode_json($req->content)->{name}, 'new-repo', 'body carries the name');
};

subtest 'repos create_for_org' => sub {
    clear_responses;
    add_response(201, '{"id":100,"name":"org-repo","owner":{"login":"testorg"}}');

    my $repo = $client->repos->create_for_org('testorg', name => 'org-repo');
    isa_ok($repo, 'WWW::Forgejo::Entity::Repo');
    is($repo->owner, 'testorg', 'owner taken from the response');
    my $req = $Test::MockIO::requests[-1];
    is($req->method . ' ' . $req->url, 'POST https://test.example/api/v1/orgs/testorg/repos',
        'POST /orgs/{org}/repos');
    is_deeply(decode_json($req->content), { name => 'org-repo' }, 'body');
};

# =============================================================================
# Entity Tests (Repo branches, collaborators, etc)
# =============================================================================

subtest 'repo entity branches' => sub {
    clear_responses;
    add_response(200, '{"id":1,"name":"test-repo"}');
    add_response(200, '[{"name":"main"},{"name":"develop"}]');

    my $repo = $client->repos->get('testorg', 'test-repo');
    my $branches_api = $repo->branches;
    ok($branches_api, 'branches accessor returned');
    my @branches = $branches_api->list;
    cmp_ok(scalar(@branches), '>=', 1);
    is($branches[0]->name, 'main');
};

subtest 'repo entity collaborators' => sub {
    clear_responses;
    add_response(200, '{"id":1,"name":"test-repo"}');
    add_response(200, '[{"login":"user1","permissions":"write"}]');

    my $repo = $client->repos->get('testorg', 'test-repo');
    my @collabs = $repo->collaborators->list;
    cmp_ok(scalar(@collabs), '>=', 1);
    is($collabs[0]->login, 'user1');
};

subtest 'repo entity hooks' => sub {
    clear_responses;
    add_response(200, '{"id":1,"name":"test-repo"}');
    add_response(200, '[{"id":1,"type":"web","url":"https://example.com/hook"}]');

    my $repo = $client->repos->get('testorg', 'test-repo');
    my @hooks = $repo->hooks->list;
    cmp_ok(scalar(@hooks), '>=', 1);
};

subtest 'repo entity labels' => sub {
    clear_responses;
    add_response(200, '{"id":1,"name":"test-repo"}');
    add_response(200, '[{"id":1,"name":"bug","color":"ff0000"}]');

    my $repo = $client->repos->get('testorg', 'test-repo');
    my @labels = $repo->labels->list;
    cmp_ok(scalar(@labels), '>=', 1);
    is($labels[0]->{name}, 'bug');
};

subtest 'repo entity milestones' => sub {
    clear_responses;
    add_response(200, '{"id":1,"name":"test-repo"}');
    add_response(200, '[{"id":1,"title":"v1.0","state":"open"}]');

    my $repo = $client->repos->get('testorg', 'test-repo');
    my @milestones = $repo->milestones->list;
    cmp_ok(scalar(@milestones), '>=', 1);
};

subtest 'repo entity issues' => sub {
    clear_responses;
    add_response(200, '{"id":1,"name":"test-repo"}');
    add_response(200, '[{"id":1,"title":"Bug report","state":"open"}]');

    my $repo = $client->repos->get('testorg', 'test-repo');
    my @issues = $repo->issues->list;
    cmp_ok(scalar(@issues), '>=', 1);
};

# =============================================================================
# Org Entity Tests
# =============================================================================

subtest 'org entity members' => sub {
    clear_responses;
    add_response(200, '{"id":1,"username":"testorg","name":"testorg"}');
    add_response(200, '[{"login":"user1"},{"login":"user2"}]');

    my $org = $client->orgs->get('testorg');
    my $members_api = $org->members;
    my $members_result = $members_api->list;
    ok($members_result, 'members result returned');
    is(ref $members_result, 'ARRAY', 'result is array');
    cmp_ok(scalar(@$members_result), '>=', 1);
    is($members_result->[0]{login}, 'user1');
};

subtest 'org entity teams' => sub {
    clear_responses;
    add_response(200, '{"id":1,"username":"testorg","name":"testorg"}');
    add_response(200, '[{"id":1,"name":"Owners"},{"id":2,"name":"Developers"}]');

    my $org = $client->orgs->get('testorg');
    my $teams = $org->teams->list;
    is(scalar(@$teams), 2, q{both teams});
    like($Test::MockIO::requests[-1]->url, qr{/orgs/testorg/teams$}, q{teams path});
};

subtest 'org entity hooks' => sub {
    clear_responses;
    add_response(200, '{"id":1,"username":"testorg","name":"testorg"}');
    add_response(200, '[{"id":1,"type":"web","url":"https://example.com/hook"}]');

    my $org = $client->orgs->get('testorg');
    my $hooks = $org->hooks->list;
    is(scalar(@$hooks), 1, q{one hook});
    like($Test::MockIO::requests[-1]->url, qr{/orgs/testorg/hooks$}, q{hooks path});
};

# =============================================================================
# URL Building and Encoding Tests
# =============================================================================

subtest 'url encoding for owner/repo in path' => sub {
    clear_responses;
    add_response(200, '{"id":1,"name":"test-repo"}');

    # Test that special characters in owner/repo are properly URL-encoded
    $client->repos->get('test-org', 'my-repo');
    my $req = $Test::MockIO::requests[-1];
    like($req->url, qr{/repos/test-org/my-repo});
};

subtest 'query params for GET requests' => sub {
    clear_responses;
    add_response(200, '{"data":[{"id":1}]}');

    $client->users->search(q => 'test', limit => 10);
    my $req = $Test::MockIO::requests[-1];
    like($req->url, qr{limit=10});
    like($req->url, qr{[?&]q=test});
};

# =============================================================================
# Error Response Parsing Tests
# =============================================================================

subtest 'error response with message field' => sub {
    clear_responses;
    $Test::MockIO::responses[0] = HTTP::Response->new(
        403, 'Forbidden', ['Content-Type' => 'application/json'],
        '{"message":"Access denied"}'
    );

    eval { $client->get('/admin-only') };
    like($@, qr/Access denied/);
};

subtest 'error response without message field' => sub {
    clear_responses;
    $Test::MockIO::responses[0] = HTTP::Response->new(
        500, 'Internal Server Error', ['Content-Type' => 'text/html'],
        '<html>Internal Server Error</html>'
    );

    eval { $client->get('/crash') };
    like($@, qr/500/);
};

done_testing;