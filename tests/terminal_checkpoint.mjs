const header = Buffer.from("--- MarkBend multiline checkpoint ---");
const prefix = Buffer.from("\nSource: ");
const suffix = Buffer.from("\nEnter replacement text,");

export function completeCheckpoint(output) {
  const last = output.lastIndexOf(header);
  if (last < 0) return null;
  const source = output.indexOf(prefix, last + header.length);
  if (source < 0) return null;
  const end = output.indexOf(suffix, source + prefix.length);
  if (end < 0) return null;
  let count = 0, at = 0;
  while ((at = output.indexOf(header, at)) >= 0) { count++; at += header.length; }
  return { count, start: source + prefix.length };
}
