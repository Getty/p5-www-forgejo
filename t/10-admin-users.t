#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);

# Admin::Users against the Swagger document: verb, path, query string and
# JSON body of every operation. (t/02 covers list and create.)

my ($client, $io) = mock_client();
my $base  = 'https://forgejo.test/api/v1';
my $users = $client->admin->users;

sub request { $io->last->method . ' ' . $io->last->url }
sub body    { decode_json($io->last->content) }

# The admin API has no GET /admin/users/{username}; a single user is read
# through the users controller.
subtest 'a single user is read through users->get' => sub {
    ok(!WWW::Forgejo::API::Admin::Users->can('get'), 'no admin users->get');

    $io->reset->add(200, '{"id":1,"login":"someuser","email":"s@e.com"}');
    my $u = $client->users->get('someuser');
    is($u->{login}, 'someuser', 'users->get returns user data');
    is(request(), "GET $base/users/someuser", 'GET /users/{username}');
};

subtest 'admin users list forwards its filters' => sub {
    $io->reset->add(200, '[{"id":1,"login":"a"}]');
    my $list = $users->list(login_name => 'a', limit => 5);
    is($list->[0]{login}, 'a', 'list returns user data');
    is(request(), "GET $base/admin/users?limit=5&login_name=a", 'GET /admin/users with query string');
};

# PATCH /admin/users/{username} with an EditUserOption body.
subtest 'admin users edit' => sub {
    $io->reset->add(200, '{"id":1,"login":"someuser","admin":true}');

    my $u = $users->edit('someuser', login_name => 'someuser', admin => \1);
    is($u->{login}, 'someuser', 'edit returns user data');
    is(request(), "PATCH $base/admin/users/someuser", 'PATCH /admin/users/{username}');
    is_deeply(body(), { login_name => 'someuser', admin => JSON::MaybeXS::true }, 'body');
};

subtest 'admin users delete' => sub {
    $io->reset->add(204, '');
    $users->delete('someuser');
    is(request(), "DELETE $base/admin/users/someuser", 'DELETE /admin/users/{username}');
    ok(!$io->last->has_content, 'no body');

    $io->reset->add(204, '');
    $users->delete('someuser', purge => 'true');
    is(request(), "DELETE $base/admin/users/someuser?purge=true", 'purge goes into the query string');
    ok(!$io->last->has_content, 'still no body');
};

subtest 'admin users delete method matches its POD' => sub {
    ok( WWW::Forgejo::API::Admin::Users->can('delete'),
        'delete method exists' );
    ok( !WWW::Forgejo::API::Admin::Users->can('delete_user'),
        'no stray delete_user method' );
};

# POST /admin/users/{username}/rename with RenameUserOption { new_username }.
subtest 'admin users rename' => sub {
    $io->reset->add(204, '');

    $users->rename('oldname', 'newname');
    is(request(), "POST $base/admin/users/oldname/rename", 'POST /admin/users/{username}/rename');
    is_deeply(body(), { new_username => 'newname' }, 'body carries new_username');
};

# Emails of a user can be listed and deleted, not added: the API has no
# POST /admin/users/{username}/emails.
subtest 'admin users list_emails' => sub {
    ok(!WWW::Forgejo::API::Admin::Users->can('add_email'), 'no add_email');

    $io->reset->add(200, '[{"email":"s@e.com","primary":true}]');
    my $emails = $users->list_emails('someuser');
    is($emails->[0]{email}, 's@e.com', 'list_emails returns the emails');
    is(request(), "GET $base/admin/users/someuser/emails", 'GET /admin/users/{username}/emails');
};

# DELETE /admin/users/{username}/emails with DeleteEmailOption { emails }.
subtest 'admin users delete_email sends the addresses as body' => sub {
    $io->reset->add(204, '');

    $users->delete_email('someuser', 'old@e.com', 'older@e.com');
    is(request(), "DELETE $base/admin/users/someuser/emails", 'DELETE /admin/users/{username}/emails');
    is_deeply(body(), { emails => ['old@e.com', 'older@e.com'] }, 'body lists the emails');
};

subtest 'admin users search_emails' => sub {
    $io->reset->add(200, '[{"email":"s@e.com","username":"someuser"}]');

    my $r = $users->search_emails(q => 'example');
    is(ref $r, 'ARRAY', 'search_emails returns arrayref');
    is(request(), "GET $base/admin/emails/search?q=example", 'GET /admin/emails/search');
};

subtest 'admin users add_key' => sub {
    $io->reset->add(201, '{"id":9,"key":"ssh-rsa AAA","title":"my key"}');

    my $k = $users->add_key('someuser', title => 'my key', key => 'ssh-rsa AAA');
    is($k->{id}, 9, 'add_key returns key data');
    is(request(), "POST $base/admin/users/someuser/keys", 'POST /admin/users/{username}/keys');
    is_deeply(body(), { title => 'my key', key => 'ssh-rsa AAA' }, 'body');
};

subtest 'admin users delete_key' => sub {
    $io->reset->add(204, '');

    $users->delete_key('someuser', 9);
    is(request(), "DELETE $base/admin/users/someuser/keys/9", 'DELETE /admin/users/{username}/keys/{id}');
};

subtest 'admin users create_org_for' => sub {
    $io->reset->add(201, '{"id":3,"name":"neworg","username":"neworg"}');

    my $o = $users->create_org_for('someuser', username => 'neworg');
    is($o->{name}, 'neworg', 'create_org_for returns org data');
    is(request(), "POST $base/admin/users/someuser/orgs", 'POST /admin/users/{username}/orgs');
    is_deeply(body(), { username => 'neworg' }, 'body');
};

subtest 'admin users create_repo_for' => sub {
    $io->reset->add(201, '{"id":4,"name":"newrepo"}');

    my $r = $users->create_repo_for('someuser', name => 'newrepo');
    is($r->{name}, 'newrepo', 'create_repo_for returns repo data');
    is(request(), "POST $base/admin/users/someuser/repos", 'POST /admin/users/{username}/repos');
    is_deeply(body(), { name => 'newrepo' }, 'body');
};

subtest 'admin users quota' => sub {
    $io->reset->add(200, '{"used":{"size":{"all":100}},"groups":[]}');

    my $q = $users->quota('someuser');
    is($q->{used}{size}{all}, 100, 'quota returns data');
    is(request(), "GET $base/admin/users/someuser/quota", 'GET /admin/users/{username}/quota');
};

# POST /admin/users/{username}/quota/groups with
# SetUserQuotaGroupsOptions { groups }.
subtest 'admin users set_quota_groups' => sub {
    ok(!WWW::Forgejo::API::Admin::Users->can('add_to_quota_group'), 'no add_to_quota_group');

    $io->reset->add(204, '');
    $users->set_quota_groups('someuser', 'premium', 'staff');
    is(request(), "POST $base/admin/users/someuser/quota/groups", 'POST /admin/users/{username}/quota/groups');
    is_deeply(body(), { groups => ['premium', 'staff'] }, 'body lists the groups');
};

subtest 'path segments are escaped' => sub {
    $io->reset->add(204, '');
    $users->delete('some user/x');
    is(request(), "DELETE $base/admin/users/some%20user%2Fx", 'username escaped');
};

done_testing;
