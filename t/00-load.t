use strict;
use warnings;
use Test::More;

use lib 'lib';

BEGIN {
    my @modules = qw(
        WWW::Forgejo
        WWW::Forgejo::HTTPRequest
        WWW::Forgejo::HTTPResponse
        WWW::Forgejo::LWPIO
        WWW::Forgejo::Role::HTTP
        WWW::Forgejo::Role::IO
    );

    for my $mod (@modules) {
        use_ok($mod);
    }
}

done_testing;