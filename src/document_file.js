function document_file_failure(code, message) {
  return { $: CID(Fail), error: io_tup(code >>> 0, message) };
}

function document_file_list(bytes) {
  let value = { $: CID(Nil) };
  for (let at = bytes.length; at > 0;) {
    value = { $: CID(Con), head: bytes[--at], tail: value };
  }
  return value;
}

function document_file_read_raw(path) {
  if (typeof require !== "function") {
    return document_file_failure(1, "Resolved file opening needs a filesystem host");
  }
  for (let at = 0; at < path.length; at++) {
    const code = path.charCodeAt(at);
    if (code === 0) return document_file_failure(22, "Document path contains NUL");
    if (code >= 0xd800 && code <= 0xdbff) {
      const next = path.charCodeAt(++at);
      if (!(next >= 0xdc00 && next <= 0xdfff)) {
        return document_file_failure(22, "Invalid document path encoding");
      }
    } else if (code >= 0xdc00 && code <= 0xdfff) {
      return document_file_failure(22, "Invalid document path encoding");
    }
  }
  let fd = null;
  let failure = null;
  let snapshot = null;
  let fs;
  try {
    fs = require("node:fs");
    if (typeof fs.constants.O_NONBLOCK !== "number" || !fs.constants.O_NONBLOCK ||
        typeof fs.constants.O_NOFOLLOW !== "number" || !fs.constants.O_NOFOLLOW) {
      throw new Error("Filesystem host cannot enforce the required file-opening flags");
    }
    const resolved = fs.realpathSync.native(Buffer.from(path), { encoding: "buffer" });
    const flags = fs.constants.O_RDONLY | (fs.constants.O_NONBLOCK || 0) |
      (fs.constants.O_NOFOLLOW || 0) | (fs.constants.O_CLOEXEC || 0);
    fd = fs.openSync(resolved, flags);
    const opened = fs.fstatSync(fd, { bigint: true });
    if (!opened.isFile()) throw Object.assign(new Error("Document is not a regular file"), { errno: 22 });
    if (opened.size > 8388608n) throw Object.assign(new Error("Document exceeds 8 MiB"), { errno: 27 });
    const bytes = Buffer.allocUnsafe(8388609);
    let length = 0;
    for (;;) {
      let count;
      try {
        count = fs.readSync(fd, bytes, length, Math.min(4096, 8388609 - length), null);
      } catch (error) {
        if (error.code === "EINTR") continue;
        throw error;
      }
      if (count === 0) break;
      length += count;
      if (length > 8388608) throw Object.assign(new Error("Document exceeds 8 MiB"), { errno: 27 });
    }
    const current = fs.lstatSync(resolved, { bigint: true });
    if (!current.isFile() || current.dev !== opened.dev || current.ino !== opened.ino) {
      throw Object.assign(new Error("Document destination changed during opening"), { errno: 1 });
    }
    snapshot = { resolved, identity: Buffer.concat([Buffer.from("PATH1:"), resolved]),
      bytes: bytes.subarray(0, length) };
  } catch (error) {
    failure = document_file_failure(Math.abs(Number(error.errno)) || 1, String(error.message));
  } finally {
    if (fd !== null) {
      try { fs.closeSync(fd); } catch (error) {
        if (!failure) failure = document_file_failure(Math.abs(Number(error.errno)) || 1, String(error.message));
      }
    }
  }
  if (failure) return failure;
  return io_done(io_tup(document_file_list(snapshot.resolved),
    io_tup(document_file_list(snapshot.identity), document_file_list(snapshot.bytes))));
}
io_eff(CID(read_raw), document_file_read_raw);
