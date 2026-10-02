package WWW::Forgejo::Entity::CronTask;
# ABSTRACT: Forgejo CronTask Entity
# PODNAME: WWW::Forgejo::Entity::CronTask

use Moo;
extends 'WWW::Forgejo::Entity';
use Log::Any qw($log);
use namespace::clean;

our $VERSION = '0.001';

sub name     { shift->data->{name} }
sub schedule { shift->data->{schedule} }
sub next_run { shift->data->{next} }
sub last_run { shift->data->{prev} }

1;

__END__

=head1 SYNOPSIS

    my $task = WWW::Forgejo::Entity::CronTask->new(
        client => $forgejo,
        data   => \%task,      # one decoded cron task object
    );
    print $task->name, ' ', $task->schedule, "\n";

=head1 DESCRIPTION

Wraps the decoded JSON object of a cron task. None of the controllers returns this class
yet; they hand out the plain decoded data, which can be wrapped as shown in the
L</SYNOPSIS>. The accessors read single fields from
L<data|WWW::Forgejo::Entity/data>, which always holds the complete structure.

Inherits from L<WWW::Forgejo::Entity>.

=method name

The cron task name.

=method schedule

The cron schedule.

=method next_run

Timestamp of the next run.

=method last_run

Timestamp of the last run.

=head1 SEE ALSO

L<WWW::Forgejo::Entity>

=cut
