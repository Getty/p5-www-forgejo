# ABSTRACT: Perl client for the Forgejo API v1
# PODNAME: WWW::Forgejo

use strict;
use warnings;

package WWW::Forgejo;

1;
__END__

=head1 SYNOPSIS

  use WWW::Forgejo;

  my $client = WWW::Forgejo->new(
    url   => 'https://src.ci',
    token => $ENV{FORGEJO_TOKEN},
  );

=cut