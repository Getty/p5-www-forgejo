#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use MIME::Base64 qw(encode_base64 decode_base64);
use Encode qw(encode);
use File::Temp qw(tempfile);
use lib 'lib';
use WWW::Forgejo;

# Live test of the repository write paths: file contents (raw bytes, DELETE
# with a body), wiki, branches and tags with a slash in their name, tag
# protections, releases with multipart asset uploads, git objects and commit
# statuses. Works on a throwaway repository of the token user, named with the
# prefix below; leftovers of an earlier, aborted run are removed first, and
# the repository is deleted at the end.

plan skip_all => 'TEST_FORGEJO_URL and TEST_FORGEJO_TOKEN required'
    unless $ENV{TEST_FORGEJO_URL} && $ENV{TEST_FORGEJO_TOKEN};

my $client = WWW::Forgejo->new(
    url   => $ENV{TEST_FORGEJO_URL},
    token => $ENV{TEST_FORGEJO_TOKEN},
);

my $PREFIX = 'wfl93-';
my $me     = $client->current_user->get;
my $OWNER  = $me->{login};
my $NAME   = $PREFIX . $$;

for my $old (@{ $client->current_user->repos }) {
    $client->repos->delete($OWNER, $old->{name}) if index($old->{name}, $PREFIX) == 0;
}

my $created = $client->repos->create(name => $NAME, auto_init => \1, private => \0, default_branch => 'main');
END { eval { $client->repos->delete($OWNER, $NAME) } if $client && $OWNER && $NAME }

my $repo = $client->repos->get($OWNER, $NAME);
my $main = $repo->branches->get('main');
my $HEAD = $main->commit->{id};

# Every byte value once, and a UTF-8 text with characters outside Latin-1.
my $BINARY = join '', map { chr } 0 .. 255;
my $TEXT   = encode('UTF-8', "Gr\x{fc}\x{df}e \x{2713}\nzweite Zeile\n");
my $JSON   = qq({"not":"decoded"}\n);

subtest 'the throwaway repository' => sub {
    is($created->repo, $NAME, 'created');
    is($created->owner, $OWNER, 'owned by the token user');
    is($repo->data->{default_branch}, 'main', 'default branch');
    ok($HEAD, 'main has a head commit');
};

# =============================================================================
# Contents
# =============================================================================

my %sha;

subtest 'contents create' => sub {
    for my $file ([ 'bin/all-bytes.bin', $BINARY ], [ 'docs/umlaut.txt', $TEXT ], [ 'data/plain.json', $JSON ]) {
        my ($path, $bytes) = @$file;
        my $res = $repo->contents->create($path, { content => encode_base64($bytes, ''), message => "add $path" });
        is($res->{content}{path}, $path, "$path created");
        ok($sha{$path} = $res->{content}{sha}, 'blob sha returned');
        ok($res->{commit}{sha}, 'commit returned');
    }
};

subtest 'contents get' => sub {
    my $file = $repo->contents->get('docs/umlaut.txt');
    is($file->{type}, 'file', 'a file');
    is($file->{encoding}, 'base64', 'base64 encoded');
    is(decode_base64($file->{content}), $TEXT, 'content round trips');
    is($file->{sha}, $sha{'docs/umlaut.txt'}, 'same sha');

    my $dir = $repo->contents->get('docs');
    is(ref $dir, 'ARRAY', 'a directory lists its entries');
    is($dir->[0]{name}, 'umlaut.txt', 'with the file');

    my $root = $repo->contents->get('');
    is(ref $root, 'ARRAY', 'the root directory too');

    my $at_ref = $repo->contents->get('README.md', ref => 'main');
    is($at_ref->{name}, 'README.md', 'named arguments reach the query string');
};

subtest 'raw and media hand back the file bytes unchanged' => sub {
    is($repo->contents->raw('bin/all-bytes.bin'), $BINARY, 'raw: binary file');
    is($repo->contents->media('bin/all-bytes.bin'), $BINARY, 'media: binary file');
    is($repo->contents->raw('docs/umlaut.txt'), $TEXT, 'raw: UTF-8 text file, as bytes');
    is($repo->contents->media('docs/umlaut.txt'), $TEXT, 'media: UTF-8 text file, as bytes');
    is($repo->contents->raw('data/plain.json'), $JSON, 'raw: a JSON file is not decoded');
    is($repo->contents->raw('README.md', ref => 'main'), $repo->contents->raw('README.md'), 'raw with a ref');
};

