#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Find;
use lib 't/lib';
use MockForgejo qw(mock_client);

# Every public method of every controller is called once against a recording
# transport. The request it sends (verb + path) has to be an operation of the
# Forgejo API as listed in t/fixtures/forgejo-api-paths.txt, which is extracted
# from the official Swagger document. A method that sends nothing, or talks to
# an endpoint the API does not have, fails here.

my %operation;
{
    open my $fh, '<', 't/fixtures/forgejo-api-paths.txt' or die "fixture: $!";
    while (my $line = <$fh>) {
        next if $line =~ /^#/ || $line !~ /\S/;
        chomp $line;
        my ($verb, $path) = split ' ', $line;
        # A path segment may carry an extension: /pulls/{index}.{diffType}.
        # Such a segment counts as one placeholder, on both sides.
        $path =~ s/\{[^}]+\}\.\{[^}]+\}/{}/g;
        $path =~ s/\{[^}]+\}/{}/g;
        $operation{"$verb $path"} = 1;
    }
}
cmp_ok(scalar keys %operation, '>', 400, 'API operation list loaded');

# Methods that need specific named arguments instead of the positional
# placeholders.
my %args = (
    'Admin::Quota::create_group' => [ name => 'ARG1' ],
    'Admin::Quota::create_rule'  => [ name => 'ARG1' ],
    'Admin::Quota::edit_rule'    => [ 'ARG1', limit => 10 ],
    'Admin::Runners::create'     => [ name => 'ARG1' ],
    'Admin::Users::create_token' => [ 'ARG1', name => 'ARG2' ],
    'CurrentUser::activitypub_follow' => [ target => 'ARG1' ],
    'CurrentUser::quota_check'   => [ subject => 'ARG1' ],
    'CurrentUser::set_avatar'    => [ image => 'ARG1' ],
    'CurrentUser::verify_gpg_key' => [ armored_signature => 'ARG1', key_id => 'ARG2' ],
    'Orgs::create'            => [ username => 'ARG1' ],
    'Orgs::rename'            => [ 'ARG1', new_name => 'ARG2' ],
    'Orgs::set_avatar'        => [ 'ARG1', image => 'ARG2' ],
    'Org::Quota::check'       => [ subject => 'ARG1' ],
    'Teams::create'           => [ org => 'ARG1', name => 'ARG2' ],
    'Users::search'           => [ q => 'ARG1' ],
    'Misc::topics_search'     => [ q => 'ARG1' ],
    'Misc::settings'          => [ 'api' ],
    'Org::Hooks::create'      => [ type => 'forgejo', config => {} ],
    'Org::Labels::create'     => [ name => 'bug', color => 'ff0000' ],
    'Org::Teams::create'      => [ name => 'ARG2' ],
    'Org::Teams::search'      => [ q => 'ARG2' ],
    'Repo::Releases::upload_asset' => [ 'ARG1', filename => 'a.txt', content => 'x' ],
    'Repo::Contents::get'     => [ 'ARG1' ],
    'Repo::Contents::delete'  => [ 'ARG1', sha => 'ARG2' ],
    'Repo::Issues::create_asset'        => [ 'ARG1', name => 'a.png', content => 'x', filename => 'a.png' ],
    'Repo::Issues::create_comment_asset' => [ 'ARG1', name => 'a.png', content => 'x', filename => 'a.png' ],
    'Repos::search'           => [ q => 'ARG1' ],
    'Repos::set_avatar'       => [ 'ARG1', 'ARG2', image => 'ARG3' ],
    'Packages::upload'        => [ 'ARG1', 'ARG2', 'ARG3', 'ARG4', 'ARG5', content => 'x' ],
);

# Methods that talk to a path outside the /api/v1 of the API: the Swagger
# document does not cover them. The package upload lives at /api/packages, the
# packages router of Forgejo is mounted on the instance.
my %outside_api = (
    'Packages::upload' => 'PUT /api/packages/ARG1/ARG2/ARG3/ARG4/ARG5',
);

# Methods that only hand out another controller and send no request.
my %no_request = map { $_ => 1 } map {"Admin::$_"} qw(users hooks cron quota runners);

my @files;
find(sub { push @files, $File::Find::name if /\.pm\z/ }, 'lib/WWW/Forgejo/API');

my ($methods, $controllers) = (0, 0);
for my $file (sort @files) {
    my $src = do { local (@ARGV, $/) = ($file); <> };
    my ($pkg) = $src =~ /^package ([\w:]+);/m or die "no package in $file";
    (my $short = $pkg) =~ s/^WWW::Forgejo::API:://;
    eval "require $pkg; 1" or die $@;
    $controllers++;

    my %seen;
    my @subs = grep { !/^_/ && !$seen{$_}++ } ($src =~ /^sub (\w+)/mg, $src =~ /^\*(\w+) = /mg);

    for my $sub (@subs) {
        my $name = "${short}::$sub";
        if ($no_request{$name}) {
            my ($client) = mock_client();
            isa_ok($pkg->new(client => $client)->$sub, 'WWW::Forgejo::API::' . $short . '::' . ucfirst $sub, "$name returns");
            next;
        }
        $methods++;

        my ($client, $io) = mock_client();
        my $ctl = $pkg->new(client => $client, owner => 'OWNER', repo => 'REPO');
        my @call = @{ $args{$name} || [ 'ARG1', 'ARG2', 'ARG3', 'ARG4' ] };

        # What happens to the canned answer afterwards is not this test's
        # business; only the requests are.
        { local $SIG{__WARN__} = sub { }; eval { $ctl->$sub(@call) }; }
        my $err = $@;

        if (!$io->count) {
            fail("$name sends a request") or diag("died with: $err");
            next;
        }

        for my $req (@{ $io->requests }) {
            (my $path = $req->url) =~ s{^https://forgejo\.test/api/v1}{};
            $path =~ s/\?.*//;
            (my $norm = $path) =~ s{(?<=/)(?:OWNER|REPO|ARG\d)(?:\.[^/.]+)?(?=/|\z)}{{}}g;
            my $op = $req->method . ' ' . $norm;
            if (my $expected = $outside_api{$name}) {
                (my $url = $req->url) =~ s{^https://forgejo\.test}{};
                is($req->method . ' ' . $url, $expected, "$name: $expected");
                next;
            }
            ok($operation{$op}, "$name: " . $req->method . " $path is an API operation");
        }
    }
}

# lib/WWW/Forgejo/API holds 47 controller modules: 10 top-level ones, 5 under
# Admin, 7 under Org and 25 under Repo. Fewer means the file scan missed some.
cmp_ok($controllers, '>=', 47, "all controllers visited ($controllers)");
cmp_ok($methods, '>', 200, "methods exercised ($methods)");

done_testing;
