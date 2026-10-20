#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);
use WWW::Forgejo::API::Repos;
use WWW::Forgejo::API::Repo::Contents;
use WWW::Forgejo::API::Repo::Hooks;
use WWW::Forgejo::API::Repo::Git;
use WWW::Forgejo::API::Repo::Wiki;

# The endpoints of the repository itself the client did not cover yet: the
# editing of a repository, its avatar, its activity feed, the commits, the
# comparison of two references, the issue configuration, the templates, the
# languages, the push mirrors, the signing key, the synchronisation of a fork
# and the transfer of the repository.
#
# Every call is made in an eval, so a method that does not exist shows up as a
# failed test instead of a dead file.

my ($client, $io) = mock_client();
my $base = 'https://forgejo.test/api/v1';

my $repos = WWW::Forgejo::API::Repos->new(client => $client);
my $contents = WWW::Forgejo::API::Repo::Contents->new(client => $client, owner => 'owner', repo => 'repo');
my $hooks   = WWW::Forgejo::API::Repo::Hooks->new(client => $client, owner => 'owner', repo => 'repo');
my $git     = WWW::Forgejo::API::Repo::Git->new(client => $client, owner => 'owner', repo => 'repo');
my $wiki    = WWW::Forgejo::API::Repo::Wiki->new(client => $client, owner => 'owner', repo => 'repo');

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

