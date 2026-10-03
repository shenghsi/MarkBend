function open_config_read_bytes() {
  if (typeof process === "undefined" || !process.env ||
      !Object.prototype.hasOwnProperty.call(process.env, "MARKBEND_OPEN_PATH")) {
    return { $: CID(None) };
  }
  const path = process.env.MARKBEND_OPEN_PATH;
  // Do not replace an unpaired UTF-16 surrogate with a different path.
  for (let at = 0; at < path.length; at++) {
    const code = path.charCodeAt(at);
    if (code >= 0xd800 && code <= 0xdbff) {
      const next = path.charCodeAt(++at);
      if (!(next >= 0xdc00 && next <= 0xdfff)) throw new Error("Invalid startup path encoding");
    } else if (code >= 0xdc00 && code <= 0xdfff) {
      throw new Error("Invalid startup path encoding");
    }
  }
  const raw = new TextEncoder().encode(path);
  let bytes = { $: CID(Nil) };
  for (let at = raw.length; at > 0;) bytes = { $: CID(Con), head: raw[--at], tail: bytes };
  return { $: CID(Some), value: bytes };
}

io_eff(CID(read_bytes), open_config_read_bytes);
