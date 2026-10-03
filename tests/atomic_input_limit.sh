#!/bin/sh
# Check the exact host input bound before it can replace a file.
set -eu
program=$1
root=$2
mkdir "$root" "$root/accepted" "$root/rejected"
printf 'original' > "$root/original"
cp "$root/original" "$root/accepted/document"
cp "$root/original" "$root/rejected/document"
dd if=/dev/zero of="$root/input" bs=1048576 count=8 2>/dev/null
"$program" --save "$root/accepted" < "$root/input"
cmp "$root/input" "$root/accepted/document"
test ! -e "$root/accepted/pending"
printf '\000' >> "$root/input"
if "$program" --save "$root/rejected" < "$root/input" 2> "$root/error"; then
  echo 'Oversized save input was accepted' >&2
  exit 1
else
  test "$?" -eq 1
fi
case "$(cat "$root/error")" in
  'save input exceeds experiment limit:'*) ;;
  *) echo 'Oversized save failed for a different reason' >&2; exit 1 ;;
esac
cmp "$root/original" "$root/rejected/document"
test ! -e "$root/rejected/pending"
echo 'Atomic save input limit check passed'
