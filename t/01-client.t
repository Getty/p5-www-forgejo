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
    is($client->url, 'https://src.ci', 'url keeps the raw instance URL as given');
    is($client->base_url, 'https://src.ci/api/v1', 'url gets /api/v1 appended');
    is($client->token, 'test-token');
};

subtest '/api/v1 auto-append is idempotent' => sub {
    is(
        WWW::Forgejo->new(url => 'https://src.ci')->base_url,
        'https://src.ci/api/v1',
        'bare host gets /api/v1 appended',
    );
    is(
        WWW::Forgejo->new(url => 'https://src.ci/')->base_url,
        'https://src.ci/api/v1',
        'trailing slash is normalised before appending',
    );
    is(
        WWW::Forgejo->new(url => 'https://src.ci/api/v1')->base_url,
        'https://src.ci/api/v1',
        'already-suffixed url is left unchanged (no double-append)',
    );
    is(
        WWW::Forgejo->new(url => 'https://src.ci/api/v1/')->base_url,
        'https://src.ci/api/v1',
        'already-suffixed url with trailing slash is left unchanged',
    );
};

subtest 'ENV fallback for url and token' => sub {
    local $ENV{FORGEJO_URL}   = 'https://env.example';
    local $ENV{FORGEJO_TOKEN} = 'env-token';
    my $client = WWW::Forgejo->new;
    is($client->base_url, 'https://env.example/api/v1', 'base_url resolved from FORGEJO_URL');
    is($client->token, 'env-token', 'token resolved from FORGEJO_TOKEN');
};

subtest 'explicit args win over ENV' => sub {
    local $ENV{FORGEJO_URL}   = 'https://env.example';
    local $ENV{FORGEJO_TOKEN} = 'env-token';
    my $client = WWW::Forgejo->new(
        url   => 'https://explicit.example',
        token => 'explicit-token',
    );
    is($client->base_url, 'https://explicit.example/api/v1', 'explicit url wins over FORGEJO_URL');
    is($client->token, 'explicit-token', 'explicit token wins over FORGEJO_TOKEN');
};

subtest 'croak with help when neither url nor FORGEJO_URL is set' => sub {
    delete local $ENV{FORGEJO_URL};
    eval { WWW::Forgejo->new };
    my $err = $@;
    ok($err, 'construction without url or FORGEJO_URL croaks');
    like($err, qr/FORGEJO_URL/, 'error names the FORGEJO_URL environment variable');
    like($err, qr/\burl\b/, 'error names the url option');
};

subtest 'missing token does not croak at construction' => sub {
    delete local $ENV{FORGEJO_TOKEN};
    my $client = WWW::Forgejo->new(url => 'https://src.ci');
    is($client->token, '', 'token falls back to empty string, no croak at construction');
};

subtest 'auth error' => sub {
    delete local $ENV{FORGEJO_TOKEN};
    eval { WWW::Forgejo->new(url => 'https://src.ci', token => '')->get('/test') };
    like($@, qr/No API token configured/i, 'empty token croaks at call time');
};

done_testing;
