requires 'perl', '5.020';

requires 'Carp';
requires 'HTTP::Request';
requires 'HTTP::Request::Common';
requires 'JSON::MaybeXS';
requires 'LWP::UserAgent';
requires 'Log::Any';
requires 'Moo';
requires 'URI::Escape';
requires 'namespace::clean';

# https:// instance URLs need it; plain-http instances do not, and Forgejo
# often runs without TLS inside a private network.
recommends 'LWP::Protocol::https';

on test => sub {
    requires 'File::Find';
    requires 'HTTP::Response';
    requires 'Scalar::Util';
    requires 'Test::More', '0.96';
};
