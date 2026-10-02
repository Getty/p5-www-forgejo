#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);
use WWW::Forgejo::Entity::Org;
use WWW::Forgejo::Entity::Repo;

my ($client, $io) = mock_client();
my $base = 'https://forgejo.test/api/v1';

sub fixture {
    my ($name) = @_;
    open my $fh, '<', "t/fixtures/$name.json" or die "$name: $!";
    return do { local $/; <$fh> };
}

# ---------------------------------------------------------------------------
# Entity::Org
# ---------------------------------------------------------------------------

subtest 'the organization fixture has the shape of the API schema' => sub {
    my $data = decode_json(fixture('org'));
    # Organization in the Swagger document: name is the organization name,
    # username its deprecated twin; there is no "login".
    is($data->{name}, 'test-org', 'name');
    is($data->{username}, 'test-org', 'username (deprecated twin of name)');
    ok(!exists $data->{login}, 'no login field');
};

subtest 'an organization from the API addresses itself by name' => sub {
    $io->reset->add(200, fixture('org'));
    my $org = $client->orgs->get('test-org');
    isa_ok($org, 'WWW::Forgejo::Entity::Org');
    is($org->name, 'test-org', 'name');

    my %class = (
        members => 'Members', teams => 'Teams', hooks => 'Hooks', labels => 'Labels',
        quota => 'Quota', actions => 'Actions', blocked_users => 'BlockedUsers',
    );
    for my $acc (sort keys %class) {
        my $ctl = $org->$acc;
        isa_ok($ctl, "WWW::Forgejo::API::Org::$class{$acc}", "\$org->$acc");
        is($ctl->owner, 'test-org', "$acc is bound to the organization name");
        is($ctl->client, $client, "$acc is bound to the client");
    }
};

subtest 'the per-organization controllers reach the organization' => sub {
    my $org = WWW::Forgejo::Entity::Org->new(client => $client, data => decode_json(fixture('org')));

    $io->reset->add(200, '[{"id":1}]');
    $org->hooks->list;
    is($io->last->method . ' ' . $io->last->url, "GET $base/orgs/test-org/hooks", 'hooks->list');

    $io->reset->add(200, '[{"login":"a"}]');
    $org->members->list;
    is($io->last->url, "$base/orgs/test-org/members", 'members->list');

    $io->reset->add(200, '[{"id":1,"name":"Owners"}]');
    $org->teams->list;
    is($io->last->url, "$base/orgs/test-org/teams", 'teams->list');
};

subtest 'name is taken from the deprecated username when name is missing' => sub {
    my $org = WWW::Forgejo::Entity::Org->new(client => $client, data => { id => 1, username => 'old-org' });
    is($org->name, 'old-org', 'name falls back to username');
    is($org->labels->owner, 'old-org', 'controllers follow');
};

subtest 'name wins over username' => sub {
    my $org = WWW::Forgejo::Entity::Org->new(client => $client, data => { name => 'new', username => 'old' });
    is($org->name, 'new', 'name');
    is($org->hooks->owner, 'new', 'controller owner');
};

subtest 'update, delete and repos use the organization name' => sub {
    my $org = WWW::Forgejo::Entity::Org->new(client => $client, data => decode_json(fixture('org')));

    $io->reset->add(200, '{"id":1,"name":"test-org","username":"test-org","description":"new"}');
    my $same = $org->update(description => 'new');
    is($io->last->method . ' ' . $io->last->url, "PATCH $base/orgs/test-org", 'update request');
    is_deeply(decode_json($io->last->content), { description => 'new' }, 'update body');
    is($same, $org, 'update returns the object itself');
    is($org->data->{description}, 'new', 'with the data refreshed');
    is($org->name, 'test-org', 'and still knows its name');

    $io->reset->add(200, '[{"name":"r1","owner":{"login":"test-org"}}]');
    my $repos = $org->repos;
    is($io->last->method . ' ' . $io->last->url, "GET $base/orgs/test-org/repos", 'repos request');
    isa_ok($repos->[0], 'WWW::Forgejo::Entity::Repo');
    is($repos->[0]->owner, 'test-org', 'repository owner');

    $io->reset->add(204, '');
    $org->delete;
    is($io->last->method . ' ' . $io->last->url, "DELETE $base/orgs/test-org", 'delete request');
};

subtest 'an organization without any name cannot be addressed' => sub {
    my $org = WWW::Forgejo::Entity::Org->new(client => $client, data => { id => 1 });
    $io->reset;
    eval { $org->update(description => 'x') };
    like($@, qr/Organization name required/, 'update croaks');
    eval { $org->delete };
    like($@, qr/Organization name required/, 'delete croaks');
    eval { $org->repos };
    like($@, qr/Organization name required/, 'repos croaks');
    is($io->count, 0, 'nothing was sent');
};

