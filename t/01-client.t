use strict;
use warnings;
use Test::More;
use lib 'lib';
use WWW::Forgejo;

subtest 'construction' => sub {
    my $client = WWW::Forgejo->new(
        url   => 'https://src.ci',
        token => 'test-token',
    );
    isa_ok($client, 'WWW::Forgejo');
    is($client->base_url, 'https://src.ci');
    is($client->token, 'test-token');
};

subtest 'auth error' => sub {
    eval { WWW::Forgejo->new(token => '')->get('/test') };
    like($@, qr/No API token configured/i);
};

done_testing;