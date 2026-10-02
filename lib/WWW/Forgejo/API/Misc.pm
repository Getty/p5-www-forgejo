# ABSTRACT: Forgejo Misc API - instance information and renderers
# PODNAME: WWW::Forgejo::API::Misc

use strict;
use warnings;

package WWW::Forgejo::API::Misc;

use Moo;
use Carp qw(croak);
use URI::Escape qw(uri_escape);
use namespace::clean;

our $VERSION = '0.001';

has client => (is => 'ro', required => 1);

=attr client

The L<WWW::Forgejo> client the requests are sent through. Required.

=cut

=method version

    my $version = $forgejo->misc->version;

Get the Forgejo server version information (C<GET /version>).

=cut

sub version {
    my ($self) = @_;
    return $self->client->get('/version');
}

=method nodeinfo

    my $nodeinfo = $forgejo->misc->nodeinfo;

Get nodeinfo metadata about the instance (C<GET /nodeinfo>).

=cut

sub nodeinfo {
    my ($self) = @_;
    return $self->client->get('/nodeinfo');
}

=method signing_key

    my $armored = $forgejo->misc->signing_key;

Get the GPG signing key of the instance (C<GET /signing-key.gpg>). Returns the
armored key as a string.

=cut

sub signing_key {
    my ($self) = @_;
    return $self->client->get('/signing-key.gpg');
}

=method signing_key_ssh

    my $key = $forgejo->misc->signing_key_ssh;

Get the SSH signing key of the instance (C<GET /signing-key.ssh>) as a string.

=cut

sub signing_key_ssh {
    my ($self) = @_;
    return $self->client->get('/signing-key.ssh');
}

=method markdown

    my $html = $forgejo->misc->markdown(Text => '# Hello', Mode => 'gfm');

Render markdown to HTML (C<POST /markdown>). The key/value pairs are sent as
the JSON body; the option names are capitalised in the API (C<Text>, C<Mode>,
C<Context>, C<Wiki>). Returns the HTML as a string.

=cut

sub markdown {
    my ($self, %params) = @_;
    return $self->client->post('/markdown', \%params);
}

=method markup

    my $html = $forgejo->misc->markup(Text => '# Hello', Mode => 'gfm');

Render markup to HTML (C<POST /markup>). The key/value pairs are sent as the
JSON body (C<Text>, C<Mode>, C<Context>, C<FilePath>, C<BranchPath>, C<Wiki>).
Returns the HTML as a string.

=cut

sub markup {
    my ($self, %params) = @_;
    return $self->client->post('/markup', \%params);
}

=method gitignore_templates

    my $templates = $forgejo->misc->gitignore_templates;

List available .gitignore templates (C<GET /gitignore/templates>).

=cut

sub gitignore_templates {
    my ($self) = @_;
    return $self->client->get('/gitignore/templates');
}

=method license_templates

    my $templates = $forgejo->misc->license_templates;

List available license templates (C<GET /licenses>).

=cut

sub license_templates {
    my ($self) = @_;
    return $self->client->get('/licenses');
}

=method label_templates

    my $templates = $forgejo->misc->label_templates;

List available label templates (C<GET /label/templates>).

=cut

sub label_templates {
    my ($self) = @_;
    return $self->client->get('/label/templates');
}

=method settings

    my $api = $forgejo->misc->settings('api');

Get one section of the instance settings (C<GET /settings/{section}>). The API
has the sections C<api>, C<attachment>, C<repository> and C<ui>; the section
name is required.

=cut

sub settings {
    my ($self, $section) = @_;
    croak "Settings section required (api, attachment, repository or ui)" unless $section;
    return $self->client->get("/settings/" . uri_escape($section));
}

=method topics_search

    my $result = $forgejo->misc->topics_search(q => 'perl');

Search for topics (C<GET /topics/search>). Named arguments are sent as the
query string of the request; C<q> is the search term.

=cut

sub topics_search {
    my ($self, %params) = @_;
    return $self->client->get('/topics/search', params => \%params);
}

1;

__END__

=head1 SYNOPSIS

    my $forgejo = WWW::Forgejo->new(url => 'https://forgejo.example.com', token => $token);

    my $version = $forgejo->misc->version;
    my $ui      = $forgejo->misc->settings('ui');
    my $html    = $forgejo->misc->markdown(Text => '# Hello');

=head1 DESCRIPTION

Utility endpoints of the instance: version, nodeinfo, signing keys, the
gitignore/license/label templates, settings and topic search, plus the
markdown and markup renderers. Available as C<< $forgejo->misc >>.

The methods return the decoded JSON response as plain Perl data; the renderers
and the signing key methods return a string.

=head1 SEE ALSO

L<WWW::Forgejo>

=cut
