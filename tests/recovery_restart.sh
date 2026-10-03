#!/bin/sh
# The writer and reader are separate processes. Never reuse the writer's memory.
set -eu
runtime=$1
program=$2
MARKBEND_ATOMIC_HOST=$3
recovery_root=$4
export MARKBEND_ATOMIC_HOST
mkdir "$recovery_root"

invoke() {
  if [ "$runtime" = native ]; then
    "$program"
  else
    "$runtime" "$program"
  fi
}

for MARKBEND_RECOVERY_DISK in old new; do
  MARKBEND_RECOVERY_DIRECTORY="$recovery_root/$MARKBEND_RECOVERY_DISK"
  mkdir "$MARKBEND_RECOVERY_DIRECTORY" "$MARKBEND_RECOVERY_DIRECTORY/journal"
  MARKBEND_RECOVERY_MODE=write
  export MARKBEND_RECOVERY_DIRECTORY MARKBEND_RECOVERY_MODE MARKBEND_RECOVERY_DISK
  if invoke >"$MARKBEND_RECOVERY_DIRECTORY/writer.out" 2>"$MARKBEND_RECOVERY_DIRECTORY/writer.err"; then
    echo 'Recovery writer did not stop with the expected exit status' >&2
    exit 1
  else
    test "$?" -eq 79
  fi
  MARKBEND_RECOVERY_MODE=read
  invoke
done
