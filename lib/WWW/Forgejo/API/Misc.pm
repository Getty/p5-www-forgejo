# ABSTRACT: Forgejo Misc API - instance information and renderers
# PODNAME: WWW::Forgejo::API::Misc

use strict;
use warnings;

package WWW::Forgejo::API::Misc;

use Moo;
use Carp qw(croak);
use WWW::Forgejo::URL qw( escape_component );
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

=method gitignore_template

    my $template = $forgejo->misc->gitignore_template('Go');

Get one .gitignore template (C<GET /gitignore/templates/{name}>). The name of
the template is the name of its file, C<Go> say. The template is returned as
a plain structure.

=cut

sub gitignore_template {
    my ($self, $name) = @_;
    croak "Template name required" unless defined $name && length $name;
    return $self->client->get('/gitignore/templates/' . escape_component($name));
}

=method license_templates

    my $templates = $forgejo->misc->license_templates;

List available license templates (C<GET /licenses>).

=cut

sub license_templates {
    my ($self) = @_;
    return $self->client->get('/licenses');
}

=method license

    my $license = $forgejo->misc->license('mit');

Get one license template (C<GET /licenses/{name}>). The name of the license is
its SPDX id, C<mit> say. The license is returned as a plain structure.

=cut

sub license {
    my ($self, $name) = @_;
    croak "License name required" unless defined $name && length $name;
    return $self->client->get('/licenses/' . escape_component($name));
}

=method label_templates

    my $templates = $forgejo->misc->label_templates;

List available label templates (C<GET /label/templates>).

=cut

sub label_templates {
    my ($self) = @_;
    return $self->client->get('/label/templates');
}

=method label_template

    my $template = $forgejo->misc->label_template('bug');

Get one label template (C<GET /label/templates/{name}>). The name of the
template is the name of its file, C<bug> say. The template is returned as a
plain structure.

=cut

sub label_template {
    my ($self, $name) = @_;
    croak "Template name required" unless defined $name && length $name;
    return $self->client->get('/label/templates/' . escape_component($name));
}

=method markdown_raw

    my $html = $forgejo->misc->markdown_raw('# Hello');

Render raw markdown to HTML (C<POST /markdown/raw>). The markdown is sent as
the body of the request, as plain text - the API takes no JSON here. Returns
the HTML as a string.

=cut

sub markdown_raw {
    my ($self, $text) = @_;
    croak "Markdown text required" unless defined $text && length $text;
    return $self->client->post('/markdown/raw', undef, content => $text, content_type => 'text/plain');
}

=method action_run

    my $run = $forgejo->misc->action_run;

Get the workflow run that belongs to the token of the client
(C<GET /actions/run>). Only the automatic token of an Actions job may ask
this; any other token is refused by the API.

=cut

sub action_run {
    my ($self) = @_;
    return $self->client->get('/actions/run');
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
    return $self->client->get("/settings/" . escape_component($section));
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
