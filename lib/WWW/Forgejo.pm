# ABSTRACT: Perl client for the Forgejo API v1
# PODNAME: WWW::Forgejo

use strict;
use warnings;

package WWW::Forgejo;

use Moo;
use WWW::Forgejo::Role::HTTP;
use WWW::Forgejo::API::Misc;
use WWW::Forgejo::API::Users;
use WWW::Forgejo::API::Orgs;
use WWW::Forgejo::API::Teams;
use WWW::Forgejo::API::Notifications;
use WWW::Forgejo::API::Packages;
use WWW::Forgejo::API::Repos;
use WWW::Forgejo::API::CurrentUser;
use WWW::Forgejo::API::Admin;
use namespace::clean;

our $VERSION = '0.001';

has token => (
    is      => 'ro',
    default => sub { '' },
);

has base_url => (
    is       => 'ro',
    init_arg => 'url',
    default  => sub { 'https://forgejo.example/api/v1' },
);

with 'WWW::Forgejo::Role::HTTP';

has misc => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::Misc->new(client => shift) },
);

has users => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::Users->new(client => shift) },
);

has orgs => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::Orgs->new(client => shift) },
);

has teams => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::Teams->new(client => shift) },
);

has notifications => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::Notifications->new(client => shift) },
);

has packages => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::Packages->new(client => shift) },
);

has repos => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::Repos->new(client => shift) },
);

has current_user => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::CurrentUser->new(client => shift) },
);

has admin => (
    is      => 'lazy',
    builder => sub { WWW::Forgejo::API::Admin->new(client => shift) },
);

1;
__END__

=head1 SYNOPSIS

  use WWW::Forgejo;

  my $client = WWW::Forgejo->new(
    url   => 'https://src.ci',
    token => $ENV{FORGEJO_TOKEN},
  );

=cut