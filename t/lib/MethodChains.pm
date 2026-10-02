package MethodChains;

# Static check of method call chains in a piece of Perl source (a live test, a
# SYNOPSIS) against the real classes: every `->method` has to exist on the
# object it is called on.
#
# The source is not executed. Each chain is replayed link by link on real
# objects bound to the mock transport: `$client->repos->get(...)->issues->list`
# starts at the object registered for `$client`, checks `can('repos')`, calls
# it to learn what comes back, checks `can('get')` on that, and so on. The
# arguments written in the source are ignored; a method is called with a few
# dummy argument lists against canned answers until one of them returns, which
# is enough to learn the class of the result. Variables assigned from a chain
# (`my $repo = ...`, `my @issues = ...`, `for my $issue (...)`) carry the
# result on to later chains.
#
# check_chains($source, io => $mock_io, vars => { name => $object },
# instances => { Class => $object }, new_args => { ... }) names the objects the
# variables of the source stand for, what Class->new yields for the classes
# named, and the constructor arguments to build any other class with. It returns a hashref:
#   checked    - number of method calls verified to exist
#   errors     - [ "line N: Class has no method name", ... ]
#   unverified - [ "line N: ->name", ... ]: method calls whose receiver could
#                not be determined, so nothing can be said about them

use strict;
use warnings;
use Exporter 'import';
use Scalar::Util qw(blessed);
use MockForgejo qw(mock_client);

our @EXPORT_OK = qw(check_chains);

my $ARGS = qr/(\((?:[^()]++|(?-1))*\))/;
my $LINK = qr/\s*->\s*[A-Za-z_]\w*(?:\s*$ARGS)?/;

# Dummy argument lists tried in turn, and the canned answers each is tried
# against: an object for methods returning one thing, a list for collections.
my @DUMMY_ARGS = (
    [], ['a'], [ {} ], [ 'a', {} ], [ 'a', 'b' ], [ 'a', 'b', {} ],
    [ "a", "b", "c" ], [ "a", "b", "c", "d" ], [ k => "v" ], [ "a", k => "v" ],
    [ "a", filename => "f", content => "c" ],
);
my @ANSWERS = ('{}', '[{}]');

# What a value is, as far as chains are concerned:
#   { object => $obj }  one object
#   { class  => 'X' }   a class name (X->new)
#   { elems  => $obj }  an arrayref of such objects
#   { list   => $obj }  a list of such objects
#   undef               anything else

sub check_chains {
    my ($source, %seed) = @_;

    my $self = bless {
        io         => $seed{io},
        instances  => $seed{instances} || {},
        new_args   => $seed{new_args}  || {},
        vars       => {},
        checked    => 0,
        errors     => [],
        unverified => [],
        covered    => {},
    }, __PACKAGE__;
    for my $name (keys %{ $seed{vars} || {} }) {
        $self->{vars}{$name} = { object => $seed{vars}{$name} };
    }

    my $code = _strip($source);
    $self->{code} = $code;
    $self->_scan($code, 0);

    # Every method call in the source has to be part of a chain we resolved.
    while ($code =~ /->\s*([A-Za-z_]\w*)/g) {
        my $at = $-[1];
        next if $self->{covered}{$at};
        push @{ $self->{unverified} }, 'line ' . $self->_line($at) . ": ->$1";
    }

    return {
        checked    => $self->{checked},
        errors     => $self->{errors},
        unverified => $self->{unverified},
    };
}

