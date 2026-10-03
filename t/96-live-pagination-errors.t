#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use WWW::Forgejo;

# Live test of the automatic pagination through the default LWP backend (the
# X-Total-Count header has to arrive for it to work at all) and of the error
# paths: the message a 404, 409, 422 and 401 croak with. Needs the token of an
# admin user. Works on throwaway repositories, users and organizations named
# with the prefix below; leftovers of an earlier, aborted run are removed
# first, and everything is deleted at the end.

plan skip_all => 'TEST_FORGEJO_URL and TEST_FORGEJO_TOKEN required'
    unless $ENV{TEST_FORGEJO_URL} && $ENV{TEST_FORGEJO_TOKEN};

my $client = WWW::Forgejo->new(
    url   => $ENV{TEST_FORGEJO_URL},
    token => $ENV{TEST_FORGEJO_TOKEN},
);

my $PREFIX = 'wfl96-';
my $NAME   = $PREFIX . $$;
my $me     = $client->current_user->get;
my $OWNER  = $me->{login};

for my $old (@{ $client->current_user->repos }) {
    $client->repos->delete($OWNER, $old->{name}) if index($old->{name}, $PREFIX) == 0;
}
my $all_orgs = $client->orgs->list;
for my $old_org (@$all_orgs) {
    $client->orgs->delete($old_org->name) if index($old_org->name, $PREFIX) == 0;
}
for my $old_user (@{ $client->admin->users->list }) {
    $client->admin->users->delete($old_user->{login}, purge => 'true') if index($old_user->{login}, $PREFIX) == 0;
}

my @REPOS = map { $NAME . '-' . $_ } 1 .. 3;
my @USERS = map { $PREFIX . 'u' . $$ . $_ } 1 .. 3;
my @ORGS  = map { $PREFIX . 'org' . $$ . $_ } 1 .. 3;

END {
    if ($client) {
        for my $name (@REPOS) { eval { $client->repos->delete($OWNER, $name) } }
        for my $name (@ORGS)  { eval { $client->orgs->delete($name) } }
        for my $name (@USERS) { eval { $client->admin->users->delete($name, purge => 'true') } }
    }
}

$client->repos->create(name => $_, auto_init => \1, default_branch => 'main') for @REPOS;
$client->orgs->create(username => $_) for @ORGS;
for my $login (@USERS) {
    $client->admin->users->create(
        username             => $login,
        email                => $login . '@example.com',
        password             => 'Live-Test-' . $$ . '!',
        must_change_password => \0,
    );
}

my $repo = $client->repos->get($OWNER, $REPOS[0]);
$repo->labels->create({ name => "label-$_", color => '00aa00' }) for 1 .. 5;
$repo->issues->create({ title => "issue $_" }) for 1 .. 5;

# =============================================================================
# Pagination
# =============================================================================

# Each check first pins page 1 to show that the server does cut the
# collection into pages of that size; the unpinned call then has to collect
# the rest, which it only can when X-Total-Count reaches it.

subtest 'a bare array over three pages' => sub {
    is(scalar(my @first = $repo->issues->list(limit => 2, page => 1, state => 'all', type => 'issues')), 2,
        'issues: the server pages by two');
    my @issues = $repo->issues->list(limit => 2, state => 'all', type => 'issues');
    is(scalar @issues, 5, 'issues: all five collected');
    my %numbers;
    for my $issue (@issues) { $numbers{ $issue->number }++ }
    is(scalar keys %numbers, 5, 'no issue twice');
    my @third = $repo->issues->list(limit => 2, page => 3, state => 'all', type => 'issues');
    is(scalar @third, 1, 'an explicit page is not paginated: page 3 holds the last one');

    my $users = $client->admin->users->list(limit => 1);
    is(scalar @$users, scalar @{ $client->admin->users->list }, 'admin users: the same with and without a page size');
};

