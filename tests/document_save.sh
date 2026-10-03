#!/bin/sh
set -eu
program=$1
runtime=${2:-native}
save_root=$(mktemp -d /tmp/markbend-document-save.XXXXXX)
trap 'rm -rf "$save_root"' EXIT HUP INT TERM
save_root=$(cd "$save_root" && pwd -P)
path="$save_root/中文 😀.md"
printf '\101\015\012\000\377' > "$path"
cp "$path" "$save_root/before"
printf '\357\273\277\344\270\255\360\237\230\200\015\012\000' > "$save_root/expected"
invoke() {
  if test "$runtime" = native; then "$program" "$@"; else "$runtime" "$program" "$@"; fi
}
if test "$runtime" != native; then
  invoke "$path" unavailable
  cmp "$path" "$save_root/before"
  printf 'JavaScript save returned unavailable and kept exact disk bytes (%s)\n' "$runtime"
  exit 0
fi
chmod 0640 "$path"
for invalid in bad-identity bad-baseline bad-output; do
  invoke "$path" "$invalid"
  cmp "$path" "$save_root/before"
done
invoke "$path" save
cmp "$path" "$save_root/expected"
invoke "$path" conflict
cmp "$path" "$save_root/expected"
invoke "$save_root/missing" reject
test ! -e "$save_root/missing"
mkdir "$save_root/directory"
invoke "$save_root/directory" reject
mkfifo "$save_root/fifo"
invoke "$save_root/fifo" reject
ln -s '中文 😀.md' "$save_root/alias"
invoke "$save_root/alias" conflict
cmp "$path" "$save_root/expected"
printf 'Bend native save effect exact bytes and rejected destinations passed\n'