sub url {
    my $last = $io->last or return '';
    return $last->url;
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
# The repository itself
# ---------------------------------------------------------------------------

subtest 'the repository is edited' => sub {
    $io->reset->add(200, '{"name":"repo","owner":{"login":"owner"}}');
    my $repo = value(sub { $repos->edit('owner', 'repo', description => 'A new description') });
    is(request(), 'PATCH /repos/owner/repo', 'PATCH /repos/{owner}/{repo}');
    is(body()->{description}, 'A new description', 'the description is sent in the body');
    isa_ok($repo, 'WWW::Forgejo::Entity::Repo', 'edit');
};

subtest 'the avatar of the repository' => sub {
    $io->reset->add(200, '{}');
    my $set = value(sub { $repos->set_avatar('owner', 'repo', image => 'YmFzZTY0') });
    is(request(), 'POST /repos/owner/repo/avatar', 'POST /repos/{owner}/{repo}/avatar');
    is(body()->{image}, 'YmFzZTY0', 'the image is sent in the body');
    ok($set, 'set_avatar returns true');

    $io->reset->add(204, '');
    my $deleted = value(sub { $repos->delete_avatar('owner', 'repo') });
    is(request(), 'DELETE /repos/owner/repo/avatar', 'DELETE /repos/{owner}/{repo}/avatar');
    ok($deleted, 'delete_avatar returns true');

    like(error(sub { $repos->set_avatar('owner', 'repo') }), qr/Avatar image required/,
        'set_avatar needs an image');
};

subtest 'the activity feed of the repository' => sub {
    $io->reset->add(200, '[]');
    my $feed = value(sub { $repos->activities('owner', 'repo') });
    is(request(), 'GET /repos/owner/repo/activities/feeds',
        'GET /repos/{owner}/{repo}/activities/feeds');
    is(ref $feed, 'ARRAY', 'activities returns an arrayref');
};

subtest 'the commits of the repository' => sub {
    $io->reset->add(200, '[]');
    my $commits = value(sub { $repos->commits('owner', 'repo', sha => 'main') });
    is(request(), 'GET /repos/owner/repo/commits', 'GET /repos/{owner}/{repo}/commits');
    like(url(), qr/sha=main/, 'the named arguments are sent as the query string');
    is(ref $commits, 'ARRAY', 'commits returns an arrayref');

    $io->reset->add(200, '{}');
    my $pull = value(sub { $repos->commit_pull('owner', 'repo', 'abc123') });
    is(request(), 'GET /repos/owner/repo/commits/abc123/pull',
        'GET /repos/{owner}/{repo}/commits/{sha}/pull');
    is(ref $pull, 'HASH', 'commit_pull returns the plain pull request');

    $io->reset->add(200, '[]');
    my $statuses = value(sub { $repos->commit_statuses('owner', 'repo', 'abc123') });
    is(request(), 'GET /repos/owner/repo/commits/abc123/statuses',
        'GET /repos/{owner}/{repo}/commits/{ref}/statuses');
    is(ref $statuses, 'ARRAY', 'commit_statuses returns an arrayref');
};

subtest 'two references are compared' => sub {
    $io->reset->add(200, '{}');
    my $comparison = value(sub { $repos->compare('owner', 'repo', 'main...feature') });
    is(request(), 'GET /repos/owner/repo/compare/main...feature',
        'GET /repos/{owner}/{repo}/compare/{basehead}');
    is(ref $comparison, 'HASH', 'compare returns the plain comparison');
};

subtest 'the editor configuration of a file' => sub {
    $io->reset->add(200, '{}');
    my $config = value(sub { $repos->editorconfig('owner', 'repo', 'src/main.pl', ref => 'main') });
    is(request(), 'GET /repos/owner/repo/editorconfig/src/main.pl',
        'GET /repos/{owner}/{repo}/editorconfig/{filepath}');
    like(url(), qr/ref=main/, 'the named arguments are sent as the query string');
    is(ref $config, 'HASH', 'editorconfig returns the plain configuration');
};

subtest 'the issue configuration of the repository' => sub {
    $io->reset->add(200, '{"config":[]}');
    my $config = value(sub { $repos->issue_config('owner', 'repo') });
    is(request(), 'GET /repos/owner/repo/issue_config', 'GET /repos/{owner}/{repo}/issue_config');
    is(ref $config, 'HASH', 'issue_config returns the plain configuration');

    $io->reset->add(200, '{"valid":true}');
    my $valid = value(sub { $repos->validate_issue_config('owner', 'repo') });
    is(request(), 'GET /repos/owner/repo/issue_config/validate',
        'GET /repos/{owner}/{repo}/issue_config/validate');
    is(ref $valid, 'HASH', 'validate_issue_config returns the plain answer');

    $io->reset->add(200, '[]');
    my $templates = value(sub { $repos->issue_templates('owner', 'repo') });
    is(request(), 'GET /repos/owner/repo/issue_templates', 'GET /repos/{owner}/{repo}/issue_templates');
    is(ref $templates, 'ARRAY', 'issue_templates returns an arrayref');
};

subtest 'the languages of the repository' => sub {
    $io->reset->add(200, '{"Perl":100}');
    my $languages = value(sub { $repos->languages('owner', 'repo') });
    is(request(), 'GET /repos/owner/repo/languages', 'GET /repos/{owner}/{repo}/languages');
    is($languages->{Perl}, 100, 'the share of the language');
};

subtest 'a new issue may be pinned' => sub {
    $io->reset->add(200, 'true');
    my $allowed = value(sub { $repos->new_pin_allowed('owner', 'repo') });
    is(request(), 'GET /repos/owner/repo/new_pin_allowed',
        'GET /repos/{owner}/{repo}/new_pin_allowed');
    ok($allowed, 'new_pin_allowed returns the answer of the API');
};

subtest 'the push mirrors of the repository' => sub {
    $io->reset->add(200, '{"name":"mirror"}');
    my $mirror = value(sub { $repos->push_mirror('owner', 'repo', 'mirror') });
    is(request(), 'GET /repos/owner/repo/push_mirrors/mirror',
        'GET /repos/{owner}/{repo}/push_mirrors/{name}');
    is(ref $mirror, 'HASH', 'push_mirror returns the plain mirror');

    $io->reset->add(200, '{}');
    my $synced = value(sub { $repos->push_mirrors_sync('owner', 'repo') });
    is(request(), 'POST /repos/owner/repo/push_mirrors-sync',
        'POST /repos/{owner}/{repo}/push_mirrors-sync');
    is(ref $synced, 'HASH', 'push_mirrors_sync returns the answer of the API');
};

subtest 'the signing key of the repository' => sub {
    $io->reset->add(200, '-----BEGIN PGP PUBLIC KEY BLOCK-----');
    my $key = value(sub { $repos->signing_key('owner', 'repo') });
    is(request(), 'GET /repos/owner/repo/signing-key.gpg',
        'GET /repos/{owner}/{repo}/signing-key.gpg');
    like($key, qr/BEGIN PGP/, 'the key is returned as bytes');
};

subtest 'the fork is synchronised' => sub {
    $io->reset->add(200, '{"status":"done"}');
    my $state = value(sub { $repos->sync_fork('owner', 'repo') });
    is(request(), 'GET /repos/owner/repo/sync_fork', 'GET /repos/{owner}/{repo}/sync_fork');
    is(ref $state, 'HASH', 'sync_fork returns the plain state');

    $io->reset->add(200, '{"status":"done"}');
    my $branch = value(sub { $repos->sync_fork_branch('owner', 'repo', 'main') });
    is(request(), 'GET /repos/owner/repo/sync_fork/main',
        'GET /repos/{owner}/{repo}/sync_fork/{branch}');
    is(ref $branch, 'HASH', 'sync_fork_branch returns the plain state');

    $io->reset->add(202, '{}');
    my $started = value(sub { $repos->start_sync_fork('owner', 'repo') });
    is(request(), 'POST /repos/owner/repo/sync_fork', 'POST /repos/{owner}/{repo}/sync_fork');
    ok($started, 'start_sync_fork returns the answer of the API');

    $io->reset->add(202, '{}');
    my $started_branch = value(sub { $repos->start_sync_fork_branch('owner', 'repo', 'main') });
    is(request(), 'POST /repos/owner/repo/sync_fork/main',
        'POST /repos/{owner}/{repo}/sync_fork/{branch}');
    ok($started_branch, 'start_sync_fork_branch returns the answer of the API');
};

subtest 'the repository is converted' => sub {
    $io->reset->add(200, '{"repo":{}}');
    my $task = value(sub { $repos->convert('owner', 'repo', type => 'mirror', new_owner => 'other') });
    is(request(), 'POST /repos/owner/repo/convert', 'POST /repos/{owner}/{repo}/convert');
    is(body()->{type}, 'mirror', 'the type is sent in the body');
    is(ref $task, 'HASH', 'convert returns the plain answer');
};

subtest 'a patch is applied to the repository' => sub {
    $io->reset->add(200, '{"files":[]}');
    my $files = value(sub { $repos->diffpatch('owner', 'repo', content => 'diff', message => 'Patch') });
    is(request(), 'POST /repos/owner/repo/diffpatch', 'POST /repos/{owner}/{repo}/diffpatch');
    is(body()->{content}, 'diff', 'the patch is sent in the body');
    is(ref $files, 'HASH', 'diffpatch returns the plain answer');
};

subtest 'the transfer of the repository' => sub {
    $io->reset->add(200, '{}');
    my $accepted = value(sub { $repos->accept_transfer('owner', 'repo') });
    is(request(), 'POST /repos/owner/repo/transfer/accept',
        'POST /repos/{owner}/{repo}/transfer/accept');
    ok($accepted, 'accept_transfer returns the answer of the API');

    $io->reset->add(200, '{}');
    my $rejected = value(sub { $repos->reject_transfer('owner', 'repo') });
    is(request(), 'POST /repos/owner/repo/transfer/reject',
        'POST /repos/{owner}/{repo}/transfer/reject');
    ok($rejected, 'reject_transfer returns the answer of the API');
};

subtest 'the path parts are escaped' => sub {
    $io->reset->add(200, '{}');
    value(sub { $repos->commit_pull('own er', 're/po', 'a/b') });
    is(path(), '/repos/own%20er/re%2Fpo/commits/a%2Fb/pull', 'the path parts are escaped');
};

# ---------------------------------------------------------------------------
# The contents of the repository
# ---------------------------------------------------------------------------

subtest 'files are created at once' => sub {
    $io->reset->add(200, '{"content":{}}');
    my $answer = value(sub {
        $contents->create_files(files => [ { path => 'a.txt', content => 'x' } ]);
    });
    is(request(), 'POST /repos/owner/repo/contents', 'POST /repos/{owner}/{repo}/contents');
    is(ref body()->{files}, 'ARRAY', 'the files are sent in the body');
    is(ref $answer, 'HASH', 'create_files returns the plain answer');
};

# ---------------------------------------------------------------------------
# The git hooks of the repository
# ---------------------------------------------------------------------------

subtest 'the git hooks of the repository' => sub {
    $io->reset->add(200, '[{"id":1}]');
    my $list = value(sub { $hooks->list_git });
    is(request(), 'GET /repos/owner/repo/hooks/git', 'GET /repos/{owner}/{repo}/hooks/git');
    is(ref $list, 'ARRAY', 'list_git returns an arrayref');

    $io->reset->add(200, '{"id":1}');
    my $hook = value(sub { $hooks->get_git(1) });
    is(request(), 'GET /repos/owner/repo/hooks/git/1', 'GET /repos/{owner}/{repo}/hooks/git/{id}');
    is(ref $hook, 'HASH', 'get_git returns the plain hook');

    $io->reset->add(200, '{"id":1}');
    my $updated = value(sub { $hooks->update_git(1, content => "#!/bin/sh\n") });
    is(request(), 'PATCH /repos/owner/repo/hooks/git/1', 'PATCH /repos/{owner}/{repo}/hooks/git/{id}');
    is(body()->{content}, "#!/bin/sh\n", 'the content is sent in the body');
    is(ref $updated, 'HASH', 'update_git returns the plain hook');

    $io->reset->add(204, '');
    my $deleted = value(sub { $hooks->delete_git(1) });
    is(request(), 'DELETE /repos/owner/repo/hooks/git/1', 'DELETE /repos/{owner}/{repo}/hooks/git/{id}');
    ok($deleted, 'delete_git returns true');
};

# ---------------------------------------------------------------------------
# The git objects of the repository
# ---------------------------------------------------------------------------

subtest 'the blobs of the repository' => sub {
    $io->reset->add(200, '[{"sha":"abc123"}]');
    my $blobs = value(sub { $git->list_blobs('abc123') });
    is(request(), 'GET /repos/owner/repo/git/blobs', 'GET /repos/{owner}/{repo}/git/blobs');
    like(url(), qr/shas=abc123/, 'the object ids are sent as the query string');
    is(ref $blobs, 'ARRAY', 'list_blobs returns an arrayref');

    like(error(sub { $git->list_blobs('') }), qr/Object ids required/, 'list_blobs needs the object ids');
};

subtest 'the tag object of the repository' => sub {
    $io->reset->add(200, '{"sha":"abc123"}');
    my $tag = value(sub { $git->get_tag('abc123') });
    is(request(), 'GET /repos/owner/repo/git/tags/abc123', 'GET /repos/{owner}/{repo}/git/tags/{sha}');
    is(ref $tag, 'HASH', 'get_tag returns the plain tag');
};

subtest 'the notes of a commit' => sub {
    $io->reset->add(200, '{"message":"A note"}');
    my $note = value(sub { $git->get_note('abc123') });
    is(request(), 'GET /repos/owner/repo/git/notes/abc123', 'GET /repos/{owner}/{repo}/git/notes/{sha}');
    is($note->{message}, 'A note', 'the text of the note');

    $io->reset->add(201, '{"message":"A note"}');
    my $created = value(sub { $git->create_note('abc123', message => 'A note') });
    is(request(), 'POST /repos/owner/repo/git/notes/abc123', 'POST /repos/{owner}/{repo}/git/notes/{sha}');
    is(body()->{message}, 'A note', 'the text of the note is sent in the body');
    is(ref $created, 'HASH', 'create_note returns the plain note');

    $io->reset->add(204, '');
    my $deleted = value(sub { $git->delete_note('abc123') });
    is(request(), 'DELETE /repos/owner/repo/git/notes/abc123',
        'DELETE /repos/{owner}/{repo}/git/notes/{sha}');
    ok($deleted, 'delete_note returns true');
};

# ---------------------------------------------------------------------------
# The wiki of the repository
# ---------------------------------------------------------------------------

subtest 'the revisions of a wiki page' => sub {
    $io->reset->add(200, '[{"title":"Page"}]');
    my $revisions = value(sub { $wiki->revisions('Page-Title') });
    is(request(), 'GET /repos/owner/repo/wiki/revisions/Page-Title',
        'GET /repos/{owner}/{repo}/wiki/revisions/{pageName}');
    is(ref $revisions, 'ARRAY', 'revisions returns an arrayref');
};

done_testing;
