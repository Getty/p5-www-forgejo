# ABSTRACT: Forgejo Admin Quota API
# PODNAME: WWW::Forgejo::API::Admin::Quota

use strict;
use warnings;

package WWW::Forgejo::API::Admin::Quota;

use Moo;
use Carp qw(croak);
use WWW::Forgejo::URL qw( escape_component );
use WWW::Forgejo::Entity::QuotaGroup;
use WWW::Forgejo::Entity::QuotaRule;
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

sub _group {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::QuotaGroup->new(client => $self->client, data => $data);
}

sub _rule {
    my ($self, $data) = @_;
    return WWW::Forgejo::Entity::QuotaRule->new(client => $self->client, data => $data);
}

# /admin/quota/groups/{group}/... of the quota group the method addresses.
sub _group_path {
    my ($self, $name, @path) = @_;
    croak "Quota group name required" unless defined $name && length $name;
    return join '/', '/admin/quota/groups', escape_component($name), @path;
}

# /admin/quota/rules/{rule} of the quota rule the method addresses.
sub _rule_path {
    my ($self, $name) = @_;
    croak "Quota rule name required" unless defined $name && length $name;
    return '/admin/quota/rules/' . escape_component($name);
}

=method list_groups

    my $groups = $forgejo->admin->quota->list_groups;

List all quota groups (C<GET /admin/quota/groups>). Returns an arrayref of
L<WWW::Forgejo::Entity::QuotaGroup> objects.

=cut

sub list_groups {
    my ($self) = @_;
    my $data = $self->client->get('/admin/quota/groups');
    return [ map { $self->_group($_) } @{$data} ];
}

=method get_group

    my $group = $forgejo->admin->quota->get_group($name);

Get a specific quota group by name (C<GET /admin/quota/groups/{group}>).
Returns a L<WWW::Forgejo::Entity::QuotaGroup>.

=cut

sub get_group {
    my ($self, $name) = @_;
    return $self->_group($self->client->get($self->_group_path($name)));
}

=method create_group

    my $group = $forgejo->admin->quota->create_group(
        name  => 'mygroup',
        rules => [ { name => 'myrule', limit => 1024, subjects => ['size:repos:all'] } ],
    );

Create a quota group (C<POST /admin/quota/groups>). The key/value pairs are
sent as the JSON body; C<name>, the name of the group, is required. The rules
of the group are given in C<rules>, a list of quota rules to create with it.
Returns a L<WWW::Forgejo::Entity::QuotaGroup>.

=cut

sub create_group {
    my ($self, %params) = @_;
    croak "Quota group name required" unless $params{name};
    return $self->_group($self->client->post('/admin/quota/groups', \%params));
}

=method delete_group

    $forgejo->admin->quota->delete_group($name);

Delete a quota group (C<DELETE /admin/quota/groups/{group}>). The rules of the
group stay; they are rules of their own.

=cut

sub delete_group {
    my ($self, $name) = @_;
    return $self->client->delete($self->_group_path($name));
}

=method list_rules

    my $rules = $forgejo->admin->quota->list_rules;

List all quota rules (C<GET /admin/quota/rules>). Returns an arrayref of
L<WWW::Forgejo::Entity::QuotaRule> objects.

=cut

sub list_rules {
    my ($self) = @_;
    my $data = $self->client->get('/admin/quota/rules');
    return [ map { $self->_rule($_) } @{$data} ];
}

=method get_rule

    my $rule = $forgejo->admin->quota->get_rule($name);

Get a specific quota rule by name (C<GET /admin/quota/rules/{rule}>). Returns
a L<WWW::Forgejo::Entity::QuotaRule>.

=cut

sub get_rule {
    my ($self, $name) = @_;
    return $self->_rule($self->client->get($self->_rule_path($name)));
}

=method create_rule

    my $rule = $forgejo->admin->quota->create_rule(
        name     => 'myrule',
        limit    => 1024,
        subjects => ['size:repos:all'],
    );

Create a quota rule (C<POST /admin/quota/rules>). The key/value pairs are sent
as the JSON body; C<name>, the name of the rule, is required, C<limit> is the
limit the rule sets and C<subjects> are the subjects it applies to. Returns a
L<WWW::Forgejo::Entity::QuotaRule>.

