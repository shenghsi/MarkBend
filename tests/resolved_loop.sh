#!/bin/sh
set -eu
program=$1
runtime=${2:-native}
loop_root=$(mktemp -d /tmp/markbend-resolved-loop.XXXXXX)
trap 'rm -rf "$loop_root"' EXIT HUP INT TERM
loop_root=$(cd "$loop_root" && pwd -P)
printf 'ab 中文😀\r\n\000' > "$loop_root/中文 😀.md"
cp "$loop_root/中文 😀.md" "$loop_root/expected"
ln -s '中文 😀.md' "$loop_root/alias.md"
if test "$runtime" = native; then
  "$program" "$loop_root/alias.md" "$loop_root/中文 😀.md" --threads 4
else
  "$runtime" "$program" "$loop_root/alias.md" "$loop_root/中文 😀.md"
fi
cmp "$loop_root/expected" "$loop_root/中文 😀.md"
