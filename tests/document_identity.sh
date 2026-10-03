#!/bin/sh
set -eu
program=$1
atomic=$2
root=$3
mkdir "$root" "$root/文件 space" "$root/other"
printf 'same' > "$root/文件 space/document"
printf 'same' > "$root/other/document"
ln -s '文件 space' "$root/alias"
ln -s '文件 space/document' "$root/link"
ln "$root/文件 space/document" "$root/hard-link"
"$program" "$root/文件 space/document" > "$root/before"
for path in "$root/alias/document" "$root/link" "$root/other/../文件 space/document"; do
  "$program" "$path" > "$root/observed"
  cmp "$root/before" "$root/observed"
done
(cd "$root"; "$program" '文件 space/document') > "$root/relative"
cmp "$root/before" "$root/relative"
if test -f "$root/文件 space/DOCUMENT"; then
  "$program" "$root/文件 space/DOCUMENT" > "$root/case-key"
  cmp "$root/before" "$root/case-key"
  echo 'Case aliases share the document identity'
else
  printf 'same' > "$root/文件 space/DOCUMENT"
  "$program" "$root/文件 space/DOCUMENT" > "$root/case-key"
  if cmp -s "$root/before" "$root/case-key"; then
    echo 'Distinct case-sensitive paths share an identity' >&2
    exit 1
  fi
  echo 'Case-sensitive paths have distinct identities'
fi
unicode_name=$(printf 'caf\303\251.md')
unicode_alias=$(printf 'cafe\314\201.md')
printf 'same' > "$root/$unicode_name"
"$program" "$root/$unicode_name" > "$root/unicode-key"
if test -f "$root/$unicode_alias"; then
  "$program" "$root/$unicode_alias" > "$root/unicode-alias-key"
  cmp "$root/unicode-key" "$root/unicode-alias-key"
  echo 'Unicode aliases share the document identity'
else
  printf 'same' > "$root/$unicode_alias"
  "$program" "$root/$unicode_alias" > "$root/unicode-alias-key"
  if cmp -s "$root/unicode-key" "$root/unicode-alias-key"; then
    echo 'Distinct Unicode paths share an identity' >&2
    exit 1
  fi
  echo 'Distinct Unicode paths have distinct identities'
fi
"$program" "$root/other/document" > "$root/other-key"
if cmp -s "$root/before" "$root/other-key"; then
  echo 'Different document paths share an identity' >&2
  exit 1
fi
"$program" "$root/hard-link" > "$root/hard-link-before"
if cmp -s "$root/before" "$root/hard-link-before"; then
  echo 'Different hard-link destinations share a path identity' >&2
  exit 1
fi
printf 'replacement' | "$atomic" --save "$root/文件 space"
"$program" "$root/文件 space/document" > "$root/after"
cmp "$root/before" "$root/after"
"$program" "$root/hard-link" > "$root/hard-link-after"
cmp "$root/hard-link-before" "$root/hard-link-after"
printf 'same' > "$root/expected-hard-link"
cmp "$root/expected-hard-link" "$root/hard-link"
printf 'replacement' > "$root/expected-replacement"
cmp "$root/expected-replacement" "$root/文件 space/document"
mkfifo "$root/fifo"
for path in "$root/other" "$root/missing" "$root/fifo"; do
  if "$program" "$path" > "$root/rejected.out" 2> "$root/rejected.err"; then
    echo 'Invalid identity target was accepted' >&2
    exit 1
  else
    test "$?" -eq 1
  fi
  test ! -s "$root/rejected.out"
done
echo 'Document path identity check passed'
