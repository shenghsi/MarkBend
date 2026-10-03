function recovery_config_bytes(name) {
  if (typeof process === "undefined" || !process.env ||
      !Object.prototype.hasOwnProperty.call(process.env, name)) {
    return { $: CID(None) };
  }
  const value = process.env[name];
  if (typeof value !== "string") throw new Error("Invalid recovery setting encoding");
  for (let at = 0; at < value.length; at++) {
    const code = value.charCodeAt(at);
    if (code >= 0xd800 && code <= 0xdbff) {
      const next = value.charCodeAt(++at);
      if (!(next >= 0xdc00 && next <= 0xdfff)) throw new Error("Invalid recovery setting encoding");
    } else if (code >= 0xdc00 && code <= 0xdfff) {
      throw new Error("Invalid recovery setting encoding");
    }
  }
  const raw = new TextEncoder().encode(value);
  let bytes = { $: CID(Nil) };
  for (let at = raw.length; at > 0;) bytes = { $: CID(Con), head: raw[--at], tail: bytes };
  return { $: CID(Some), value: bytes };
}

function recovery_config_read() {
  try {
    const host = recovery_config_bytes("MARKBEND_STARTUP_RECOVERY_HOST");
    const root = recovery_config_bytes("MARKBEND_STARTUP_RECOVERY_ROOT");
    const available = typeof Bun !== "undefined" && typeof Bun.spawnSync === "function";
    return io_done(io_tup(available, io_tup(host, root)));
  } catch (error) {
    // Do not use io_fail: its runtime dependency needs Bun even on Node.
    return { $: CID(Fail), error: io_tup(22, String(error.message)) };
  }
}

io_eff(CID(read), recovery_config_read);
