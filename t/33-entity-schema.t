#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 't/lib';
use MockForgejo qw(mock_client);

# The field accessors of the entities read fields the API really sends: every
# data->{...} key in an entity class has to be a property of the response
# schema it wraps, as listed in t/fixtures/forgejo-api-schemas.txt (extracted
# from the official Swagger document). An accessor for a field the API does
# not have would silently return undef for ever.

my %schema;
{
    open my $fh, '<', 't/fixtures/forgejo-api-schemas.txt' or die "fixture: $!";
    while (my $line = <$fh>) {
        next if $line =~ /^#/ || $line !~ /\S/;
        chomp $line;
        my ($name, $fields) = split /:\s*/, $line, 2;
        $schema{$name} = { map { $_ => 1 } split ' ', $fields };
    }
}

# Entity class => schema of the API object it wraps.
my %wraps = (
    Branch            => 'Branch',
    BranchProtection  => 'BranchProtection',
    Collaborator      => 'User',
    CommitStatus      => 'CommitStatus',
    CronTask          => 'Cron',
    DeployKey         => 'DeployKey',
    Email             => 'Email',
    Hook              => 'Hook',
    Issue             => 'Issue',
    IssueComment      => 'Comment',
    Milestone         => 'Milestone',
    Org               => 'Organization',
    PullRequest       => 'PullRequest',
    PullRequestReview => 'PullReview',
    QuotaGroup        => 'QuotaGroup',
    QuotaRule         => 'QuotaRuleInfo',
    Release           => 'Release',
    ReleaseAsset      => 'Attachment',
    Repo              => 'Repository',
    Team              => 'Team',
    User              => 'User',
    WorkflowJob       => 'ActionRunJob',
    WorkflowRun       => 'ActionRun',
);

opendir my $dh, 'lib/WWW/Forgejo/Entity' or die $!;
my @entities = sort map { /^(\w+)\.pm\z/ ? $1 : () } readdir $dh;
is_deeply(\@entities, [ sort keys %wraps ], 'every entity class is mapped to a schema');

my ($client) = mock_client();

for my $entity (@entities) {
    my $schema = $schema{ $wraps{$entity} // '' };
    ok($schema, "$entity: schema $wraps{$entity} is in the fixture") or next;

    open my $fh, '<', "lib/WWW/Forgejo/Entity/$entity.pm" or die $!;
    my $src = do { local $/; <$fh> };
    $src =~ s/^__END__.*//ms;

    # accessor => field, from "sub name { ...->data->{field} ... }"
    my %reads;
    while ($src =~ /^sub (\w+)\s*\{([^\n]*data->\{\w+\}[^\n]*)\}\s*$/mg) {
        my ($accessor, $code) = ($1, $2);
        $reads{$accessor} = [ $code =~ /data->\{(\w+)\}/g ];
    }

    my $class = "WWW::Forgejo::Entity::$entity";
    eval "require $class; 1" or die $@;
    my %data = map { $_ => "value of $_" } keys %$schema;
    my $object = $class->new(client => $client, owner => 'o', repo => 'r', data => \%data);

    for my $accessor (sort keys %reads) {
        my @fields = @{ $reads{$accessor} };
        my @unknown = grep { !$schema->{$_} } @fields;
        is_deeply(\@unknown, [], "$entity->$accessor reads a field of $wraps{$entity}");
        next if @unknown;
        is($object->$accessor, "value of $fields[0]", "$entity->$accessor returns $fields[0]");
    }
}

done_testing;
