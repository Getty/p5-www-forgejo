#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use MIME::Base64 qw(encode_base64);
use lib 'lib';
use WWW::Forgejo;

# Live test of the current user, users, notifications, packages, the
# miscellaneous endpoints and ActivityPub. Needs the token of an admin user. A
# throwaway user (with a token of its own, made through basic auth) follows the
# token user and opens an issue in a throwaway repository of the token user,
# which gives a notification to work with. Everything is named with the prefix
# below; leftovers of an earlier, aborted run are removed first, and
# everything is deleted at the end.

plan skip_all => 'TEST_FORGEJO_URL and TEST_FORGEJO_TOKEN required'
    unless $ENV{TEST_FORGEJO_URL} && $ENV{TEST_FORGEJO_TOKEN};

my $client = WWW::Forgejo->new(
    url   => $ENV{TEST_FORGEJO_URL},
    token => $ENV{TEST_FORGEJO_TOKEN},
);

my $PREFIX   = 'wfl97-';
my $NAME     = $PREFIX . $$;
my $USER     = $PREFIX . 'u' . $$;
my $PASSWORD = 'Live-Test-' . $$ . '!';
my $EMAIL    = $PREFIX . $$ . '@example.com';
my $HOOK_URL = 'http://127.0.0.1:9/' . $PREFIX . 'hook';
my $USER_KEY = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBpKEyuOdfQ+0EmAuN9VVb9i4ATvdRCyjB2CdW1hlJF0 wfl-live-user';
my $me       = $client->current_user->get;
my $OWNER    = $me->{login};