=cut

sub create_rule {
    my ($self, %params) = @_;
    croak "Quota rule name required" unless $params{name};
    return $self->_rule($self->client->post('/admin/quota/rules', \%params));
}

=method edit_rule

    my $rule = $forgejo->admin->quota->edit_rule($name, limit => 2048);

Edit a quota rule (C<PATCH /admin/quota/rules/{rule}>). The key/value pairs
are sent as the JSON body: C<limit> is the new limit of the rule and
C<subjects> its new subjects. Returns a L<WWW::Forgejo::Entity::QuotaRule>.

=cut

sub edit_rule {
    my ($self, $name, %params) = @_;
    return $self->_rule($self->client->patch($self->_rule_path($name), \%params));
}

=method delete_rule

    $forgejo->admin->quota->delete_rule($name);

Delete a quota rule (C<DELETE /admin/quota/rules/{rule}>).

=cut

sub delete_rule {
    my ($self, $name) = @_;
    return $self->client->delete($self->_rule_path($name));
}

=method add_rule_to_group

    $forgejo->admin->quota->add_rule_to_group($group, $rule);

Add a quota rule to a quota group (C<PUT
/admin/quota/groups/{group}/rules/{rule}>). Returns true; the API sends no
data back.

=cut

sub add_rule_to_group {
    my ($self, $group, $rule) = @_;
    croak "Quota rule name required" unless defined $rule && length $rule;
    $self->client->put($self->_group_path($group, 'rules', escape_component($rule)));
    return 1;
}

=method remove_rule_from_group

    $forgejo->admin->quota->remove_rule_from_group($group, $rule);

Remove a quota rule from a quota group (C<DELETE
/admin/quota/groups/{group}/rules/{rule}>). The rule itself stays.

=cut

sub remove_rule_from_group {
    my ($self, $group, $rule) = @_;
    croak "Quota rule name required" unless defined $rule && length $rule;
    return $self->client->delete($self->_group_path($group, 'rules', escape_component($rule)));
}

=method list_group_users

    my $users = $forgejo->admin->quota->list_group_users($group);

List the users of a quota group (C<GET /admin/quota/groups/{group}/users>).
Returns the users as plain Perl data, in an arrayref.

=cut

sub list_group_users {
    my ($self, $group) = @_;
    return $self->client->get($self->_group_path($group, 'users'));
}

=method add_user_to_group

    $forgejo->admin->quota->add_user_to_group($group, $username);

Add a user to a quota group (C<PUT /admin/quota/groups/{group}/users/{username}>).
Returns true; the API sends no data back.

=cut

sub add_user_to_group {
    my ($self, $group, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    $self->client->put($self->_group_path($group, 'users', escape_component($username)));
    return 1;
}

=method remove_user_from_group

    $forgejo->admin->quota->remove_user_from_group($group, $username);

Remove a user from a quota group (C<DELETE
/admin/quota/groups/{group}/users/{username}>).

=cut

sub remove_user_from_group {
    my ($self, $group, $username) = @_;
    croak "Username required" unless defined $username && length $username;
    return $self->client->delete($self->_group_path($group, 'users', escape_component($username)));
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $groups = $forgejo->admin->quota->list_groups;
    my $group  = $forgejo->admin->quota->get_group($name);

    my $rules = $forgejo->admin->quota->list_rules;
    my $rule  = $forgejo->admin->quota->create_rule(name => 'myrule', limit => 1024);

    $forgejo->admin->quota->add_user_to_group($name, $username);

=head1 DESCRIPTION

The C</admin/quota/...> site administration endpoints: the quota groups, the
quota rules and the rules and users of a group. It is obtained through
L<WWW::Forgejo::API::Admin/quota>.

Quota groups and quota rules are returned as
L<WWW::Forgejo::Entity::QuotaGroup> and L<WWW::Forgejo::Entity::QuotaRule>
objects; the users of a group are returned as plain Perl data, like the users
of every other endpoint of the client.

=head1 SEE ALSO

L<WWW::Forgejo::API::Admin>, L<WWW::Forgejo::Entity::QuotaGroup>,
L<WWW::Forgejo::Entity::QuotaRule>, L<WWW::Forgejo>

=cut
