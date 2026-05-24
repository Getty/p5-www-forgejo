# ABSTRACT: Forgejo Admin API
# PODNAME: WWW::Forgejo::API::Admin

use strict;
use warnings;

package WWW::Forgejo::API::Admin;

use Moo;
use Log::Any;

has client => (
    is       => 'ro',
    init_arg => 'client',
);

sub users {
    my $self = shift;
    require WWW::Forgejo::API::Admin::Users;
    return WWW::Forgejo::API::Admin::Users->new(client => $self->client);
}

sub hooks {
    my $self = shift;
    require WWW::Forgejo::API::Admin::Hooks;
    return WWW::Forgejo::API::Admin::Hooks->new(client => $self->client);
}

sub cron {
    my $self = shift;
    require WWW::Forgejo::API::Admin::Cron;
    return WWW::Forgejo::API::Admin::Cron->new(client => $self->client);
}

sub quota {
    my $self = shift;
    require WWW::Forgejo::API::Admin::Quota;
    return WWW::Forgejo::API::Admin::Quota->new(client => $self->client);
}

sub runners {
    my $self = shift;
    require WWW::Forgejo::API::Admin::Runners;
    return WWW::Forgejo::API::Admin::Runners->new(client => $self->client);
}

1;

__END__

=head1 SYNOPSIS

  my $admin = $forgejo->admin;
  my $users = $admin->users;

=head1 SEE ALSO

L<WWW::Forgejo>

=cut