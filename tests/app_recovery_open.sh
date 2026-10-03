#!/bin/sh
set -eu
app=$1
writer=$2
atomic=$3
host=$4
runtime=${5:-native}
startup_root=$(mktemp -d /tmp/markbend-recovery-startup.XXXXXX)
trap 'rm -rf "$startup_root"' EXIT HUP INT TERM
startup_root=$(cd "$startup_root" && pwd -P)
mkdir "$startup_root/source" "$startup_root/catalog"
printf 'A\r\n' > "$startup_root/source/中文 😀.md"
cp "$startup_root/source/中文 😀.md" "$startup_root/source/other.md"
printf '\357\273\277# 中文😀\r\n\r\n**e\314\201**\000\n' > "$startup_root/recovered"
ln -s 'source/中文 😀.md' "$startup_root/alias.md"
ln -s source/other.md "$startup_root/other-alias.md"
export MARKBEND_OPEN_PATH="$startup_root/alias.md"
export MARKBEND_APP_PROGRAM="$app"
export MARKBEND_APP_EXPECTED="$startup_root/recovered"
export MARKBEND_STARTUP_RECOVERY_HOST="$host"
export MARKBEND_STARTUP_RECOVERY_ROOT="$startup_root/catalog"
invoke() {
  if test "$runtime" = native; then
    printf '.close\n.discard\n' | "$app"
  else
    node "$(dirname "$0")/watchdog.mjs" 20000 "$runtime" -e 'const fs=require("node:fs"),assert=require("node:assert/strict");let shown=0,choices=0;const expected=fs.readFileSync(process.env.MARKBEND_APP_EXPECTED),before=fs.readFileSync(process.env.MARKBEND_OPEN_PATH),dirty=!expected.equals(before);process.on("exit",code=>{if(code===0){assert.equal(shown,1);assert.equal(choices,dirty?1:0);assert.deepEqual(fs.readFileSync(process.env.MARKBEND_OPEN_PATH),before);}});globalThis.prompt=(message,source)=>{if(process.env.MARKBEND_APP_REJECT)throw new Error("Rejected file opened an editor");if(message.startsWith("Unsaved changes.")){assert.equal(dirty,true);assert.equal(shown,1);assert.equal(choices++,0);return "discard";}assert.equal(shown++,0);assert.equal(source,expected.toString("utf8"));return ".close";};require(process.env.MARKBEND_APP_PROGRAM);'
  fi
}
snapshot() {
  cp "$startup_root/source/中文 😀.md" "$startup_root/owner-before"
  cp "$startup_root/source/other.md" "$startup_root/other-before"
  find "$startup_root/source" "$startup_root/catalog" -print | LC_ALL=C sort > "$startup_root/names-before"
  for record in entry bad duplicate; do
    if test -f "$startup_root/catalog/$record/document"; then
      cp "$startup_root/catalog/$record/document" "$startup_root/$record-before"
    fi
  done
}
unchanged() {
  cmp "$startup_root/owner-before" "$startup_root/source/中文 😀.md"
  cmp "$startup_root/other-before" "$startup_root/source/other.md"
  find "$startup_root/source" "$startup_root/catalog" -print | LC_ALL=C sort > "$startup_root/names-after"
  cmp "$startup_root/names-before" "$startup_root/names-after"
  for record in entry bad duplicate; do
    if test -f "$startup_root/catalog/$record/document"; then
      cmp "$startup_root/$record-before" "$startup_root/catalog/$record/document"
    fi
  done
}
rejected() {
  export MARKBEND_APP_REJECT=1
  snapshot
  if invoke > "$startup_root/output" 2>&1; then exit 1; else
    invoke_status=$?
    if test "$invoke_status" -eq 124; then cat "$startup_root/output" >&2; exit 1; fi
  fi
  case "$(cat "$startup_root/output")" in
    *'Rejected file opened an editor'*) cat "$startup_root/output" >&2; exit 1 ;;
    *'--- MarkBend multiline checkpoint ---'*) cat "$startup_root/output" >&2; exit 1 ;;
  esac
  case "$(cat "$startup_root/output")" in
    *'Cannot recover this file:'*) ;;
    *) cat "$startup_root/output" >&2; exit 1 ;;
  esac
  unchanged
}
accepted() {
  unset MARKBEND_APP_REJECT
  export MARKBEND_APP_EXPECTED="$1"
  snapshot
  invoke > "$startup_root/output" 2>&1
  if test "$runtime" = native && test "$(uname -s)" = Linux; then
    node "$(dirname "$0")/terminal_source_check.mjs" "$startup_root/output" "$MARKBEND_APP_EXPECTED"
  fi
  unchanged
}
unset MARKBEND_STARTUP_RECOVERY_ROOT
rejected
export MARKBEND_STARTUP_RECOVERY_ROOT="$startup_root/catalog"
unset MARKBEND_STARTUP_RECOVERY_HOST
rejected
export MARKBEND_STARTUP_RECOVERY_HOST=''
rejected
MARKBEND_STARTUP_RECOVERY_HOST="$host"
MARKBEND_STARTUP_RECOVERY_ROOT=''
rejected
MARKBEND_STARTUP_RECOVERY_ROOT="$startup_root/catalog"
if test "$runtime" = native; then
  MARKBEND_STARTUP_RECOVERY_HOST=$(printf '\377')
  rejected
  MARKBEND_STARTUP_RECOVERY_HOST="$host"
  MARKBEND_STARTUP_RECOVERY_ROOT=$(printf '\377')
  rejected
  MARKBEND_STARTUP_RECOVERY_ROOT="$startup_root/catalog"
fi
if test "$runtime" = node; then
  rejected
  case "$(cat "$startup_root/output")" in
    *'the process host is unavailable'*) ;;
    *) exit 1 ;;
  esac
  printf 'Node startup rejected unavailable recovery process host before display\n'
  exit 0
fi
accepted "$startup_root/source/中文 😀.md"
mkdir "$startup_root/catalog/entry"
if "$writer" write "$atomic" "$host" "$startup_root" > "$startup_root/writer.out" 2>&1; then
  exit 1
else test "$?" -eq 79; fi
test -s "$startup_root/catalog/entry/document"
accepted "$startup_root/recovered"
MARKBEND_OPEN_PATH="$startup_root/other-alias.md"
accepted "$startup_root/source/other.md"
MARKBEND_OPEN_PATH="$startup_root/alias.md"
printf 'B\r\n' > "$startup_root/source/中文 😀.md"
accepted "$startup_root/recovered"
printf 'X\r\n' > "$startup_root/source/中文 😀.md"
rejected
MARKBEND_STARTUP_RECOVERY_ROOT="$startup_root/missing"
rejected
MARKBEND_STARTUP_RECOVERY_ROOT="$startup_root/catalog"
MARKBEND_STARTUP_RECOVERY_HOST="$startup_root/missing-host"
rejected
MARKBEND_STARTUP_RECOVERY_HOST="$host"
mkdir "$startup_root/catalog/bad"
printf 'broken\000\377' > "$startup_root/catalog/bad/document"
rejected
mv "$startup_root/catalog/bad" "$startup_root/rejected-record"
printf 'A\r\n' > "$startup_root/source/中文 😀.md"
mkdir "$startup_root/catalog/duplicate"
if "$writer" duplicate-write "$atomic" "$host" "$startup_root" > "$startup_root/writer.out" 2>&1; then
  exit 1
else test "$?" -eq 79; fi
rejected
printf 'App recovery startup source and blocked display checks passed (%s)\n' "$runtime"
