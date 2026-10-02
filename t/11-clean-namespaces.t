#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Find;

# Every module loads without a single warning, carries its own $VERSION and
# keeps the functions it imports out of its method namespace.

my @warnings;
local $SIG{__WARN__} = sub { push @warnings, @_ };

my @modules;
find(sub {
    return unless /\.pm\z/;
    (my $module = $File::Find::name) =~ s{^lib/}{};
    $module =~ s{/}{::}g;
    $module =~ s{\.pm\z}{};
    push @modules, $module;
}, 'lib');
cmp_ok(scalar @modules, '>', 70, 'modules found (' . scalar(@modules) . ')');

for my $module (sort @modules) {
    @warnings = ();
    ok(eval "require $module; 1", "$module loads") or diag $@;
    is_deeply(\@warnings, [], "$module loads without warnings");

    no strict 'refs';
    is(${"${module}::VERSION"}, '0.001', "$module has a \$VERSION");

    # Imported helpers and the Moo sugar must not be callable as methods.
    my @leaked = grep { $module->can($_) }
        qw(croak carp uri_escape encode_json decode_json has extends with requires around
           before after DEFAULT_MAX_PAGES);
    is_deeply(\@leaked, [], "$module leaks no imported functions as methods");
}

subtest 'the client keeps its public interface' => sub {
    can_ok('WWW::Forgejo', qw(
        new url base_url token io get post put patch delete check
        _build_request _parse_response _request _request_with_response _set_auth
        misc users orgs teams notifications packages repos current_user admin activitypub
    ));
};

subtest 'alias methods survive the cleanup' => sub {
    my %alias = (
        'WWW::Forgejo::API::Repo::Issues'            => [qw(edit update list_comments comments list_labels labels)],
        'WWW::Forgejo::API::Repo::PullRequests'      => [qw(edit update)],
        'WWW::Forgejo::API::Repo::Milestones'        => [qw(edit update)],
        'WWW::Forgejo::API::Repo::Releases'          => [qw(edit update)],
        'WWW::Forgejo::API::Repo::Hooks'             => [qw(edit update)],
        'WWW::Forgejo::API::Repo::Labels'            => [qw(edit update)],
        'WWW::Forgejo::API::Repo::BranchProtections' => [qw(edit update)],
        'WWW::Forgejo::API::Repo::TagProtections'    => [qw(edit update)],
    );
    can_ok($_, @{ $alias{$_} }) for sort keys %alias;
};

subtest 'value objects and backends keep their interface' => sub {
    can_ok('WWW::Forgejo::HTTPRequest',  qw(new method url headers content has_content));
    can_ok('WWW::Forgejo::HTTPResponse', qw(new status content headers));
    can_ok('WWW::Forgejo::LWPIO',        qw(new call ua timeout));
    ok(WWW::Forgejo::LWPIO->does('WWW::Forgejo::Role::IO'), 'LWPIO does Role::IO');
    ok(WWW::Forgejo->does('WWW::Forgejo::Role::HTTP'),      'client does Role::HTTP');
};

done_testing;
