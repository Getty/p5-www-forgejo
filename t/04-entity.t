use strict;
use warnings;
use Test::More;
use Scalar::Util qw(isweak);

use lib 'lib';

use WWW::Forgejo::Entity;
use WWW::Forgejo::Entity::User;
use WWW::Forgejo::Entity::Release;
use WWW::Forgejo::Entity::Repo;

# A stand-in client. The entity 'client' attribute carries no type
# constraint, so any reference is an acceptable value.
sub mock_client { bless {}, 'MockClient' }

subtest 'concrete entities extend the base WWW::Forgejo::Entity' => sub {
    my $client = mock_client();

    my $user = WWW::Forgejo::Entity::User->new(
        client => $client,
        data   => { id => 1, login => 'alice', email => 'alice@example.com' },
    );
    my $rel = WWW::Forgejo::Entity::Release->new(
        client => $client,
        owner  => 'alice',
        repo   => 'proj',
        data   => { id => 7, tag_name => 'v1.0', name => 'First cut' },
    );
    my $repo = WWW::Forgejo::Entity::Repo->new(
        client => $client,
        owner  => 'alice',
        repo   => 'proj',
        data   => { id => 42, name => 'proj' },
    );

    isa_ok($user, 'WWW::Forgejo::Entity', 'Entity::User (non-repo-scoped)');
    isa_ok($rel,  'WWW::Forgejo::Entity', 'Entity::Release (repo-scoped)');
    isa_ok($repo, 'WWW::Forgejo::Entity', 'Entity::Repo (repo-scoped)');
};

subtest 'inherited client attribute is a weak reference' => sub {
    my $client = mock_client();

    my $user = WWW::Forgejo::Entity::User->new(
        client => $client,
        data   => { id => 1, login => 'alice' },
    );
    my $rel = WWW::Forgejo::Entity::Release->new(
        client => $client,
        owner  => 'alice',
        repo   => 'proj',
        data   => { id => 7 },
    );

    ok(isweak($user->{client}), 'Entity::User stored client is weak');
    ok(isweak($rel->{client}),  'Entity::Release stored client is weak');

    # Behavioural proof: drop the only strong external ref and the weak
    # slot clears itself. On the old non-weak attribute it would persist.
    my $obj;
    {
        my $scoped_client = mock_client();
        $obj = WWW::Forgejo::Entity::User->new(
            client => $scoped_client,
            data   => { id => 2, login => 'bob' },
        );
        ok(defined $obj->client, 'client present while a strong ref is in scope');
    }
    is($obj->client, undef,
        'client cleared once the last strong ref leaves scope (weak_ref)');
};

subtest 'inherited update/delete croak stubs' => sub {
    my $client = mock_client();

    my $rel = WWW::Forgejo::Entity::Release->new(
        client => $client,
        owner  => 'alice',
        repo   => 'proj',
        data   => { id => 7 },
    );
    eval { $rel->update };
    like($@, qr/update not implemented for WWW::Forgejo::Entity::Release/,
        'Release inherits the base update() croak stub');
    eval { $rel->delete };
    like($@, qr/delete not implemented for WWW::Forgejo::Entity::Release/,
        'Release inherits the base delete() croak stub');

    my $user = WWW::Forgejo::Entity::User->new(
        client => $client,
        data   => { id => 1 },
    );
    eval { $user->update };
    like($@, qr/update not implemented for WWW::Forgejo::Entity::User/,
        'User inherits the base update() croak stub');
    eval { $user->delete };
    like($@, qr/delete not implemented for WWW::Forgejo::Entity::User/,
        'User inherits the base delete() croak stub');
};

subtest 'concrete-specific attributes and field accessors survive' => sub {
    my $client = mock_client();

    my $user = WWW::Forgejo::Entity::User->new(
        client => $client,
        data   => { id => 1, login => 'alice', email => 'alice@example.com' },
    );
    is($user->id,    1,                   'User->id');
    is($user->login, 'alice',             'User->login');
    is($user->email, 'alice@example.com', 'User->email');

    my $rel = WWW::Forgejo::Entity::Release->new(
        client => $client,
        owner  => 'alice',
        repo   => 'proj',
        data   => { id => 7, tag_name => 'v1.0', name => 'First cut' },
    );
    is($rel->id,       7,           'Release->id');
    is($rel->tag_name, 'v1.0',      'Release->tag_name');
    is($rel->name,     'First cut', 'Release->name');
    is($rel->owner,    'alice',     'Release->owner (repo-scoped attr kept)');
    is($rel->repo,     'proj',      'Release->repo (repo-scoped attr kept)');
    like($rel->data_json, qr/"tag_name"\s*:\s*"v1\.0"/,
        'Release->data_json still serialises data');
};

subtest 'inherited data attribute is optional (defaults to {})' => sub {
    my $client = mock_client();

    my $user;
    my $ok = eval {
        $user = WWW::Forgejo::Entity::User->new(client => $client);
        1;
    };
    ok($ok, 'construct a concrete without data (inherits base optional data)')
        or diag $@;
    is_deeply($user->data, {}, 'data defaults to an empty hashref');
};

done_testing;
