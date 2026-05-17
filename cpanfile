requires 'Moo';
requires 'LWP::UserAgent';
requires 'JSON::MaybeXS';
requires 'HTTP::Request';
requires 'URI';
requires 'URI::Escape';
requires 'namespace::clean';
requires 'Log::Any';
requires 'Carp';

on test => sub {
    requires 'Test::More';
    requires 'Path::Tiny';
};