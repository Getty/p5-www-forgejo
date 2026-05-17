# WWW::Forgejo

Perl client for the Forgejo API v1.

## Synopsis

    use WWW::Forgejo;

    my $client = WWW::Forgejo->new(
      url   => 'https://src.ci',
      token => $ENV{FORGEJO_TOKEN},
    );

## Description

This distribution provides a Perl client library for the Forgejo API version 1.