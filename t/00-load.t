use strict;
use warnings;
use Test::More;

use lib 'lib';

use_ok($_) for grep { !/\bJSONRPC\b/ } (<<'...');
  WWW::Forgejo
  WWW::Forgejo::HTTPRequest
  WWW::Forgejo::HTTPResponse
  WWW::Forgejo::LWPIO
  WWW::Forgejo::Role::HTTP
  WWW::Forgejo::Role::IO
...

done_testing;