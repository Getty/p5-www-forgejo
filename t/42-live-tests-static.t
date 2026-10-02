#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 't/lib';
use MockForgejo qw(mock_client);
use MethodChains qw(check_chains);

# The live tests (t/9x-live-*.t) only run against a real instance, so nothing
# in the offline suite notices when they call a method that was renamed or
# removed. This test reads their source and checks every method call in it
# against the real classes (see t/lib/MethodChains.pm), without running them.
# A call it cannot attribute to a class counts as a failure: write the live
# tests so that every receiver is a variable assigned from a client chain.

my @files = sort glob 't/9*-live-*.t';
cmp_ok(scalar @files, '>=', 3, 'live tests found');

for my $file (@files) {
    subtest $file => sub {
        open my $fh, '<', $file or die "$file: $!";
        my $source = do { local $/; <$fh> };
        close $fh;

        ok($source =~ m{\A#!/usr/bin/env perl\nuse strict;\nuse warnings;\n}, "shebang, strict, warnings");
        ok($source =~ qr/plan skip_all => [^;]+unless \$ENV\{TEST_FORGEJO_URL\} && \$ENV\{TEST_FORGEJO_TOKEN\};/,
            'skips without TEST_FORGEJO_URL and TEST_FORGEJO_TOKEN');
        my @env = grep { !/^TEST_FORGEJO_/ } $source =~ /\$ENV\{(\w+)\}/g;
        is_deeply(\@env, [], 'reads only TEST_FORGEJO_* environment variables');

        my ($client, $io) = mock_client();
        my $result = check_chains(
            $source,
            io        => $io,
            vars      => { client => $client },
            instances => { 'WWW::Forgejo' => $client },
        );
        is_deeply($result->{errors},     [], 'every method called exists') or diag join "\n", @{ $result->{errors} };
        is_deeply($result->{unverified}, [], 'every method call could be attributed to a class')
            or diag join "\n", @{ $result->{unverified} };
        cmp_ok($result->{checked}, '>=', 5, "method calls checked ($result->{checked})");
    };
}

subtest 'the live tests skip themselves without an instance' => sub {
    local @ENV{qw(TEST_FORGEJO_URL TEST_FORGEJO_TOKEN)};
    delete @ENV{qw(TEST_FORGEJO_URL TEST_FORGEJO_TOKEN)};
    for my $file (@files) {
        my $out = qx{$^X -Ilib $file 2>&1};
        is($?, 0, "$file exits cleanly");
        like($out, qr/\A1\.\.0 # SKIP TEST_FORGEJO_URL and TEST_FORGEJO_TOKEN required\s*\z/, "$file skips, and prints nothing else");
    }
};

subtest 'the test instance tooling hands the live tests the variables they read' => sub {
    # Not part of the tarball; checked where the files exist.
    my @tooling = grep { -e } qw(Makefile.docker k8s/forgejo-test/Makefile scripts/setup-forgejo-test.sh);
    plan skip_all => 'no test instance tooling in this tree' unless @tooling;
    for my $file (@tooling) {
        open my $fh, '<', $file or die "$file: $!";
        my @bare = grep { /(?<!TEST_)FORGEJO_(?:URL|TOKEN)/ } <$fh>;
        is_deeply(\@bare, [], "$file uses TEST_FORGEJO_URL / TEST_FORGEJO_TOKEN only");
    }
};

subtest 'the checker itself notices what it is there for' => sub {
    my ($client, $io) = mock_client();
    my $check = sub {
        check_chains($_[0], io => $io, vars => { client => $client }, instances => { 'WWW::Forgejo' => $client });
    };

    my $r = $check->(<<'EOT');
my $user  = $client->users->get('x');           # plain data
my $repo  = eval { $client->repos->get('o', 'r') };
my @list  = $repo->issues->list(state => 'open');
for my $issue ($repo->issues->list) { print $issue->number, $issue->title }
my ($pr)  = $repo->pulls->list;
print $pr->number;
my $orgs = $client->orgs->list;
for my $org (@$orgs) { $org->teams->list }
print $orgs->[0]->name;
my @comments = $repo->issues->list_comments(1);
for my $comment (@comments) { print $comment->body }
my $new = WWW::Forgejo->new(url => 'x')->admin->cron->list;   # a comment with $client->nope
EOT
    is_deeply($r->{errors},     [], 'valid chains: no errors')        or diag explain $r->{errors};
    is_deeply($r->{unverified}, [], 'valid chains: all attributable') or diag explain $r->{unverified};
    is($r->{checked}, 25, 'valid chains: every link counted');

    $r = $check->('$client->admin->users->get($name);');
    is_deeply($r->{errors}, ['line 1: WWW::Forgejo::API::Admin::Users has no method get'], 'removed controller method');

    $r = $check->("my \$repo = \$client->repos->get('o', 'r');\n\$repo->branches->protect('main');");
    is_deeply($r->{errors}, ['line 2: WWW::Forgejo::API::Repo::Branches has no method protect'], 'through a variable');

    $r = $check->("for my \$m (\$client->repos->get('o', 'r')->milestones->list) {\n  \$m->due_date;\n}");
    is_deeply($r->{errors}, ['line 2: WWW::Forgejo::Entity::Milestone has no method due_date'], 'renamed entity accessor');

    $r = $check->('$client->users->get("x")->login;');
    is_deeply($r->{unverified}, ['line 1: ->login'], 'a method call on plain data cannot be attributed');

    $r = $check->('my $x = $client->repos->get("o", "r")->issues->list; $x->number;');
    is_deeply($r->{unverified}, ['line 1: ->number'], 'neither can one on a list squeezed into a scalar');

    $r = $check->('$thing->frobnicate;');
    is_deeply($r->{unverified}, ['line 1: ->frobnicate'], 'nor one on an unknown variable');
};

done_testing;
