use strict;
use warnings;
use Test::More;
use lib 'lib';
use WWW::Forgejo::HTTPResponse;

# (a) mixed-case header retrievable via lower-cased key; values preserved as-is
subtest 'headers keys are lower-cased, values preserved' => sub {
    my $res = WWW::Forgejo::HTTPResponse->new(
        status  => 200,
        content => '{"ok":true}',
        headers => {
            'X-Total-Count' => 5,
            'Content-Type'  => 'application/json',
        },
    );
    is($res->headers->{'x-total-count'}, 5,
        'X-Total-Count retrievable via lower-cased key, value preserved');
    is($res->headers->{'content-type'}, 'application/json',
        'Content-Type retrievable via lower-cased key, value preserved');
    ok(!exists $res->headers->{'X-Total-Count'},
        'original mixed-case key is not present');
};

# (b) headers defaults to {} when omitted
subtest 'headers defaults to empty hashref' => sub {
    my $res = WWW::Forgejo::HTTPResponse->new(status => 204);
    is_deeply($res->headers, {}, 'headers is {} when omitted');
};

# (c) status/content still work
subtest 'status and content still work' => sub {
    my $res = WWW::Forgejo::HTTPResponse->new(status => 201, content => 'hi');
    is($res->status, 201, 'status preserved');
    is($res->content, 'hi', 'content preserved');

    my $default = WWW::Forgejo::HTTPResponse->new(status => 200);
    is($default->content, '', 'content defaults to empty string');
};

done_testing;
