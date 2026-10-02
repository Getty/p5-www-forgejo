#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Find;
use Pod::Checker;
use lib 't/lib';
use MockForgejo qw(mock_client);
use MethodChains qw(check_chains);
use WWW::Forgejo;

# The documentation against the code, module by module:
#
# - the names documented with =method / =attr are exactly the public methods
#   and attributes of the module: nothing undocumented, nothing documented
#   that is gone;
# - the SYNOPSIS compiles, declares no variable twice, and calls only methods
#   that exist (see t/lib/MethodChains.pm);
# - the POD has no syntax errors and no dangling internal links.
#
# Works on the source, where Pod::Weaver's =method / =attr are still there,
# and on the built distribution, where they have become =head2 entries below
# =head1 METHODS / ATTRIBUTES.

my @files;
find(sub { push @files, $File::Find::name if /\.pm\z/ }, 'lib');
cmp_ok(scalar @files, '>', 70, 'modules found (' . scalar(@files) . ')');

# Methods a class gets from elsewhere and that are documented there.
my %not_its_own = map { $_ => 1 } qw(new can does DOES isa VERSION BUILD BUILDARGS DEMOLISH DESTROY meta);

sub slurp {
    my ($file) = @_;
    open my $fh, '<', $file or die "$file: $!";
    local $/;
    return scalar <$fh>;
}

# name => 'method' | 'attr' | 'required', from the POD. A role lists what it
# requires of its consumer below a =head1 REQUIRED ... heading.
sub documented {
    my ($src) = @_;
    my (%doc, $section);
    for my $line (split /\n/, $src) {
        if ($line =~ /^=head1\s+(.+?)\s*$/) {
            $section = $1;
        }
        elsif ($line =~ /^=(method|attr)\s+(\w+)/) {
            $doc{$2} = $1;
            $section = undef;    # a directive block is not part of the section before it
        }
        elsif (defined $section && $section =~ /^REQUIRED /) {
            $doc{$1} = 'required' if $line =~ /^=head2\s+(\w+)/ || $line =~ /^=item \* C<(\w+)>/;
        }
        elsif (defined $section && $line =~ /^=head2\s+(\w+)/) {
            $doc{$1} = 'attr'   if $section eq 'ATTRIBUTES';
            $doc{$1} = 'method' if $section eq 'METHODS';
        }
    }
    return \%doc;
}

