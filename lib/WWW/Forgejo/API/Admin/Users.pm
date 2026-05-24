package WWW::Forgejo::API::Admin::Users;
# ABSTRACT: Forgejo Admin API - Users
# PODNAME: WWW::Forgejo::API::Admin::Users

use Moo;
use Log::Any qw($log);

has client => (
    is       => 'ro',
    init_arg => 'client',
);

=method list

    my $users = $self->list;

List all users.

=cut

sub list {
    my ($self) = @_;
    return $self->{client}->get('/admin/users');
}

=method get

    my $user = $self->get($username);

Get a specific user by username.

=cut

sub get {
    my ($self, $username) = @_;
    return $self->{client}->get("/users/$username");
}

=method create

    my $user = $self->create(
        email => 'user@example.com',
        username => 'testuser',
        password => 'secret',
    );

Create a new user.

=cut

sub create {
    my ($self, %params) = @_;
    return $self->{client}->post('/admin/users', \%params);
}

=method edit

    my $user = $self->edit($username, %params);

Edit an existing user.

=cut

sub edit {
    my ($self, $username, %params) = @_;
    return $self->{client}->put("/admin/users/$username", \%params);
}

=method delete

    $self->delete($username);

Delete a user.

=cut

sub delete_user {
    my ($self, $username) = @_;
    return $self->{client}->delete("/admin/users/$username");
}

=method rename

    my $user = $self->rename($username, $new_name);

Rename a user.

=cut

sub rename {
    my ($self, $username, $new_name) = @_;
    return $self->{client}->post("/admin/users/$username/rename", { new_name => $new_name });
}

=method add_email

    my $email = $self->add_email($username, $email);

Add an email address to a user.

=cut

sub add_email {
    my ($self, $username, $email) = @_;
    return $self->{client}->post("/admin/users/$username/emails", { email => $email });
}

=method delete_email

    $self->delete_email($username, $email);

Delete an email address from a user.

=cut

sub delete_email {
    my ($self, $username, $email) = @_;
    return $self->{client}->delete("/admin/users/$username/emails/$email");
}

=method search_emails

    my $results = $self->search_emails(email => 'user@example.com');

Search for email addresses.

=cut

sub search_emails {
    my ($self, %params) = @_;
    return $self->{client}->get('/admin/users/emails/search', params => \%params);
}

=method list_keys

    my $keys = $self->list_keys($username);

List all public keys for a user.

=cut

sub list_keys {
    my ($self, $username) = @_;
    return $self->{client}->get("/admin/users/$username/keys");
}

=method add_key

    my $key = $self->add_key($username, title => 'My Key', key => $public_key);

Add a public key to a user.

=cut

sub add_key {
    my ($self, $username, %params) = @_;
    return $self->{client}->post("/admin/users/$username/keys", \%params);
}

=method delete_key

    $self->delete_key($username, $key_id);

Delete a public key from a user.

=cut

sub delete_key {
    my ($self, $username, $key_id) = @_;
    return $self->{client}->delete("/admin/users/$username/keys/$key_id");
}

=method list_orgs

    my $orgs = $self->list_orgs($username);

List all organizations for a user.

=cut

sub list_orgs {
    my ($self, $username) = @_;
    return $self->{client}->get("/admin/users/$username/orgs");
}

=method create_org_for

    my $org = $self->create_org_for($username, name => 'myorg');

Create an organization for a user.

=cut

sub create_org_for {
    my ($self, $username, %params) = @_;
    return $self->{client}->post("/admin/users/$username/orgs", \%params);
}

=method list_repos

    my $repos = $self->list_repos($username);

List all repositories for a user.

=cut

sub list_repos {
    my ($self, $username) = @_;
    return $self->{client}->get("/admin/users/$username/repos");
}

=method create_repo_for

    my $repo = $self->create_repo_for($username, name => 'myrepo');

Create a repository for a user.

=cut

sub create_repo_for {
    my ($self, $username, %params) = @_;
    return $self->{client}->post("/admin/users/$username/repos", \%params);
}

=method quota

    my $quota = $self->quota($username);

Get quota information for a user.

=cut

sub quota {
    my ($self, $username) = @_;
    return $self->{client}->get("/admin/users/$username/quota");
}

=method add_to_quota_group

    $self->add_to_quota_group($username, $group);

Add a user to a quota group.

=cut

sub add_to_quota_group {
    my ($self, $username, $group) = @_;
    return $self->{client}->post("/admin/users/$username/quota/group", { group_name => $group });
}

1;

__END__

=head1 METHODS

=head2 list

  my $users = $self->list;

List all users.

=head2 get

  my $user = $self->get($username);

Get a specific user by username.

=head2 create

  my $user = $self->create(
      email => 'user@example.com',
      username => 'testuser',
      password => 'secret',
  );

Create a new user.

=head2 edit

  my $user = $self->edit($username, %params);

Edit an existing user.

=head2 delete

  $self->delete($username);

Delete a user.

=head2 rename

  my $user = $self->rename($username, $new_name);

Rename a user.

=head2 add_email

  my $email = $self->add_email($username, $email);

Add an email address to a user.

=head2 delete_email

  $self->delete_email($username, $email);

Delete an email address from a user.

=head2 search_emails

  my $results = $self->search_emails(email => 'user@example.com');

Search for email addresses.

=head2 list_keys

  my $keys = $self->list_keys($username);

List all public keys for a user.

=head2 add_key

  my $key = $self->add_key($username, title => 'My Key', key => $public_key);

Add a public key to a user.

=head2 delete_key

  $self->delete_key($username, $key_id);

Delete a public key from a user.

=head2 list_orgs

  my $orgs = $self->list_orgs($username);

List all organizations for a user.

=head2 create_org_for

  my $org = $self->create_org_for($username, name => 'myorg');

Create an organization for a user.

=head2 list_repos

  my $repos = $self->list_repos($username);

List all repositories for a user.

=head2 create_repo_for

  my $repo = $self->create_repo_for($username, name => 'myrepo');

Create a repository for a user.

=head2 quota

  my $quota = $self->quota($username);

Get quota information for a user.

=head2 add_to_quota_group

  $self->add_to_quota_group($username, $group);

Add a user to a quota group.

=head1 SEE ALSO

L<WWW::Forgejo>

=cut