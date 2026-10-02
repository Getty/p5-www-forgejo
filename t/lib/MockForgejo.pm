package MockForgejo;

# Shared in-memory transport for the offline tests: a WWW::Forgejo::Role::IO
# backend that records every request and answers from a queue.

use strict;
use warnings;
use Exporter 'import';
use WWW::Forgejo;
use WWW::Forgejo::HTTPResponse;

our @EXPORT_OK = qw(mock_client);

{
    package MockForgejo::IO;
    use Moo;
    with 'WWW::Forgejo::Role::IO';

    has requests => (is => 'ro', default => sub { [] });
    has queue    => (is => 'ro', default => sub { [] });

    # Answer when the queue is empty.
    has default_response => (is => 'rw', default => sub { [200, '{}'] });

    sub add {
        my ($self, $status, $content, %headers) = @_;
        push @{ $self->queue }, [$status, $content, \%headers];
        return $self;
    }

    sub call {
        my ($self, $req) = @_;
        push @{ $self->requests }, $req;
        my ($status, $content, $headers) = @{ shift @{ $self->queue } || $self->default_response };
        return WWW::Forgejo::HTTPResponse->new(
            status  => $status,
            content => $content // '',
            headers => $headers || {},
        );
    }

    sub last  { $_[0]->requests->[-1] }
    sub count { scalar @{ $_[0]->requests } }

    sub reset {
        my ($self) = @_;
        @{ $self->requests } = ();
        @{ $self->queue }    = ();
        return $self;
    }
}

sub mock_client {
    my (%args) = @_;
    my $io = MockForgejo::IO->new;
    my $client = WWW::Forgejo->new(
        url   => 'https://forgejo.test',
        token => 'test-token',
        io    => $io,
        %args,
    );
    return ($client, $io);
}

1;
