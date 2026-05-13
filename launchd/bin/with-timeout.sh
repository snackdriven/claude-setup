#!/usr/bin/env bash
# with-timeout.sh — portable replacement for `timeout(1)` on stock macOS.
# Usage: with-timeout.sh SECONDS CMD [ARGS...]
# Exits 124 if the command was killed by the timeout (matching GNU timeout).
#
# Implementation: perl `alarm` is preserved across `exec`, so the alarm
# fires on the replaced process (the actual command) and default SIGALRM
# disposition terminates it. We translate the resulting status to 124.

if [ "$#" -lt 2 ]; then
  echo "usage: $(basename "$0") SECONDS CMD [ARGS...]" >&2
  exit 2
fi

SECS="$1"
shift

perl -e '
  my $secs = shift @ARGV;
  my $pid  = fork();
  die "with-timeout: fork failed: $!\n" unless defined $pid;
  if ($pid == 0) {
    exec @ARGV or die "with-timeout: exec failed: $!\n";
  }
  $SIG{ALRM} = sub {
    kill "TERM", $pid;
    sleep 2;
    kill "KILL", $pid;
    waitpid($pid, 0);
    exit 124;
  };
  alarm $secs;
  waitpid($pid, 0);
  my $status = $?;
  exit ($status >> 8) if ($status & 127) == 0;
  exit 128 + ($status & 127);
' "$SECS" "$@"