subtest 'public_members is gone: the members controller lists them' => sub {
    ok(!WWW::Forgejo::Entity::Org->can('public_members'), 'no public_members accessor');
    my $org = WWW::Forgejo::Entity::Org->new(client => $client, data => { name => 'test-org' });
    $io->reset->add(200, '[{"login":"a"}]');
    my $public = $org->members->list_public;
    is($io->last->method . ' ' . $io->last->url, "GET $base/orgs/test-org/public_members", 'list_public request');
    is($public->[0]{login}, 'a', 'data');
};

# ---------------------------------------------------------------------------
# Entity::Repo
# ---------------------------------------------------------------------------

my %controller = (
    branches => 'Branches', branch_protections => 'BranchProtections', tags => 'Tags',
    tag_protections => 'TagProtections', releases => 'Releases', issues => 'Issues',
    pulls => 'PullRequests', hooks => 'Hooks', collaborators => 'Collaborators',
    contents => 'Contents', git => 'Git', wiki => 'Wiki', actions => 'Actions',
    labels => 'Labels', milestones => 'Milestones', topics => 'Topics', keys => 'Keys',
    forks => 'Forks', stargazers => 'Stargazers', subscribers => 'Subscribers',
    subscription => 'Subscription', assignees => 'Assignees', reviewers => 'Reviewers',
    flags => 'Flags', statuses => 'Statuses',
);

sub repo_entity {
    my (%args) = @_;
    return WWW::Forgejo::Entity::Repo->new(
        client => $client, owner => 'o', repo => 'r', data => { name => 'r' }, %args,
    );
}

subtest 'every repository controller has an accessor' => sub {
    my $repo = repo_entity();
    for my $acc (sort keys %controller) {
        my $ctl = $repo->$acc;
        isa_ok($ctl, "WWW::Forgejo::API::Repo::$controller{$acc}", "\$repo->$acc");
        is($ctl->client, $client, "$acc: client");
        is($ctl->owner, 'o', "$acc: owner");
        is($ctl->repo, 'r', "$acc: repo");
        is($repo->$acc, $ctl, "$acc: built once");
    }
};

subtest 'no controller module is left without an accessor' => sub {
    opendir my $dh, 'lib/WWW/Forgejo/API/Repo' or die $!;
    my @modules = sort map { /^(\w+)\.pm\z/ ? $1 : () } readdir $dh;
    is_deeply(\@modules, [ sort values %controller ], 'accessors cover lib/WWW/Forgejo/API/Repo');
};

subtest 'statuses accessor works end to end' => sub {
    $io->reset->add(200, '[{"id":1,"status":"success","context":"ci"}]');
    my @statuses = repo_entity()->statuses->list('abc123');
    is($io->last->url, "$base/repos/o/r/statuses/abc123", 'request');
    isa_ok($statuses[0], 'WWW::Forgejo::Entity::CommitStatus');
    is($statuses[0]->status, 'success', 'data');
};

subtest 'update and delete escape owner and repository name' => sub {
    my $repo = repo_entity(owner => 'my org', repo => 'a/b');

    $io->reset->add(200, '{"name":"a/b","description":"new"}');
    my $updated = $repo->update({ description => 'new' });
    is($io->last->method . ' ' . $io->last->url, "PATCH $base/repos/my%20org/a%2Fb", 'update request');
    is_deeply(decode_json($io->last->content), { description => 'new' }, 'update body');

    isa_ok($updated, 'WWW::Forgejo::Entity::Repo');
    isnt($updated, $repo, 'update returns a new entity');
    is($updated->data->{description}, 'new', 'carrying the response');
    is($updated->client, $client, 'and the client');
    is($updated->owner, 'my org', 'and the owner');
    is($updated->repo, 'a/b', 'and the repository name');
    is($repo->data->{description}, undef, 'the original keeps its data');

    $io->reset->add(204, '');
    is($repo->delete, 1, 'delete returns true');
    is($io->last->method . ' ' . $io->last->url, "DELETE $base/repos/my%20org/a%2Fb", 'delete request');
};

subtest 'an updated entity builds its own controllers' => sub {
    my $repo = repo_entity();
    my $issues = $repo->issues;
    $io->reset->add(200, '{"name":"r"}');
    my $updated = $repo->update({ description => 'x' });
    isnt($updated->issues, $issues, 'controllers are not carried over');
    is($updated->issues->owner, 'o', 'but bound alike');
};

done_testing;
