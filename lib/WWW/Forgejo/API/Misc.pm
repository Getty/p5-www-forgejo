# ABSTRACT: Forgejo Misc API - read-only utility endpoints
# PODNAME: WWW::Forgejo::API::Misc

use strict;
use warnings;

package WWW::Forgejo::API::Misc;

use Moo;
use Log::Any qw($log);
use URI::Escape;

has client => (
    is       => 'ro',
    init_arg => 'client',
);

=method version

    my $version = $self->{client}->version;

Get the Forgejo server version information.

=cut

sub version {
    my ($self) = @_;
    return $self->{client}->get('/version');
}

=method nodeinfo

    my $nodeinfo = $self->{client}->nodeinfo;

Get nodeinfo metadata about the instance.

=cut

sub nodeinfo {
    my ($self) = @_;
    return $self->{client}->get('/nodeinfo');
}

=method signing_key

    my $signing_key = $self->{client}->signing_key;

Get the instance signing key.

=cut

sub signing_key {
    my ($self) = @_;
    return $self->{client}->get('/signing-key');
}

=method markdown

    my $html = $self->{client}->markdown(markdown => '# Hello');

Render markdown to HTML.

=cut

sub markdown {
    my ($self, %params) = @_;
    return $self->{client}->post('/markdown', \%params);
}

=method markup

    my $html = $self->{client}->markup(content => '<h1>Hello</h1>', mode => 'gfm');

Render markup to HTML.

=cut

sub markup {
    my ($self, %params) = @_;
    return $self->{client}->post('/markup', \%params);
}

=method gitignore_templates

    my $templates = $self->{client}->gitignore_templates;

List available .gitignore templates.

=cut

sub gitignore_templates {
    my ($self) = @_;
    return $self->{client}->get('/gitignore_templates');
}

=method license_templates

    my $templates = $self->{client}->license_templates;

List available license templates.

=cut

sub license_templates {
    my ($self) = @_;
    return $self->{client}->get('/license_templates');
}

=method label_templates

    my $templates = $self->{client}->label_templates;

List available label templates.

=cut

sub label_templates {
    my ($self) = @_;
    return $self->{client}->get('/label_templates');
}

=method settings

    my $settings = $self->{client}->settings;
    my $setting = $self->{client}->settings('api');

Get settings. Without an argument returns all settings sections.

=cut

sub settings {
    my ($self, $section) = @_;
    my $path = $section ? "/settings/" . uri_escape($section) : '/settings';
    return $self->{client}->get($path);
}

=method topics_search

    my $topics = $self->{client}->topics_search(q => 'perl');

Search for topics.

=cut

sub topics_search {
    my ($self, %params) = @_;
    return $self->{client}->get('/topics/search', params => \%params);
}

1;