subtest 'archives' => sub {
    my $zip = $repo->contents->get_archive('main.zip');
    is(substr($zip, 0, 4), "PK\x03\x04", 'zip archive starts with the zip signature');
    my $tgz = $repo->contents->get_archive('main.tar.gz');
    is(substr($tgz, 0, 2), "\x1f\x8b", 'tar.gz archive starts with the gzip signature');
};

subtest 'contents update' => sub {
    my $new = encode('UTF-8', "ge\x{e4}ndert\n");
    my $res = $repo->contents->update('docs/umlaut.txt', {
        content => encode_base64($new, ''),
        message => 'update umlaut.txt',
        sha     => $sha{'docs/umlaut.txt'},
    });
    isnt($res->{content}{sha}, $sha{'docs/umlaut.txt'}, 'new blob sha');
    $sha{'docs/umlaut.txt'} = $res->{content}{sha};
    is($repo->contents->raw('docs/umlaut.txt'), $new, 'new content');

    ok(!eval {
        $repo->contents->update('docs/umlaut.txt', { content => encode_base64('x', ''), message => 'stale', sha => '0' x 40 });
        1;
    }, 'an update with a stale sha fails');
    like($@, qr/^Forgejo API error: \S/, 'with the message of the server');
};

subtest 'contents delete sends sha and message as the DELETE body' => sub {
    my $res = $repo->contents->delete('data/plain.json', { sha => $sha{'data/plain.json'}, message => 'remove plain.json' });
    ok($res->{commit}{sha}, 'a commit is returned');
    is($res->{content}, undef, 'and no content');
    ok(!eval { $repo->contents->get('data/plain.json'); 1 }, 'the file is gone');
    like($@, qr/^Forgejo API error: /, 'reading it croaks');

    ok(!eval { $repo->contents->delete('docs/umlaut.txt', { sha => '0' x 40, message => 'wrong sha' }); 1 },
        'deleting with a wrong sha fails');
    ok(eval { $repo->contents->get('docs/umlaut.txt'); 1 }, 'and leaves the file in place');
};

# =============================================================================
# Wiki
# =============================================================================

subtest 'wiki create, read, edit, delete' => sub {
    my $page = $repo->wiki->create_page({
        title          => 'Live Page',
        content_base64 => encode_base64($TEXT, ''),
        message        => 'create wiki page',
    });
    is($page->{title}, 'Live Page', 'created');
    my $sub_url = $page->{sub_url};
    ok($sub_url, "sub_url $sub_url");

    my @pages = $repo->wiki->list_pages;
    my %titles = map { ($_->{title} => 1) } @pages;
    ok($titles{'Live Page'}, 'listed');

    my $got = $repo->wiki->get_page($sub_url);
    is(decode_base64($got->{content_base64}), $TEXT, 'content round trips');

    my $edited = $repo->wiki->edit_page($sub_url, {
        title          => 'Live Page',
        content_base64 => encode_base64("edited\n", ''),
        message        => 'edit wiki page',
    });
    is(decode_base64($edited->{content_base64}), "edited\n", 'edited');

    is($repo->wiki->delete_page($sub_url), undef, 'deleted');
    ok(!eval { $repo->wiki->get_page($sub_url); 1 }, 'gone');
};

# =============================================================================
# Branches and tags with a slash in the name
# =============================================================================

subtest 'branch named feature/x' => sub {
    my $head = $repo->branches->get('main')->commit->{id};
    my $branch = $repo->branches->create({ new_branch_name => 'feature/x', old_ref_name => 'main' });
    isa_ok($branch, 'WWW::Forgejo::Entity::Branch');
    is($branch->name, 'feature/x', 'created');

    my $got = $repo->branches->get('feature/x');
    is($got->name, 'feature/x', 'get escapes the slash');
    is($got->commit->{id}, $head, 'points at the head of main');
    ok(!$got->protected, 'not protected');

    my %names;
    for my $listed ($repo->branches->list) { $names{ $listed->name } = 1 }
    ok($names{'feature/x'}, 'listed');

    my $refs = $repo->git->get_ref('heads/feature/x');
    is(ref $refs, 'ARRAY', 'get_ref returns the matching refs');
    is($refs->[0]{ref}, 'refs/heads/feature/x', 'git ref with slashes');

    ok($repo->branches->rename('feature/x', 'feature/y'), 'rename');
    is($repo->branches->get('feature/y')->name, 'feature/y', 'renamed');
    ok(!eval { $repo->branches->get('feature/x'); 1 }, 'the old name is gone');

    $repo->branches->delete('feature/y');
    ok(!eval { $repo->branches->get('feature/y'); 1 }, 'deleted');
};

