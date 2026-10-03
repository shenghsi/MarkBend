#!/bin/sh
set -eu
program=$1
root=$2
mkdir "$root" "$root/store" "$root/store/a" "$root/store/empty"
printf 'record\000\377' > "$root/store/a/document"
printf 'note' > "$root/store/note"
ln -s a "$root/store/alias"
ln -s a/document "$root/store/link"
mkfifo "$root/store/fifo"
line_name=$(printf 'line\nEND')
mkdir "$root/store/$line_name"
cp "$root/store/a/document" "$root/store/$line_name/document"
binary_name=$(printf 'bad\377')
read_names='61 6c696e650a454e44'
if LC_ALL=C mkdir "$root/store/$binary_name" 2> "$root/name-error"; then
  cp "$root/store/a/document" "$root/store/$binary_name/document"
  read_names='61 6c696e650a454e44 626164ff'
else
  test "$(uname -s)" = Darwin
  case "$(cat "$root/name-error")" in
    *'Illegal byte sequence'*) ;;
    *) echo 'Unexpected non-UTF-8 directory creation error' >&2; exit 1 ;;
  esac
  test ! -e "$root/store/$binary_name"
  echo 'Non-UTF-8 names are unavailable on this macOS filesystem'
fi
"$program" --list "$root/store" > "$root/list"
test "$(tail -n 1 "$root/list")" = END
sort "$root/list" > "$root/list-sorted"
printf 'D 61\nD 656d707479\nD 6c696e650a454e44\nEND\nX 616c696173\nX 6669666f\nX 6c696e6b\nX 6e6f7465\n' > "$root/expected-list"
if [ "$read_names" = '61 6c696e650a454e44 626164ff' ]; then printf 'D 626164ff\n' >> "$root/expected-list"; fi
sort "$root/expected-list" > "$root/expected-sorted"
cmp "$root/list-sorted" "$root/expected-sorted"
for name in $read_names; do
  "$program" --read "$root/store" "$name" > "$root/read"
  cmp "$root/store/a/document" "$root/read"
done
for name in 656d707479 616c696173 6e6f7465 2e 2e2e 2f 00 0g 6; do
  if "$program" --read "$root/store" "$name" > "$root/rejected"; then
    echo 'Unsafe or unreadable candidate was accepted' >&2; exit 1
  else test "$?" -eq 1; fi
  test ! -s "$root/rejected"
done
mkdir "$root/store/oversized" "$root/store/symlink-record" "$root/store/fifo-record"
dd if=/dev/zero of="$root/store/oversized/document" bs=1048576 count=8 2>/dev/null
"$program" --read "$root/store" 6f76657273697a6564 > "$root/read"
cmp "$root/store/oversized/document" "$root/read"
printf '\000' >> "$root/store/oversized/document"
ln -s ../a/document "$root/store/symlink-record/document"
mkfifo "$root/store/fifo-record/document"
for name in 6f76657273697a6564 73796d6c696e6b2d7265636f7264 6669666f2d7265636f7264; do
  if "$program" --read "$root/store" "$name" > "$root/rejected"; then
    echo 'Unsafe or oversized record was accepted' >&2; exit 1
  else test "$?" -eq 1; fi
  test ! -s "$root/rejected"
done
mkdir "$root/empty-root"
"$program" --list "$root/empty-root" > "$root/empty-list"
printf 'END\n' > "$root/expected-empty"
cmp "$root/empty-list" "$root/expected-empty"
ln -s store "$root/root-link"
for path in "$root/missing" "$root/store/note" "$root/root-link"; do
  if "$program" --list "$path" > "$root/rejected"; then
    echo 'Invalid scan root was accepted' >&2; exit 1
  else test "$?" -eq 1; fi
  test ! -s "$root/rejected"
done
echo 'Recovery directory effect check passed'
