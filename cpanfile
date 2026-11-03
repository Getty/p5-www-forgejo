requires 'perl', '5.020';

requires 'Carp';
requires 'HTTP::Request';
requires 'HTTP::Request::Common';
requires 'JSON::MaybeXS';
requires 'Log::Any';
requires 'LWP::UserAgent';
requires 'MIME::Base64';
requires 'Moo';
requires 'namespace::clean';
requires 'URI::Escape';

# https:// instance URLs need it; plain-http instances do not, and Forgejo
# often runs without TLS inside a private network.
recommends 'LWP::Protocol::https';

on test => sub {
    requires 'File::Find';
    requires 'HTTP::Response';
    requires 'IO::Compress::Gzip';
    requires 'Scalar::Util';
    requires 'Test::More', '0.96';
};