subtest "without a limit: the server's own page size" => sub {
    my $per_page = $client->misc->settings('api')->{default_paging_num};
    ok($per_page, "default_paging_num $per_page");
    my $wanted = $per_page + 2;
    $repo->issues->create({ title => "more $_" }) for 6 .. $wanted;
    is(scalar(my @first = $repo->issues->list(state => 'all', type => 'issues', page => 1)), $per_page,
        'page 1 holds one page');
    my @all = $repo->issues->list(state => 'all', type => 'issues');
    is(scalar @all, $wanted, 'all collected, the following pages with the size of the first');
};

subtest 'endpoints that page only with an explicit page' => sub {
    # Forgejo 15 answers the labels and orgs lists with everything unless a
    # page is given; limit alone changes nothing, and nothing is left to
    # collect.
    is(scalar(my @first = $repo->labels->list(limit => 2, page => 1)), 2, 'labels: page 1 of two');
    is(scalar(my @labels = $repo->labels->list(limit => 2)), 5, 'labels: limit alone, all five');
    my $orgs = $client->orgs->list(limit => 1);
    my %org_names;
    for my $listed_org (@$orgs) { $org_names{ $listed_org->name } = 1 }
    is(scalar(grep { $org_names{$_} } @ORGS), 3, 'orgs: all three');
};

subtest 'page_size and max_pages of the plain get' => sub {
    my $path   = "/repos/$OWNER/$REPOS[0]/issues";
    my %filter = (state => 'all', type => 'issues');
    my $total  = scalar(my @all = $repo->issues->list(%filter));
    is(scalar @{ $client->get($path, params => \%filter, page_size => 2) }, $total, "page_size: all $total");
    is(scalar @{ $client->get($path, params => \%filter, page_size => 2, max_pages => 2) }, 4, 'max_pages caps it');
};

subtest 'the search envelopes' => sub {
    my $page = $client->repos->search(q => $NAME, limit => 1, page => 1);
    is(scalar @{ $page->{data} }, 1, 'repos: the server pages by one');
    my $found = $client->repos->search(q => $NAME, limit => 1);
    ok($found->{ok}, 'repos: still the envelope');
    is_deeply([ sort map { $_->{name} } @{ $found->{data} } ], [ sort @REPOS ], 'repos: all three collected');

    my $user_page = $client->users->search(q => $PREFIX . 'u' . $$, limit => 1, page => 1);
    is(scalar @{ $user_page->{data} }, 1, 'users: the server pages by one');
    my $users = $client->users->search(q => $PREFIX . 'u' . $$, limit => 1);
    is_deeply([ sort map { $_->{login} } @{ $users->{data} } ], [ sort @USERS ], 'users: all three collected');
};

# =============================================================================
# Errors
# =============================================================================

subtest 'not found' => sub {
    eval { $client->repos->get($OWNER, $NAME . '-missing') };
    like($@, qr/^Forgejo API error: The target couldn't be found\. at /, 'a missing repository');

    eval { $repo->contents->get('no/such/file.txt') };
    like($@, qr/^Forgejo API error: \S/, 'a missing file: ' . ($@ =~ /^(.*?) at /)[0]);

    eval { $client->get('/no/such/route') };
    like($@, qr/^Forgejo API error: 404 page not found at /, 'a route the instance does not have');
};

subtest '409 and 422 carry the message of the server' => sub {
    eval { $client->repos->create(name => $REPOS[0]) };
    like($@, qr/^Forgejo API error: The repository with the same name already exists\./, '409: a repository that exists');

    eval { $client->repos->create(name => 'not a valid name') };
    like($@, qr/^Forgejo API error: \S/, '422: an invalid name: ' . ($@ =~ /^(.*?) at /)[0]);
    unlike($@, qr/^Forgejo API error: 422 at /, 'the message, not only the status');

    eval { $repo->labels->create({ name => 'no-color' }) };
    like($@, qr/^Forgejo API error: \S/, '422: a missing required field: ' . ($@ =~ /^(.*?) at /)[0]);
};

subtest '401: a wrong token' => sub {
    my $stranger = WWW::Forgejo->new(url => $ENV{TEST_FORGEJO_URL}, token => 'not-a-token');
    eval { $stranger->current_user->get };
    like($@, qr/^Forgejo API error: \S/, 'croaks: ' . ($@ =~ /^(.*?) at /)[0]);
};

done_testing;