for my $old (@{ $client->current_user->repos }) {
    $client->repos->delete($OWNER, $old->{name}) if index($old->{name}, $PREFIX) == 0;
}
for my $old_user (@{ $client->admin->users->list }) {
    $client->admin->users->delete($old_user->{login}, purge => 'true') if index($old_user->{login}, $PREFIX) == 0;
}
for my $old_key (@{ $client->current_user->list_keys }) {
    $client->current_user->delete_key($old_key->{id}) if index($old_key->{title}, $PREFIX) == 0;
}
for my $old_hook (@{ $client->current_user->list_hooks }) {
    $client->current_user->delete_hook($old_hook->{id}) if ($old_hook->{config}{url} // '') eq $HOOK_URL;
}
for my $old_app (@{ $client->current_user->list_applications }) {
    $client->current_user->delete_application($old_app->{id}) if index($old_app->{name}, $PREFIX) == 0;
}
for my $old_email (@{ $client->current_user->list_emails }) {
    $client->current_user->delete_email($old_email->{email}) if index($old_email->{email}, $PREFIX) == 0;
}

END {
    if ($client) {
        eval { $client->repos->delete($OWNER, $NAME) };
        eval { $client->admin->users->delete($USER, purge => 'true') };
    }
}

$client->repos->create(name => $NAME, auto_init => \1, default_branch => 'main');
$client->admin->users->create(
    username             => $USER,
    email                => $USER . '@example.com',
    password             => $PASSWORD,
    must_change_password => \0,
);

# A token for the throwaway user. Creating one needs basic auth: swap the
# authentication of the client for the length of the block.
my ($token, $listed_tokens);
{
    no warnings 'redefine';
    local *WWW::Forgejo::_set_auth = sub { $_[1]{Authorization} = 'Basic ' . encode_base64("$USER:$PASSWORD", '') };
    $token         = $client->post("/users/$USER/tokens", { name => 'live', scopes => ['all'] });
    $listed_tokens = $client->users->tokens($USER);
}
my $other = WWW::Forgejo->new(url => $ENV{TEST_FORGEJO_URL}, token => $token->{sha1});

subtest 'a second user with a token of its own' => sub {
    ok($token->{sha1}, 'token created');
    is($listed_tokens->[0]{name}, 'live', 'users->tokens');
    is($other->current_user->get->{login}, $USER, 'the token works');
    my $mine = $client->users->tokens($OWNER);
    ok(scalar @$mine, 'users->tokens of the token user, with token auth');
};

# =============================================================================
# Current user
# =============================================================================

subtest 'settings' => sub {
    my $settings = $client->current_user->settings;
    ok(exists $settings->{description}, 'settings');
    my $before = $settings->{description};
    my $updated = $client->current_user->update_settings(description => 'set by t/97');
    is($updated->{description}, 'set by t/97', 'update_settings');
    $client->current_user->update_settings(description => $before);
    is($client->current_user->settings->{description}, $before, 'restored');
};

subtest 'emails' => sub {
    my $added = $client->current_user->add_email($EMAIL);
    ok((grep { $_->{email} eq $EMAIL } @$added), 'add_email answers with the addresses of the user');
    my %emails = map { ($_->{email} => $_) } @{ $client->current_user->list_emails };
    ok($emails{$EMAIL}, 'list_emails');
    ok(!$emails{$EMAIL}{primary}, 'not primary');
    $client->current_user->delete_email($EMAIL);
    %emails = map { ($_->{email} => 1) } @{ $client->current_user->list_emails };
    ok(!$emails{$EMAIL}, 'delete_email: DELETE with a body');
};

subtest 'keys' => sub {
    my $key = $client->current_user->create_key(title => $PREFIX . 'key', key => $USER_KEY);
    ok($key->{id}, 'create_key');
    is($client->current_user->get_key($key->{id})->{title}, $PREFIX . 'key', 'get_key');
    my %keys = map { ($_->{id} => 1) } @{ $client->current_user->list_keys };
    ok($keys{ $key->{id} }, 'list_keys');
    my %public = map { ($_->{id} => 1) } @{ $client->users->keys($OWNER) };
    ok($public{ $key->{id} }, 'users->keys');
    $client->current_user->delete_key($key->{id});
    ok(!eval { $client->current_user->get_key($key->{id}); 1 }, 'delete_key');
    is(ref $client->current_user->list_gpg_keys, 'ARRAY', 'list_gpg_keys');
    is(ref $client->users->gpg_keys($OWNER), 'ARRAY', 'users->gpg_keys');
};

subtest 'hooks' => sub {
    my $hook = $client->current_user->create_hook(
        type   => 'forgejo',
        config => { url => $HOOK_URL, content_type => 'json' },
        events => ['push'],
        active => \0,
    );
    ok($hook->{id}, 'create_hook');
    is($client->current_user->get_hook($hook->{id})->{config}{url}, $HOOK_URL, 'get_hook');
    ok($client->current_user->edit_hook($hook->{id}, active => \1)->{active}, 'edit_hook');
    my %hooks = map { ($_->{id} => 1) } @{ $client->current_user->list_hooks };
    ok($hooks{ $hook->{id} }, 'list_hooks');
    $client->current_user->delete_hook($hook->{id});
    ok(!eval { $client->current_user->get_hook($hook->{id}); 1 }, 'delete_hook');
};

subtest 'oauth2 applications' => sub {
    my $app = $client->current_user->create_application(
        name                => $PREFIX . 'app',
        redirect_uris       => ['http://localhost/callback'],
        confidential_client => \1,
    );
    ok($app->{id}, 'create_application');
    ok($app->{client_secret}, 'with a client secret');
    my %apps = map { ($_->{id} => 1) } @{ $client->current_user->list_applications };
    ok($apps{ $app->{id} }, 'list_applications');
    $client->current_user->delete_application($app->{id});
    %apps = map { ($_->{id} => 1) } @{ $client->current_user->list_applications };
    ok(!$apps{ $app->{id} }, 'delete_application');
};

subtest 'lists' => sub {
    my %repos = map { ($_->{name} => 1) } @{ $client->current_user->repos };
    ok($repos{$NAME}, 'repos');
    my %watched = map { ($_->{name} => 1) } @{ $client->current_user->subscriptions };
    ok($watched{$NAME}, 'subscriptions');
    is(ref $client->current_user->orgs,       'ARRAY', 'orgs');
    is(ref $client->current_user->teams,      'ARRAY', 'teams');
    is(ref $client->current_user->starred,    'ARRAY', 'starred');
    is(ref $client->current_user->stopwatches, 'ARRAY', 'stopwatches');
    is(ref $client->current_user->times,      'ARRAY', 'times');
    my $quota = $client->current_user->quota;
    ok(exists $quota->{used}, 'quota');
};

subtest 'follow, through the plain verbs' => sub {
    $other->put("/user/following/$OWNER");
    is($other->check("/user/following/$OWNER"), 1, 'the second user follows the token user');
    my %followers = map { ($_->{login} => 1) } @{ $client->current_user->followers };
    ok($followers{$USER}, 'current_user->followers');
    %followers = map { ($_->{login} => 1) } @{ $client->users->followers($OWNER) };
    ok($followers{$USER}, 'users->followers');
    my %following = map { ($_->{login} => 1) } @{ $client->users->following($USER) };
    ok($following{$OWNER}, 'users->following');
    is(ref $client->current_user->following, 'ARRAY', 'current_user->following');
    $other->delete("/user/following/$OWNER");
    is($other->check("/user/following/$OWNER"), 0, 'unfollowed');
};

subtest 'block' => sub {
    $client->current_user->block($USER);
    my %blocked = map { ($_->{block_id} => 1) } @{ $client->current_user->list_blocked };
    is(scalar keys %blocked, 1, 'block, list_blocked');
    $client->current_user->unblock($USER);
    is(scalar @{ $client->current_user->list_blocked }, 0, 'unblock');
};

subtest 'actions secrets, variables and runners of the user' => sub {
    $client->current_user->set_secret('WFL97_SECRET', { data => 's3cret' });
    pass('set_secret');
    $client->current_user->delete_secret('WFL97_SECRET');
    pass('delete_secret');
    is(ref $client->current_user->list_variables, 'ARRAY', 'list_variables');
    is(ref $client->current_user->list_runners,   'ARRAY', 'list_runners');
};

# =============================================================================
# Users
# =============================================================================

subtest 'users' => sub {
    my $user = $client->users->get($USER);
    is($user->{login}, $USER, 'get');
    my $found = $client->users->search(q => $USER);
    is($found->{data}[0]{login}, $USER, 'search');
    my %repos = map { ($_->{name} => 1) } @{ $client->users->repos($OWNER) };
    ok($repos{$NAME}, 'repos');
    is(ref $client->users->orgs($USER),          'ARRAY', 'orgs');
    is(ref $client->users->starred($USER),       'ARRAY', 'starred');
    is(ref $client->users->subscriptions($OWNER), 'ARRAY', 'subscriptions');
    is(ref $client->users->heatmap($OWNER),      'ARRAY', 'heatmap');
    my $feeds = $client->users->activities($OWNER, limit => 5);
    ok(scalar @$feeds, 'activities: creating a repository is one');
};

# =============================================================================
# Notifications
# =============================================================================

subtest 'notifications' => sub {
    my $issue = $other->post("/repos/$OWNER/$NAME/issues", { title => 'ping', body => "\@$OWNER have a look" });
    ok($issue->{number}, 'the second user opens an issue');

    my $threads = [];
    for (1 .. 15) {
        $threads = $client->notifications->list;
        last if @$threads;
        sleep 1;
    }
    is(scalar @$threads, 1, 'a notification for the token user');
    my $thread_id = $threads->[0]{id};
    is($threads->[0]{subject}{title}, 'ping', 'about the issue');
    ok($client->notifications->check->{new} >= 1, 'check counts it');

    is($client->notifications->get_thread($thread_id)->{id}, $thread_id, 'get_thread');
    is(scalar @{ $client->notifications->list_for_repo($OWNER, $NAME) }, 1, 'list_for_repo');

    my $read = $client->notifications->mark_read_thread($thread_id);
    ok(!$read->{unread}, 'mark_read_thread');
    is(scalar @{ $client->notifications->list }, 0, 'no unread notification left');
    is(scalar @{ $client->notifications->list(all => 'true') }, 1, 'but it is there with all');

    my $unread = $client->notifications->mark_read_repo($OWNER, $NAME, 'to-status' => 'unread', 'status-types' => 'read');
    is(ref $unread, 'ARRAY', 'mark_read_repo can mark it unread again');
    is(scalar @{ $client->notifications->list }, 1, 'unread again');
    $client->notifications->mark_read(all => 'true');
    is(scalar @{ $client->notifications->list }, 0, 'mark_read');
};

# =============================================================================
# Packages
# =============================================================================

subtest 'packages' => sub {
    # Uploading lives outside /api/v1; put the file there with the transport.
    my $base = $client->url . "/api/packages/$OWNER/generic/$NAME/1.0.0/hello.txt";
    $client->io->call(WWW::Forgejo::HTTPRequest->new(
        method  => 'PUT',
        url     => $base,
        headers => { Authorization => 'token ' . $ENV{TEST_FORGEJO_TOKEN} },
        content => "hello\n",
    ));
    my %packages = map { ($_->{name} => $_) } @{ $client->packages->list($OWNER, type => 'generic') };
    ok($packages{$NAME}, 'list');
    my $package = $client->packages->get($OWNER, 'generic', $NAME, '1.0.0');
    is($package->{version}, '1.0.0', 'get');
    my $files = $client->packages->files($OWNER, 'generic', $NAME, '1.0.0');
    is($files->[0]{name}, 'hello.txt', 'files');
    is($files->[0]{Size}, 6, 'with the size (the field is spelled Size)');
    $client->packages->delete($OWNER, 'generic', $NAME, '1.0.0');
    ok(!eval { $client->packages->get($OWNER, 'generic', $NAME, '1.0.0'); 1 }, 'delete');
};

# =============================================================================
# Misc
# =============================================================================

subtest 'misc' => sub {
    like($client->misc->version->{version}, qr/^\d+\.\d+/, 'version');
    my $nodeinfo = $client->misc->nodeinfo;
    is($nodeinfo->{software}{name}, 'forgejo', 'nodeinfo');

    like($client->misc->markdown(Text => "# Gr\x{fc}\x{df}e \x{2713}", Mode => 'markdown'),
        qr{<h1 [^>]*>Gr\x{fc}\x{df}e \x{2713}</h1>}, 'markdown: HTML as characters');
    like($client->misc->markup(Text => '*x*', Mode => 'markdown'), qr{<em>x</em>}, 'markup');

    ok(scalar @{ $client->misc->gitignore_templates }, 'gitignore_templates');
    ok(scalar @{ $client->misc->license_templates },   'license_templates');
    ok(scalar @{ $client->misc->label_templates },     'label_templates');
    for my $section (qw(api attachment repository ui)) {
        is(ref $client->misc->settings($section), 'HASH', "settings $section");
    }
    is(ref $client->misc->topics_search(q => 'beta')->{topics}, 'ARRAY', 'topics_search');

    my $gpg = $client->misc->signing_key;
    ok(!defined $gpg || $gpg =~ /BEGIN PGP PUBLIC KEY/, 'signing_key: none configured, or an armored key');
    my $ssh = eval { $client->misc->signing_key_ssh };
    ok(defined $ssh ? $ssh =~ /^ssh-/ : $@ =~ /^Forgejo API error: /, 'signing_key_ssh: a key, or a 404 without one');
};

subtest 'activitypub' => sub {
    # The ActivityPub endpoints want HTTP signatures, which this client does
    # not make; Forgejo turns an unsigned request away with a message.
    for my $call ([ actor => sub { $client->activitypub->actor($me->{id}) } ],
                  [ outbox => sub { $client->activitypub->outbox($me->{id}) } ],
                  [ inbox => sub { $client->activitypub->inbox($me->{id}, { type => 'Follow' }) } ]) {
        my ($name, $code) = @$call;
        my $result = eval { $code->() };
        if (defined $result) {
            ok(ref $result, "$name: answered without a signature");
        }
        else {
            like($@, qr/^Forgejo API error: request signature verification failed/, "$name: needs a signature");
        }
    }
};

done_testing;