subtest 'branch protections' => sub {
    my $rule = $repo->branch_protections->create({ rule_name => 'release/*', enable_push => \0 });
    isa_ok($rule, 'WWW::Forgejo::Entity::BranchProtection');
    is($rule->rule_name, 'release/*', 'created');
    is($rule->branch_name, '', 'branch_name, the deprecated twin of rule_name, stays empty for a pattern');

    my $got = $repo->branch_protections->get('release/*');
    is($got->rule_name, 'release/*', 'get escapes the rule name');

    my $edited = $repo->branch_protections->update('release/*', { enable_push => \1 });
    ok($edited->data->{enable_push}, 'updated');

    my @rules = $repo->branch_protections->list;
    is(scalar @rules, 1, 'listed');

    $repo->branch_protections->delete('release/*');
    is(scalar(my @none = $repo->branch_protections->list), 0, 'deleted');
};

subtest 'tag named v/1.0' => sub {
    my $head = $repo->branches->get('main')->commit->{id};
    my $tag = $repo->tags->create({ tag_name => 'v/1.0', target => 'main', message => 'annotated' });
    is($tag->{name}, 'v/1.0', 'created');

    my $got = $repo->tags->get('v/1.0');
    is($got->{name}, 'v/1.0', 'get escapes the slash');
    is($got->{commit}{sha}, $head, 'tags the head of main');

    my %names = map { ($_->{name} => 1) } $repo->tags->list;
    ok($names{'v/1.0'}, 'listed');

    $repo->tags->delete('v/1.0');
    ok(!eval { $repo->tags->get('v/1.0'); 1 }, 'deleted');
};

subtest 'tag protections' => sub {
    my $rule = $repo->tag_protections->create({ name_pattern => 'v/*', whitelist_usernames => [$OWNER] });
    ok($rule->{id}, 'created');
    is($rule->{name_pattern}, 'v/*', 'with the pattern');

    is($repo->tag_protections->get($rule->{id})->{name_pattern}, 'v/*', 'get');

    my $edited = $repo->tag_protections->edit($rule->{id}, { name_pattern => 'release/*' });
    is($edited->{name_pattern}, 'release/*', 'edited');

    my @rules = $repo->tag_protections->list;
    is(scalar @rules, 1, 'listed');

    $repo->tag_protections->delete($rule->{id});
    is(scalar(my @none = $repo->tag_protections->list), 0, 'deleted');
};

# =============================================================================
# Releases and their assets
# =============================================================================

