#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Find;

# Every module under lib/ compiles, without a warning, and declares its own
# $VERSION in the source (the release tooling rewrites `our $VERSION` per file;
# a module without one would ship versionless). Modules are found on disk, so
# a new one is covered without touching this file.

my @files;
find(sub { push @files, $File::Find::name if /\.pm\z/ }, 'lib');
cmp_ok(scalar @files, '>', 70, 'modules found (' . scalar(@files) . ')');

for my $file (sort @files) {
    (my $module = $file) =~ s{^lib/}{};
    $module =~ s{/}{::}g;
    $module =~ s{\.pm\z}{};

    my @warnings;
    {
        local $SIG{__WARN__} = sub { push @warnings, @_ };
        require_ok($module);
    }
    is_deeply(\@warnings, [], "$module loads without warnings");

    open my $fh, '<', $file or die "$file: $!";
    my $src = do { local $/; <$fh> };
    close $fh;

    my @packages = $src =~ /^package\s+([\w:]+)/mg;
    is_deeply(\@packages, [$module], "$file holds exactly the package $module");

    my @versions = $src =~ /^our \$VERSION = '([0-9._]+)';/mg;
    is(scalar @versions, 1, "$file declares our \$VERSION once");
    no strict 'refs';
    is(${"${module}::VERSION"}, $versions[0], "$module\::VERSION is the declared one");
}

done_testing;
