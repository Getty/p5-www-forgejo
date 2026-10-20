#!/usr/bin/env perl
use strict;
use warnings;
use File::Spec;
use FindBin;
use Test::More;

# The cpanfile is what the installer reads. A module the code loads but the
# cpanfile does not name is not missing at build time, it is missing when the
# library is loaded on a machine where the module is not installed yet.
#
# The list below is the runtime chain of lib/ plus the modules the tests
# load, named by the distribution that ships them. Where module and
# distribution differ, the distribution counts, so both names are accepted in
# the cpanfile: HTTP::Request comes with HTTP::Message, Moo::Role comes with
# Moo and URI::Escape comes with URI.

my $cpanfile = File::Spec->catfile( $FindBin::Bin, File::Spec->updir, 'cpanfile' );

plan skip_all => 'cpanfile is not part of the distribution' unless -f $cpanfile;

# the prerequisites of the cpanfile, per phase
my %requires = ( runtime => {}, test => {} );
{
    open my $fh, '<', $cpanfile or die "cannot read $cpanfile: $!";
    my $phase = 'runtime';
    while ( my $line = <$fh> ) {
        if ( $line =~ /^\s*on\s+(\w+)\s*=>\s*sub\s*\{/ ) {
            $phase = $1;
            next;
        }
        if ( $phase ne 'runtime' && $line =~ /^\s*\};/ ) {
            $phase = 'runtime';
            next;
        }
        next unless $line =~ /^\s*requires\s+'([^']+)'/;
        $requires{$phase}{$1} = 1;
    }
    close $fh;
}

my @runtime = (
    [ 'HTTP::Request'        => qw( HTTP::Request HTTP::Message ) ],
    [ 'HTTP::Request::Common' => qw( HTTP::Request::Common HTTP::Message ) ],
    [ 'JSON::MaybeXS'         => qw( JSON::MaybeXS ) ],
    [ 'LWP::UserAgent'        => qw( LWP::UserAgent ) ],
    [ 'Log::Any'              => qw( Log::Any ) ],
    [ 'Moo'                   => qw( Moo Moo::Role ) ],
    [ 'URI::Escape'           => qw( URI::Escape URI ) ],
    [ 'namespace::clean'      => qw( namespace::clean ) ],
);

my @test = (
    [ 'HTTP::Response' => qw( HTTP::Response HTTP::Message HTTP::Request ) ],
    [ 'JSON::MaybeXS'  => qw( JSON::MaybeXS ) ],
    [ 'Moo'            => qw( Moo ) ],
    [ 'Test::More'     => qw( Test::More ) ],
);

# a name the cpanfile accepts for a module
sub declared {
    my ( $phase, @names ) = @_;
    for my $name ( @names ) {
        return 1 if $requires{$phase}{$name};
    }
    return 0;
}

# a runtime prerequisite has to sit in the runtime phase: a name in the test
# phase alone is not installed when the distribution is applied
for my $entry ( @runtime ) {
    my ( $module, @names ) = @$entry;
    ok( declared( 'runtime', @names ), "$module is a declared prerequisite" );
}

# a test prerequisite is fine in the test phase or in the runtime phase, the
# runtime phase is installed either way
for my $entry ( @test ) {
    my ( $module, @names ) = @$entry;
    ok( declared( 'test', @names ) || declared( 'runtime', @names ),
        "$module is a declared prerequisite for the tests" );
}

done_testing;
