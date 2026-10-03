#!/bin/sh
set -eu
runtime=$1
writer=$2
updater=$3
MARKBEND_ATOMIC_HOST=$4
journal_root=$5
export MARKBEND_ATOMIC_HOST
mkdir "$journal_root"

invoke() {
  if [ "$runtime" = native ]; then
    "$1"
  else
    "$runtime" "$1"
  fi
}

stopped() {
  if invoke "$1" >"$MARKBEND_RECOVERY_DIRECTORY/$2.out" 2>"$MARKBEND_RECOVERY_DIRECTORY/$2.err"; then
    echo 'Journal writer did not stop' >&2
    exit 1
  else
    test "$?" -eq 79
  fi
}

for MARKBEND_JOURNAL_STOP in 0 1 2 3 4; do
  MARKBEND_RECOVERY_DIRECTORY="$journal_root/$MARKBEND_JOURNAL_STOP"
  mkdir "$MARKBEND_RECOVERY_DIRECTORY" "$MARKBEND_RECOVERY_DIRECTORY/journal"
  MARKBEND_RECOVERY_MODE=write
  MARKBEND_RECOVERY_DISK=old
  MARKBEND_JOURNAL_EXPECTED=old
  if [ "$MARKBEND_JOURNAL_STOP" -eq 4 ]; then MARKBEND_JOURNAL_EXPECTED=new; fi
  export MARKBEND_RECOVERY_DIRECTORY MARKBEND_RECOVERY_MODE MARKBEND_RECOVERY_DISK
  export MARKBEND_JOURNAL_STOP MARKBEND_JOURNAL_EXPECTED
  stopped "$writer" initial
  stopped "$updater" update
  MARKBEND_RECOVERY_MODE=read
  invoke "$updater"
done
