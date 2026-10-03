#!/bin/sh
set -eu
program=$1
runtime=${2:-native}
check_file() {
  if test "$runtime" = native; then "$program" "$@"; else "$runtime" "$program" "$@"; fi
}
file_root=$(mktemp -d /tmp/markbend-document-file.XXXXXX)
trap 'rm -rf "$file_root"' EXIT HUP INT TERM
file_root=$(cd "$file_root" && pwd -P)
mkdir "$file_root/directory"
printf '\357\273\277\043\040\101\015\012\000\360\237\230\200\377\303\050' > "$file_root/中文 😀.md"
touch "$file_root/empty"
ln -s '中文 😀.md' "$file_root/alias"
mkfifo "$file_root/fifo"
dd if=/dev/zero of="$file_root/limit" bs=1048576 count=8 2>/dev/null
cp "$file_root/limit" "$file_root/over"
printf '\000' >> "$file_root/over"
check_file "$file_root/中文 😀.md" "$file_root/中文 😀.md" bytes
check_file "$file_root/alias" "$file_root/中文 😀.md" bytes
check_file "$file_root/empty" "$file_root/empty" empty
check_file "$file_root/limit" "$file_root/limit" limit
for name in over directory fifo missing; do
  check_file "$file_root/$name" '' reject
done
check_file "$file_root/empty"
printf 'Resolved file exact bytes, paths, limits, and rejected targets passed\n'