# name => 'method' | 'attr' | 'required' | 'generated' (a predicate, an
# attribute declared in a loop), from the code: what the module itself defines.
sub public {
    my ($module, $src) = @_;
    (my $code = $src) =~ s/^__END__.*//ms;
    $code =~ s/^=[a-zA-Z].*?^=cut[ \t]*$//msg;

    my %pub;
    $pub{$_} = 'method'   for $code =~ /^sub ([a-z]\w*)/mg;
    $pub{$_} = 'required' for $code =~ /^requires '([a-z]\w*)';/mg;
    while ($code =~ /^has\s+(?:\[\s*qw\(([^)]*)\)\s*\]|['"]?(\w+)['"]?)\s*=>/mg) {
        $pub{$_} = 'attr' for grep { !/^_/ } split ' ', $1 // $2;
    }

    # Attributes declared in a loop, predicates and the like do not show up
    # as `has name` / `sub name`: take what the class itself ended up with.
    # What a role or a parent class brought along is theirs to document.
    if ($module->can('new')) {
        no strict 'refs';
        my %theirs;
        for my $source (grep { $_ ne $module } @{ mro::get_linear_isa($module) }, roles_of($module)) {
            $theirs{$_} = 1 for grep { defined &{"${source}::$_"} } keys %{"${source}::"};
        }
        for my $name (grep { defined &{"${module}::$_"} } keys %{"${module}::"}) {
            next if $name =~ /^_/ || $not_its_own{$name} || $pub{$name};
            next if $theirs{$name} && $code !~ /^sub \Q$name\E\b/m;
            $pub{$name} = 'generated';
        }
    }
    return \%pub;
}

sub roles_of {
    my ($module) = @_;
    return grep { $_ ne $module } keys %{ $Role::Tiny::APPLIED_TO{$module} || {} };
}

# Objects the variables of the SYNOPSIS blocks stand for.
my ($client, $io) = mock_client();
my %synopsis_vars = (
    forgejo => $client,
    client  => $client,
    repo    => WWW::Forgejo::Entity::Repo->new(client => $client, owner => 'o', repo => 'r'),
    org     => WWW::Forgejo::Entity::Org->new(client => $client, data => { name => 'org' }),
);

# Everything loaded up front: a SYNOPSIS may use any class of the distribution.
for my $file (@files) {
    (my $path = $file) =~ s{^lib/}{};
    require $path;
}

my $synopsis_calls = 0;
for my $file (sort @files) {
    (my $module = $file) =~ s{^lib/}{};
    $module =~ s{/}{::}g;
    $module =~ s{\.pm\z}{};
    my $src = slurp($file);

    subtest "$module: documented names" => sub {
        my $doc = documented($src);
        my $pub = public($module, $src);

        my @undocumented = grep { !$doc->{$_} } sort keys %$pub;
        is_deeply(\@undocumented, [], 'every public method and attribute is documented');

        # Documenting an internal method is fine as long as it exists.
        my @gone = grep { !$pub->{$_} && !(/^_/ && $src =~ /^sub \Q$_\E\b/m) } sort keys %$doc;
        is_deeply(\@gone, [], 'everything documented exists');

        my @wrong = grep { $pub->{$_} && $pub->{$_} ne 'generated' && $pub->{$_} ne $doc->{$_} } sort keys %$doc;
        is_deeply(\@wrong, [], 'attributes are documented as attributes, methods as methods');
    };

    subtest "$module: POD syntax" => sub {
        # podchecker does not know the weaver directives; give it what the
        # weaver makes of them.
        (my $pod = $src) =~ s/^=(?:method|attr)\b/=head2/mg;
        my $report = "";
        open my $in,  "<", \$pod    or die $!;
        open my $out, ">", \$report or die $!;
        my $checker = Pod::Checker->new(-warnings => 0);
        $checker->parse_from_file($in, $out);
        cmp_ok($checker->num_errors, "==", 0, "no POD errors") or diag $report;
    };

    subtest "$module: SYNOPSIS" => sub {
        my ($synopsis) = $src =~ /^=head1 SYNOPSIS\n(.*?)(?=^=(?:head1|cut)\b)/ms;
        ok(defined $synopsis && $synopsis =~ /\S/, 'has a SYNOPSIS') or return;

        # Compiled, never run. Variables the reader is expected to bring along
        # ($token, $forgejo, ...) are not declared, hence no strict 'vars'.
        my @warnings;
        {
            local $SIG{__WARN__} = sub { push @warnings, @_ };
            my $ok = eval "package MockForgejo::Synopsis; no strict; use warnings; sub { $synopsis\n }; 1";
            ok($ok, 'compiles') or diag $@;
        }
        my @twice = grep { /masks earlier declaration/ } @warnings;
        is_deeply(\@twice, [], 'declares no variable twice');

        my $result = check_chains(
            $synopsis,
            io        => $io,
            vars      => \%synopsis_vars,
            instances => { "WWW::Forgejo" => $client, "My::Forgejo::Client" => $client },
            new_args  => {
                client => $client, data => {}, owner => "o", repo => "r",
                method => "GET", url => "http://localhost/", status => 200,
            },
        );
        is_deeply($result->{errors}, [], "calls only methods that exist") or diag join "\n", @{ $result->{errors} };
        is_deeply($result->{unverified}, [], "every method call could be attributed to a class")
            or diag join "\n", @{ $result->{unverified} };
        $synopsis_calls += $result->{checked};
    };
}

subtest 'README.md: the Perl examples' => sub {
    plan skip_all => 'no README.md in this tree' unless -e 'README.md';
    my @blocks = slurp('README.md') =~ /^```perl\n(.*?)^```$/msg;
    cmp_ok(scalar @blocks, '>=', 5, 'Perl examples found (' . scalar(@blocks) . ')');

    # The examples build on each other, like the sections of the README do.
    my $code = join "\n", @blocks;
    my @warnings;
    {
        local $SIG{__WARN__} = sub { push @warnings, @_ };
        my $ok = eval "package MockForgejo::Readme; no strict; use warnings; sub { $code\n }; 1";
        ok($ok, 'compile') or diag $@;
    }
    my $result = check_chains(
        $code,
        io        => $io,
        vars      => \%synopsis_vars,
        instances => { "WWW::Forgejo" => $client, "My::IO" => $io },    # My::IO: the made-up transport
    );
    is_deeply($result->{errors}, [], "call only methods that exist") or diag join "\n", @{ $result->{errors} };
    is_deeply($result->{unverified}, [], "every method call could be attributed to a class")
        or diag join "\n", @{ $result->{unverified} };
};

cmp_ok($synopsis_calls, '>', 150, "method calls in the SYNOPSIS blocks checked ($synopsis_calls)");

done_testing;