# Blank out comments, POD and string contents, keeping every offset and line
# number intact.
sub _strip {
    my ($code) = @_;
    my $blank = sub { (my $s = $_[0]) =~ s/[^\n]/ /g; $s };
    $code =~ s/^=[a-zA-Z].*?^=cut[ \t]*$/$blank->($&)/msge;
    $code =~ s/^__END__.*\z/$blank->($&)/mse;
    $code =~ s/('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")|((?:^|(?<=\s))#[^\n]*)/
        defined $1 ? substr($1, 0, 1) . $blank->(substr($1, 1, -1)) . substr($1, -1) : $blank->($2)/mge;
    return $code;
}

sub _line {
    my ($self, $offset) = @_;
    return 1 + (substr($self->{code}, 0, $offset) =~ tr/\n//);
}

# Find the chains in $text (which starts at $base in the whole source) and
# resolve them in order; then descend into the argument lists.
sub _scan {
    my ($self, $text, $base) = @_;

    my $start = qr/\$\w+(?:\s*->\s*\[[^\]]*\])?|\b[A-Z]\w*(?:::\w+)+/;
    while ($text =~ /($start)((?:$LINK)+)/g) {
        my ($head, $links) = ($1, $2);
        my ($from, $links_from, $end) = ($-[1], $-[2], pos $text);

        $self->_loop_variables(substr($self->{code}, 0, $base + $from));

        my $value = $self->_start_value($head);
        my $offset = $base + $links_from;
        my @inner;
        while ($links =~ /\G(\s*->\s*)([A-Za-z_]\w*)(?:\s*$ARGS)?/g) {
            my ($arrow, $method, $args) = ($1, $2, $3);
            my $at = $offset + $-[2];
            push @inner, [ $args, $offset + $-[3] ] if defined $args;
            next unless $value;    # receiver unknown: stays unverified

            $self->{covered}{$at} = 1;
            my $target = $value->{object} // $value->{class};
            if (!$value->{object} && !$value->{class}) {
                push @{ $self->{errors} },
                    'line ' . $self->_line($at) . ": ->$method called on a collection, not on an object";
                $value = undef;
                next;
            }
            my $registered = $value->{class} && $method eq "new" && $self->{instances}{ $value->{class} };
            if (!$registered && !$target->can($method)) {
                push @{ $self->{errors} },
                    'line ' . $self->_line($at) . ': ' . (ref $target || $target) . " has no method $method";
                $value = undef;
                next;
            }
            $self->{checked}++;
            $value = $self->_result($value, $method);
        }
        $self->_scan(substr($_->[0], 1, -1), $_->[1] + 1) for @inner;

        # A result that is dereferenced further ($x->get(1)->{field}) is data.
        my $after = substr($text, $end, 20);
        $value = undef if $after =~ /^\s*(?:->|\[|\{)/;
        $self->_assign(substr($text, 0, $from), $value);
    }
    return;
}

sub _start_value {
    my ($self, $head) = @_;
    if ($head =~ /^\$(\w+)$/) {
        return $self->{vars}{$1};
    }
    if ($head =~ /^\$(\w+)\s*->\s*\[/) {
        my $v = $self->{vars}{$1};
        return $v && $v->{elems} ? { object => $v->{elems} } : undef;
    }
    return { class => $head } if $self->{instances}{$head} || $head->can("new");
    return;
}

# Call $method the way a caller would and classify what comes back.
sub _result {
    my ($self, $value, $method) = @_;

    if ($value->{class}) {
        # The instance the caller registered for the class, else one built
        # from the constructor arguments the caller supplied.
        return unless $method eq "new";
        my $instance = $self->{instances}{ $value->{class} }
            // eval { $value->{class}->new(%{ $self->{new_args} }) };
        return $instance ? { object => $instance } : undef;
    }

    my $object = $value->{object};
    my $io     = $self->{io};
    local $SIG{__WARN__} = sub { };
    for my $answer (@ANSWERS) {
        for my $args (@DUMMY_ARGS) {
            $io->reset;
            $io->default_response([ 200, $answer ]);
            my @got = eval { $object->$method(@$args) };
            next if $@;
            my $first = $got[0];
            my $found
                = blessed $first ? ($answer eq '{}' || !$io->count ? { object => $first } : { list => $first })
                : ref $first eq 'ARRAY' && blessed $first->[0] ? { elems => $first->[0] }
                :                                               undef;
            $io->default_response([ 200, '{}' ]);
            return $found if $found || $answer eq $ANSWERS[-1];
            last;
        }
    }
    $io->default_response([ 200, '{}' ]);
    return;
}

# The statement a chain sits in decides which variable receives its result.
sub _assign {
    my ($self, $before, $value) = @_;
    my $eval = qr/(?:eval\s*\{\s*)?/;

    if ($before =~ /\$(\w+)\s*=\s*$eval\z/) {
        $self->{vars}{$1} = $value && ($value->{object} || $value->{elems}) ? $value : undef;
    }
    elsif ($before =~ /\@(\w+)\s*=\s*$eval\z/) {
        my $item = $value && ($value->{list} || $value->{object});
        $self->{vars}{"\@$1"} = $item ? { elems => $item } : undef;
    }
    elsif ($before =~ /\(\s*\$(\w+)\s*\)\s*=\s*$eval\z/ || $before =~ /\bfor(?:each)?\s+my\s+\$(\w+)\s*\(\s*\z/) {
        my $item = $value && ($value->{list} || $value->{object});
        $self->{vars}{$1} = $item ? { object => $item } : undef;
    }
    return;
}

# for my $x (@$list) / (@{$list}) / (@list): $x is an element of the list.
sub _loop_variables {
    my ($self, $before) = @_;
    while ($before =~ /\bfor(?:each)?\s+my\s+\$(\w+)\s*\(\s*\@(\{?\s*\$)?(\w+)\s*\}?\s*\)/g) {
        my $list = $self->{vars}{ defined $2 ? $3 : "\@$3" };
        $self->{vars}{$1} = $list && $list->{elems} ? { object => $list->{elems} } : undef
            unless $self->{loops}{ $-[0] }++;
    }
    return;
}

1;
