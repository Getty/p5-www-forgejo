package WWW::Forgejo::Entity::CronTask;
# ABSTRACT: Forgejo CronTask Entity
# PODNAME: WWW::Forgejo::Entity::CronTask

use Moo;
extends 'WWW::Forgejo::Entity';
use Log::Any qw($log);

sub name     { shift->data->{name} }
sub schedule { shift->data->{schedule} }
sub next_run { shift->data->{next_run} }
sub last_run { shift->data->{last_run} }
sub disabled { shift->data->{disabled} }

1;

__END__

=head1 DESCRIPTION

Represents a Forgejo cron task entity.

=head1 ATTRIBUTES

=head2 name

The cron task name.

=head2 schedule

The cron schedule.

=head2 next_run

Timestamp of the next run.

=head2 last_run

Timestamp of the last run.

=head2 disabled

Whether the cron task is disabled.

=head1 SEE ALSO

L<WWW::Forgejo::Entity>

=cut