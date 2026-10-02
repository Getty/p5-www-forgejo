# ABSTRACT: Forgejo Admin Users API
# PODNAME: WWW::Forgejo::API::Admin::Users

use strict;
use warnings;

package WWW::Forgejo::API::Admin::Users;

use Moo;
use URI::Escape qw(uri_escape);
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

=method list

    my $users = $forgejo->admin->users->list;

List all users. Named arguments are sent as the query string of the request.

The admin API has no call to read a single user; that is
L<WWW::Forgejo::API::Users/get> (C<< $forgejo->users->get($username) >>).

=cut

sub list {
    my ($self, %params) = @_;
    return $self->client->get('/admin/users', params => \%params);
}

=method create

    my $user = $forgejo->admin->users->create(
        username => 'testuser',
        email    => 'user@example.com',
        password => 'secret',
    );

Create a new user; the API requires C<username> and C<email>. The key/value
pairs are sent as the JSON body.

=cut

sub create {
    my ($self, %params) = @_;
    return $self->client->post('/admin/users', \%params);
}

=method edit

    my $user = $forgejo->admin->users->edit($username, full_name => 'New Name');

Edit an existing user (C<PATCH /admin/users/{username}>). The key/value
pairs are sent as the JSON body.

=cut

sub edit {
    my ($self, $username, %params) = @_;
    return $self->client->patch('/admin/users/' . uri_escape($username), \%params);
}

=method delete

    $forgejo->admin->users->delete($username);
    $forgejo->admin->users->delete($username, purge => 'true');

Delete a user. Named arguments are sent as the query string of the request.

=cut

sub delete {
    my ($self, $username, %params) = @_;
    return $self->client->delete('/admin/users/' . uri_escape($username), undef, params => \%params);
}

=method rename

    $forgejo->admin->users->rename($username, $new_username);

Rename a user (C<POST /admin/users/{username}/rename>).

=cut

sub rename {
    my ($self, $username, $new_username) = @_;
    return $self->client->post('/admin/users/' . uri_escape($username) . '/rename', { new_username => $new_username });
}

=method list_emails

    my $emails = $forgejo->admin->users->list_emails($username);

List the email addresses of a user.

=cut

sub list_emails {
    my ($self, $username) = @_;
    return $self->client->get('/admin/users/' . uri_escape($username) . '/emails');
}

=method delete_email

    $forgejo->admin->users->delete_email($username, 'old@example.com');

Delete one or more email addresses of a user (C<DELETE
/admin/users/{username}/emails>, the addresses travel in the request body).

=cut

sub delete_email {
    my ($self, $username, @emails) = @_;
    return $self->client->delete('/admin/users/' . uri_escape($username) . '/emails', { emails => \@emails });
}

=method search_emails

    my $results = $forgejo->admin->users->search_emails(q => 'example.com');

Search all email addresses of the instance (C<GET /admin/emails/search>);
C<q> is the search term. Named arguments are sent as the query string of the
request.

=cut

sub search_emails {
    my ($self, %params) = @_;
    return $self->client->get('/admin/emails/search', params => \%params);
}

=method add_key

    my $key = $forgejo->admin->users->add_key($username, title => 'My Key', key => $public_key);

Add a public key to a user. The key/value pairs are sent as the JSON body.

=cut

sub add_key {
    my ($self, $username, %params) = @_;
    return $self->client->post('/admin/users/' . uri_escape($username) . '/keys', \%params);
}

=method delete_key

    $forgejo->admin->users->delete_key($username, $key_id);

Delete a public key from a user.

=cut

sub delete_key {
    my ($self, $username, $key_id) = @_;
    return $self->client->delete('/admin/users/' . uri_escape($username) . '/keys/' . uri_escape($key_id));
}

=method create_org_for

    my $org = $forgejo->admin->users->create_org_for($username, username => 'myorg');

Create an organization owned by a user; C<username> is the name of the
organization. The key/value pairs are sent as the JSON body.

=cut

sub create_org_for {
    my ($self, $username, %params) = @_;
    return $self->client->post('/admin/users/' . uri_escape($username) . '/orgs', \%params);
}

=method create_repo_for

    my $repo = $forgejo->admin->users->create_repo_for($username, name => 'myrepo');

Create a repository for a user. The key/value pairs are sent as the JSON
body.

=cut

sub create_repo_for {
    my ($self, $username, %params) = @_;
    return $self->client->post('/admin/users/' . uri_escape($username) . '/repos', \%params);
}

=method quota

    my $quota = $forgejo->admin->users->quota($username);

Get quota information for a user.

=cut

sub quota {
    my ($self, $username) = @_;
    return $self->client->get('/admin/users/' . uri_escape($username) . '/quota');
}

=method set_quota_groups

    $forgejo->admin->users->set_quota_groups($username, 'premium', 'staff');

Set the quota groups of a user to the given list (C<POST
/admin/users/{username}/quota/groups>).

=cut

sub set_quota_groups {
    my ($self, $username, @groups) = @_;
    return $self->client->post('/admin/users/' . uri_escape($username) . '/quota/groups', { groups => \@groups });
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $users = $forgejo->admin->users->list;
    my $user  = $forgejo->admin->users->create(username => 'testuser', email => 'user@example.com');

    $forgejo->admin->users->rename('testuser', 'tester');

=head1 DESCRIPTION

The C</admin/users> site administration endpoints: create, edit, rename and
delete users and manage their emails, keys, organizations, repositories and
quota. It is obtained through L<WWW::Forgejo::API::Admin/users>.

To read a user's keys, organizations or repositories use
L<WWW::Forgejo::API::Users>; the admin API only has the write side.

Methods return the decoded JSON response as plain Perl data.

=head1 SEE ALSO

L<WWW::Forgejo::API::Admin>, L<WWW::Forgejo>

=cut
