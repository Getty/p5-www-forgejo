#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use lib 't/lib';
use MockForgejo qw(mock_client);
use WWW::Forgejo::API::Repo::Actions;

# The Actions endpoints of a repository the client did not cover yet: the
# artifacts with their archive, the logs of a job and of a run, the runners with
# their registration token, the tasks and the dispatch of a workflow.
#
# Every call is made in an eval, so a method that does not exist shows up as a
# failed test instead of a dead file.

my ($client, $io) = mock_client();
my $base = 'https://forgejo.test/api/v1';

my $actions = WWW::Forgejo::API::Repo::Actions->new(
    client => $client,
    owner  => 'owner',
    repo   => 'repo',
);

sub request {
    my $last = $io->last or return '(no request)';
    return $last->method . ' ' . substr($last->url, length $base);
}

sub body {
    my $last = $io->last or return undef;
    return $last->has_content ? decode_json($last->content) : undef;
}

# The value of an expression, or undef when it dies.
sub value { return eval { $_[0]->() } }

# ---------------------------------------------------------------------------
# The artifacts
# ---------------------------------------------------------------------------

subtest 'the artifacts of the repository' => sub {
    $io->reset->add(200, '[{"id":1,"name":"build"}]');
    my $artifacts = value(sub { $actions->list_artifacts });
    is(request(), 'GET /repos/owner/repo/actions/artifacts',
        'GET /repos/{owner}/{repo}/actions/artifacts');
    is(ref $artifacts, 'ARRAY', 'list_artifacts returns an arrayref') or return;
    is($artifacts->[0]{name}, 'build', 'the name of the artifact');

    $io->reset->add(200, '{"id":1,"name":"build"}');
    my $artifact = value(sub { $actions->get_artifact(1) });
    is(request(), 'GET /repos/owner/repo/actions/artifacts/1',
        'GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}');
    is(ref $artifact, 'HASH', 'get_artifact returns the plain artifact');

    $io->reset->add(204, '');
    my $deleted = value(sub { $actions->delete_artifact(1) });
    is(request(), 'DELETE /repos/owner/repo/actions/artifacts/1',
        'DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}');
    ok($deleted, 'delete_artifact returns true');
};

subtest 'the archive of an artifact' => sub {
    $io->reset->add(200, 'PK' . "\x03\x04" . 'zip-bytes');
    my $zip = value(sub { $actions->download_artifacts(1) });
    is(request(), 'GET /repos/owner/repo/actions/artifacts/1/zip',
        'GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip');
    is($zip, 'PK' . "\x03\x04" . 'zip-bytes', 'the archive is the body of the response');
};

# ---------------------------------------------------------------------------
# The logs
# ---------------------------------------------------------------------------

subtest 'the log of a job' => sub {
    $io->reset->add(200, "the log of the job\n");
    my $log = value(sub { $actions->get_job_logs(7) });
    is(request(), 'GET /repos/owner/repo/actions/jobs/7/logs',
        'GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs');
    is($log, "the log of the job\n", 'the log is the body of the response');
};

subtest 'the logs of a run' => sub {
    $io->reset->add(200, "the logs of the run\n");
    my $log = value(sub { $actions->get_run_logs(3) });
    is(request(), 'GET /repos/owner/repo/actions/runs/3/logs',
        'GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs');
    is($log, "the logs of the run\n", 'the logs are the body of the response');
};

# ---------------------------------------------------------------------------
# The runners
# ---------------------------------------------------------------------------

subtest 'the runners of the repository' => sub {
    $io->reset->add(200, '[{"id":1,"name":"runner-1"}]');
    my $jobs = value(sub { $actions->list_runner_jobs });
    is(request(), 'GET /repos/owner/repo/actions/runners/jobs',
        'GET /repos/{owner}/{repo}/actions/runners/jobs');
    is(ref $jobs, 'ARRAY', 'list_runner_jobs returns an arrayref') or return;

    $io->reset->add(200, '{"token":"abc"}');
    my $token = value(sub { $actions->get_runner_registration_token });
    is(request(), 'GET /repos/owner/repo/actions/runners/registration-token',
        'GET /repos/{owner}/{repo}/actions/runners/registration-token');
    is($token->{token}, 'abc', 'the registration token');

    $io->reset->add(200, '{"id":1,"name":"runner-1"}');
    my $runner = value(sub { $actions->get_runner(1) });
    is(request(), 'GET /repos/owner/repo/actions/runners/1',
        'GET /repos/{owner}/{repo}/actions/runners/{runner_id}');
    is($runner->{name}, 'runner-1', 'the runner');

    $io->reset->add(201, '{"id":2,"name":"runner-2"}');
    value(sub { $actions->create_runner(name => 'runner-2') });
    is(request(), 'POST /repos/owner/repo/actions/runners',
        'POST /repos/{owner}/{repo}/actions/runners');
    is_deeply(body(), { name => 'runner-2' }, 'the name is the body of the request');

    $io->reset->add(204, '');
    my $deleted = value(sub { $actions->delete_runner(1) });
    is(request(), 'DELETE /repos/owner/repo/actions/runners/1',
        'DELETE /repos/{owner}/{repo}/actions/runners/{runner_id}');
    ok($deleted, 'delete_runner returns true');
};

# ---------------------------------------------------------------------------
# The artifacts of a run
# ---------------------------------------------------------------------------

subtest 'the artifacts of a run' => sub {
    $io->reset->add(200, '[{"id":1,"name":"build"}]');
    my $artifacts = value(sub { $actions->list_run_artifacts(3) });
    is(request(), 'GET /repos/owner/repo/actions/runs/3/artifacts',
        'GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts');
    is(ref $artifacts, 'ARRAY', 'list_run_artifacts returns an arrayref') or return;
};

# ---------------------------------------------------------------------------
# The tasks
# ---------------------------------------------------------------------------

subtest 'the tasks of the repository' => sub {
    $io->reset->add(200, '[{"id":1,"status":"waiting"}]');
    my $tasks = value(sub { $actions->list_tasks });
    is(request(), 'GET /repos/owner/repo/actions/tasks',
        'GET /repos/{owner}/{repo}/actions/tasks');
    is(ref $tasks, 'ARRAY', 'list_tasks returns an arrayref') or return;
    is($tasks->[0]{status}, 'waiting', 'the status of the task');
};

# ---------------------------------------------------------------------------
# The dispatch of a workflow
# ---------------------------------------------------------------------------

subtest 'the dispatch of a workflow' => sub {
    $io->reset->add(204, '');
    value(sub { $actions->dispatch_workflow('ci.yaml', ref => 'main') });
    is(request(), 'POST /repos/owner/repo/actions/workflows/ci.yaml/dispatches',
        'POST /repos/{owner}/{repo}/actions/workflows/{workflowfilename}/dispatches');
    is_deeply(body(), { ref => 'main' }, 'the ref is the body of the request');
};

# ---------------------------------------------------------------------------
# The names of the paths are escaped
# ---------------------------------------------------------------------------

subtest 'the names of the paths are escaped' => sub {
    $io->reset->add(200, '{}');
    value(sub { $actions->get_runner('a b') });
    is(request(), 'GET /repos/owner/repo/actions/runners/a%20b',
        'the parts of the path are escaped');
};

done_testing;
