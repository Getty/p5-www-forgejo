#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);
use WWW::Forgejo::API::Misc;

# The endpoints of the instance the client did not cover yet: the single
# license, gitignore and label templates, the raw markdown renderer, the
# workflow run of the token and the settings sections.
#
# Every call is made in an eval, so a method that does not exist shows up as a
# failed test instead of a dead file.

my ($client, $io) = mock_client();
my $base = 'https://forgejo.test/api/v1';

my $misc = WWW::Forgejo::API::Misc->new(client => $client);

sub request {
    my $last = $io->last or return '(no request)';
    return $last->method . ' ' . path();
}

sub path {
    my $last = $io->last or return '(no request)';
    my $url = substr($last->url, length $base);
    $url =~ s/\?.*//;
    return $url;
}

sub url {
    my $last = $io->last or return '';
    return $last->url;
}

sub body {
    my $last = $io->last or return {};
    return $last->has_content ? decode_json($last->content) : {};
}

sub content {
    my $last = $io->last or return '';
    return $last->has_content ? $last->content : '';
}

sub header {
    my $last = $io->last or return '';
    my $name = shift;
    return ($last->headers->{$name} || '');
}

# The value of an expression, or undef when it dies.
sub value { return eval { $_[0]->() } }

# The message of the exception of an expression, or the empty string.
sub error {
    my $err = '';
    eval { $_[0]->() };
    $err = $@ if $@;
    return $err;
}

# ---------------------------------------------------------------------------
# The templates
# ---------------------------------------------------------------------------

subtest 'one license' => sub {
    $io->reset->add(200, '{"name":"MIT","spdx_id":"MIT"}');
    my $license = value(sub { $misc->license('mit') });
    is(request(), 'GET /licenses/mit', 'GET /licenses/{name}');
    is($license->{spdx_id}, 'MIT', 'the license is decoded');
};

subtest 'the name of a license is escaped' => sub {
    $io->reset->add(200, '{}');
    value(sub { $misc->license('a/b') });
    is(path(), '/licenses/a%2Fb', 'the slash is escaped');
};

subtest 'one gitignore template' => sub {
    $io->reset->add(200, '{"name":"Go"}');
    my $template = value(sub { $misc->gitignore_template('Go') });
    is(request(), 'GET /gitignore/templates/Go', 'GET /gitignore/templates/{name}');
    is($template->{name}, 'Go', 'the template is decoded');
};

subtest 'one label template' => sub {
    $io->reset->add(200, '{"name":"bug"}');
    my $template = value(sub { $misc->label_template('bug') });
    is(request(), 'GET /label/templates/bug', 'GET /label/templates/{name}');
    is($template->{name}, 'bug', 'the template is decoded');
};

subtest 'the name of a template is required' => sub {
    $io->reset;
    ok(error(sub { $misc->license() }), 'license without a name dies');
    ok(error(sub { $misc->gitignore_template('') }), 'gitignore_template without a name dies');
    ok(error(sub { $misc->label_template(undef) }), 'label_template without a name dies');
    is($io->count, 0, 'no request was sent');
};

# ---------------------------------------------------------------------------
# The raw markdown renderer
# ---------------------------------------------------------------------------

subtest 'raw markdown' => sub {
    # The API answers with text/html, so the body is not JSON and comes back
    # as it was sent.
    $io->reset->add(200, '<h1>Hello</h1>');
    my $html = value(sub { $misc->markdown_raw('# Hello') });
    is(request(), 'POST /markdown/raw', 'POST /markdown/raw');
    is(content(), '# Hello', 'the markdown is the body of the request');
    is(header('Content-Type'), 'text/plain', 'the body is sent as plain text');
    is($html, '<h1>Hello</h1>', 'the HTML is returned');
};

subtest 'the markdown is required' => sub {
    $io->reset;
    ok(error(sub { $misc->markdown_raw('') }), 'markdown_raw without text dies');
    is($io->count, 0, 'no request was sent');
};

# ---------------------------------------------------------------------------
# The workflow run of the token and the settings
# ---------------------------------------------------------------------------

subtest 'the workflow run of the token' => sub {
    $io->reset->add(200, '{"id":1}');
    my $run = value(sub { $misc->action_run });
    is(request(), 'GET /actions/run', 'GET /actions/run');
    is($run->{id}, 1, 'the run is decoded');
};

subtest 'one section of the settings' => sub {
    $io->reset->add(200, '{"disabled":false}');
    my $api = value(sub { $misc->settings('api') });
    is(request(), 'GET /settings/api', 'GET /settings/{section}');
    ok(!$api->{disabled}, 'the section is decoded');
};

subtest 'the name of the section is required' => sub {
    $io->reset;
    ok(error(sub { $misc->settings() }), 'settings without a section dies');
    is($io->count, 0, 'no request was sent');
};

done_testing;
