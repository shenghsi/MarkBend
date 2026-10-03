#!/bin/sh
set -eu
program=$1
runtime=${2:-native}
check_file() {
  if test "$runtime" = native; then "$program" "$@"; else "$runtime" "$program" "$@"; fi
}
resolved_root=$(mktemp -d /tmp/markbend-resolved-file.XXXXXX)
trap 'rm -rf "$resolved_root"' EXIT HUP INT TERM
resolved_root=$(cd "$resolved_root" && pwd -P)
printf '\357\273\277# 中文😀\r\n\000' > "$resolved_root/中文 😀.md"
cp "$resolved_root/中文 😀.md" "$resolved_root/expected"
ln -s '中文 😀.md' "$resolved_root/alias"
touch "$resolved_root/empty"
printf '\377' > "$resolved_root/invalid"
mkfifo "$resolved_root/fifo"
check_file "$resolved_root/中文 😀.md" "$resolved_root/中文 😀.md" valid
check_file "$resolved_root/alias" "$resolved_root/中文 😀.md" valid
check_file "$resolved_root/empty" "$resolved_root/empty" empty
check_file "$resolved_root/invalid" "$resolved_root/invalid" invalid
check_file "$resolved_root" '' reject
check_file "$resolved_root/fifo" '' reject
check_file "$resolved_root/missing" '' reject
if test "$(uname -s)" = Linux; then
  invalid_leaf=$(printf 'bad-\377')
  cp "$resolved_root/expected" "$resolved_root/$invalid_leaf"
  ln -s "$invalid_leaf" "$resolved_root/path-alias"
  check_file "$resolved_root/path-alias" "$resolved_root/bad-" invalid-path
fi
cmp "$resolved_root/expected" "$resolved_root/中文 😀.md"
printf 'Resolved opening to exact app document and rejected results passed\n'
