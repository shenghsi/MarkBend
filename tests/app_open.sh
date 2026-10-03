#!/bin/sh
# Check the real app entry point without a user input step.
set -eu
program=$1
runtime=$2
app_root=$(mktemp -d /tmp/markbend-app-open.XXXXXX)
unset MARKBEND_STARTUP_RECOVERY_HOST MARKBEND_STARTUP_RECOVERY_ROOT
trap 'rm -rf "$app_root"' EXIT HUP INT TERM
printf '\357\273\277# 中文😀\r\n\000' > "$app_root/source.md"
ln -s source.md "$app_root/alias.md"
printf '\377' > "$app_root/invalid.md"
mkdir "$app_root/directory"
mkfifo "$app_root/fifo"
export MARKBEND_OPEN_PATH="$app_root/alias.md"
export MARKBEND_APP_PROGRAM="$program"
export MARKBEND_APP_EXPECTED="$app_root/source.md"
unset MARKBEND_APP_REJECT
if test "$runtime" = native; then
  "$program" </dev/null > "$app_root/output"
else
  "$runtime" -e 'const fs=require("node:fs"), assert=require("node:assert/strict"); let shown=0; globalThis.prompt=(_,source)=>{shown++; assert.equal(source,fs.readFileSync(process.env.MARKBEND_APP_EXPECTED,"utf8")); return null;}; require(process.env.MARKBEND_APP_PROGRAM); assert.equal(shown,1);'
fi
if test "${3:-}" = guard; then
  export MARKBEND_APP_REJECT=1
  if "$program" </dev/null > "$app_root/output" 2>&1; then exit 1; fi
  case "$(cat "$app_root/output")" in
    *'Rejected file opened an editor (display call)'*) ;;
    *) exit 1 ;;
  esac
fi
for rejected in invalid.md directory fifo missing.md; do
  export MARKBEND_APP_REJECT=1
  export MARKBEND_OPEN_PATH="$app_root/$rejected"
  if test "$runtime" = native; then
    if "$program" </dev/null > "$app_root/output" 2>&1; then exit 1; fi
  else
    if "$runtime" -e 'globalThis.prompt=()=>{throw new Error("Rejected file opened an editor")}; require(process.env.MARKBEND_APP_PROGRAM);' > "$app_root/output" 2>&1; then exit 1; fi
  fi
  case "$(cat "$app_root/output")" in
    *'Rejected file opened an editor'*) exit 1 ;;
  esac
  test -s "$app_root/output"
  case "$(cat "$app_root/output")" in
    *'Cannot open this file:'*|*'Cannot read this file:'*) ;;
    *) exit 1 ;;
  esac
done
printf 'App startup accepted a resolved alias and rejected invalid files (%s)\n' "$runtime"