subtest 'releases and multipart asset uploads' => sub {
    my $release = $repo->releases->create({
        tag_name         => 'rel/1.0',
        name             => 'Release 1.0',
        body             => "Gr\x{fc}\x{df}e",
        target_commitish => 'main',
    });
    isa_ok($release, 'WWW::Forgejo::Entity::Release');
    is($release->tag_name, 'rel/1.0', 'created');
    is($release->name, 'Release 1.0', 'name');
    is($release->body, "Gr\x{fc}\x{df}e", 'body with non-ASCII text');
    is($release->target_commitish, 'main', 'target');

    is($repo->releases->get($release->id)->name, 'Release 1.0', 'get');
    is($repo->releases->get_by_tag('rel/1.0')->id, $release->id, 'get_by_tag with a slash');
    is($repo->releases->latest->id, $release->id, 'latest');

    my $edited = $repo->releases->edit($release->id, { name => 'Release 1.0 final' });
    is($edited->name, 'Release 1.0 final', 'edit');

    my ($fh, $filename) = tempfile(SUFFIX => '.bin', UNLINK => 1);
    binmode $fh;
    print {$fh} $BINARY;
    close $fh;

    my $from_file = $repo->releases->upload_asset($release->id, file => $filename, name => 'from-file.bin');
    isa_ok($from_file, 'WWW::Forgejo::Entity::ReleaseAsset');
    is($from_file->name, 'from-file.bin', 'upload from a file, with a name');
    is($from_file->size, 256, 'every byte arrived');
    ok($from_file->browser_download_url, 'download URL');
    ok($from_file->created_at, 'created_at');
    is($from_file->downloads, 0, 'download count');

    my $from_content = $repo->releases->upload_asset($release->id, content => $TEXT, filename => 'notes.txt');
    is($from_content->name, 'notes.txt', 'upload from content, named after the filename');
    is($from_content->size, length $TEXT, 'size in bytes');

    my @assets = $repo->releases->assets($release->id);
    is(scalar @assets, 2, 'two assets listed');

    my $asset = $repo->releases->get_asset($release->id, $from_file->id);
    is($asset->name, 'from-file.bin', 'get_asset');

    my $renamed = $repo->releases->edit_asset($release->id, $from_file->id, { name => 'renamed.bin' });
    is($renamed->name, 'renamed.bin', 'edit_asset');

    ok($repo->releases->delete_asset($release->id, $from_content->id), 'delete_asset');
    is(scalar(my @left = $repo->releases->assets($release->id)), 1, 'one asset left');

    ok($repo->releases->delete_by_tag('rel/1.0'), 'delete_by_tag');
    ok(!eval { $repo->releases->get($release->id); 1 }, 'release gone');
    is($repo->tags->get('rel/1.0')->{name}, 'rel/1.0', 'the tag stays');

    my $second = $repo->releases->create({ tag_name => 'rel/2.0', name => 'two' });
    ok($repo->releases->delete($second->id), 'delete by id');
    is(scalar(my @none = $repo->releases->list), 0, 'no releases left');
};

# =============================================================================
# Git objects and commit statuses
# =============================================================================

subtest 'git refs, commits, trees and blobs' => sub {
    my $refs = $repo->git->list_refs;
    my %refs = map { ($_->{ref} => $_->{object}{sha}) } @$refs;
    is($refs{'refs/heads/main'}, $repo->branches->get('main')->commit->{id}, 'main listed with its head');

    my $head = $repo->branches->get('main')->commit->{id};
    my $commit = $repo->git->get_commit($head);
    is($commit->{sha}, $head, 'get_commit');

    my $tree = $repo->git->get_tree($head, recursive => 1);
    my %blob = map { ($_->{path} => $_->{sha}) } grep { $_->{type} eq 'blob' } @{ $tree->{tree} };
    ok($blob{'bin/all-bytes.bin'}, 'recursive tree reaches into subdirectories');

    my $blob = $repo->git->get_blob($blob{'bin/all-bytes.bin'});
    is($blob->{encoding}, 'base64', 'blob is base64');
    is(decode_base64($blob->{content}), $BINARY, 'blob content');
    is($blob->{size}, 256, 'blob size');
};

subtest 'commit statuses' => sub {
    my $head = $repo->branches->get('main')->commit->{id};
    my $status = $repo->statuses->create($head, {
        state       => 'success',
        context     => 'live/test',
        description => 'from t/93',
        target_url  => 'https://example.com/build/1',
    });
    isa_ok($status, 'WWW::Forgejo::Entity::CommitStatus');
    ok($status->id, 'created');
    is($status->status, 'success', 'status');
    is($status->context, 'live/test', 'context');
    is($status->description, 'from t/93', 'description');
    is($status->target_url, 'https://example.com/build/1', 'target_url');

    my @statuses = $repo->statuses->list($head);
    is(scalar @statuses, 1, 'listed');

    my $combined = $repo->statuses->combined('main');
    is($combined->{state}, 'success', 'combined state');
    is($combined->{total_count}, 1, 'combined total');

    # {ref} is a single path segment: a slash in it has to arrive as %2F.
    $repo->branches->create({ new_branch_name => 'ci/status', old_ref_name => 'main' });
    my $by_branch = $repo->statuses->combined('ci/status');
    is($by_branch->{sha}, $head, 'combined status of a branch with a slash in its name');
    is($by_branch->{total_count}, 1, 'with the status of its head commit');
    $repo->branches->delete('ci/status');
};

done_testing;
