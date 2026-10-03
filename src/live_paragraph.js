function live_paragraph_open(initial) {
  // Test the required synchronous retention service before accepting edits.
  // Browser main threads reject Atomics.wait, even with a zero timeout.
  try { Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 0); }
  catch (_) { throw new Error("This host cannot retain an input-ended editor session"); }
  return { initial };
}

function live_paragraph_next(window) {
  if (typeof prompt !== "function") {
    return io_tup(window, { $: CID(ParagraphInputEnded) });
  }
  const value = prompt("MarkBend live paragraph experiment", window.initial);
  if (value === null) {
    return io_tup(window, { $: CID(ParagraphInputEnded) });
  }
  if (value === ".save") return io_tup(window, { $: CID(ParagraphSave) });
  if (value === ".return") {
    const selection = window.selection || { start: 0, end: 0 };
    return io_tup(window, { $: CID(ParagraphReturn), start: selection.start, end: selection.end });
  }
  if (value === ".recheck") return io_tup(window, { $: CID(ParagraphRecheckSaveAs) });
  if (value === ".saveas" || value.startsWith(".saveas ")) {
    return io_tup(window, { $: CID(ParagraphSaveAs), requested: value === ".saveas" ? "" : value.slice(8) });
  }
  if (value === ".undo") return io_tup(window, { $: CID(ParagraphUndo) });
  if (value === ".redo") return io_tup(window, { $: CID(ParagraphRedo) });
  if (value === ".close") return io_tup(window, { $: CID(ParagraphClosed) });
  return io_tup(window, { $: CID(ParagraphChanged), text: value });
}

function live_paragraph_close_choice(window) {
  const value = typeof prompt === "function"
    ? prompt("Unsaved changes. Enter save, discard, or cancel.", "cancel") : null;
  return io_tup(window, value === null ? 3 : value === "save" ? 1 : value === "discard" ? 2 : 0);
}

function live_paragraph_pick_save_as(window) {
  return io_tup(window, { $: CID(SaveAsPickerUnavailable) });
}

function live_paragraph_status(window, message) {
  window.message = message;
  if (typeof console !== "undefined") console.error(message);
  return window;
}

function live_paragraph_close(window) {
  return { $: CID(Unit) };
}

function live_paragraph_set(window, source) {
  window.initial = source;
  window.runs = [];
  window.nativeOrder = undefined;
  window.retainedRuns = undefined;
  return window;
}

function live_paragraph_replace(window, start, end, text) {
  window.retainedRuns = window.runs;
  if (start === end && text.length === 0) {
    window.runs = [];
    return window;
  }
  const scalars = Array.from(window.initial);
  const lo = Math.min(Number(start), Number(end), scalars.length);
  const hi = Math.min(Math.max(Number(start), Number(end)), scalars.length);
  window.initial = scalars.slice(0, lo).join("") + text + scalars.slice(hi).join("");
  window.runs = [];
  return window;
}

function live_paragraph_append(window, text, style) {
  window.runs.push({ text, bold: style === 1 || (style >= 4 && style <= 9),
    italic: style === 2 || style === 10, code: style === 3,
    blockStyle: style >= 4 ? style : undefined });
  return window;
}

function live_paragraph_project(window, start, end) {
  window.selection = { start, end };
  return window;
}

function live_paragraph_append_scene(window, runs) {
  while (runs.$ === CID(Con)) {
    live_paragraph_append(window, runs.head.text, runs.head.style);
    runs = runs.tail;
  }
  return window;
}

function live_paragraph_append_chunks(window, chunks, cacheable) {
  const enabled = cacheable === true || cacheable.$ === CID(True);
  const previous = window.nativeChunks || new Map();
  const next = new Map();
  const order = [];
  while (chunks.$ === CID(Con)) {
    const chunk = chunks.head;
    let runs = enabled ? previous.get(chunk.id) : undefined;
    if (!runs || chunk.fresh === true || chunk.fresh.$ === CID(True)) {
      const local = { runs: [] };
      live_paragraph_append_scene(local, chunk.runs);
      runs = local.runs;
    }
    for (const run of runs) window.runs.push(run);
    if (enabled) { next.set(chunk.id, runs); order.push(chunk.id); }
    chunks = chunks.tail;
  }
  window.nativeChunks = next;
  window.nativeOrder = enabled ? order : undefined;
  window.retainedRuns = undefined;
  return window;
}

function live_paragraph_patch_chunks(window, patches) {
  if (!window.nativeOrder) {
    if (patches.$ === CID(Con)) throw new Error("LiveParagraph: scene patch needs a complete baseline");
    window.runs = window.retainedRuns || window.runs;
    window.retainedRuns = undefined;
    return window;
  }
  const cache = window.nativeChunks || new Map();
  let order = window.nativeOrder || [];
  while (patches.$ === CID(Con)) {
    const patch = patches.head;
    const first = Number(patch.first), removed = Number(patch.removed);
    if (first > order.length || removed > order.length - first) {
      throw new Error("LiveParagraph: scene patch block range failed");
    }
    const textLength = (ids) => ids.reduce((total, id) => total +
      cache.get(id).reduce((sum, run) => sum + run.text.length, 0), 0);
    if (Number(patch.start) !== textLength(order.slice(0, first)) ||
        Number(patch.length) !== textLength(order.slice(first, first + removed))) {
      throw new Error("LiveParagraph: scene patch native range failed");
    }
    let chunks = patch.chunks;
    const inserted = [];
    while (chunks.$ === CID(Con)) {
      const chunk = chunks.head;
      let runs = cache.get(chunk.id);
      if (!runs || chunk.fresh === true || chunk.fresh.$ === CID(True)) {
        const local = { runs: [] };
        live_paragraph_append_scene(local, chunk.runs);
        runs = local.runs;
      }
      cache.set(chunk.id, runs);
      inserted.push(chunk.id);
      chunks = chunks.tail;
    }
    const discarded = order.slice(first, first + removed);
    order = order.slice(0, first).concat(inserted, order.slice(first + removed));
    const retained = new Set(inserted);
    for (const id of discarded) if (!retained.has(id)) cache.delete(id);
    patches = patches.tail;
  }
  window.nativeChunks = cache;
  window.nativeOrder = order;
  window.runs = order.flatMap(id => cache.get(id));
  window.retainedRuns = undefined;
  return window;
}

io_eff(CID(LiveParagraph.open), live_paragraph_open);
if (typeof CID(LiveParagraph.pick_save_as) !== "undefined") {
  io_eff(CID(LiveParagraph.pick_save_as), live_paragraph_pick_save_as);
}
io_eff(CID(LiveParagraph.next), live_paragraph_next);
io_eff(CID(LiveParagraph.set), live_paragraph_set);
io_eff(CID(LiveParagraph.replace), live_paragraph_replace);
if (typeof CID(LiveParagraph.append) !== "undefined") {
  io_eff(CID(LiveParagraph.append), live_paragraph_append);
}
if (typeof CID(LiveParagraph.append_scene) !== "undefined") {
  io_eff(CID(LiveParagraph.append_scene), live_paragraph_append_scene);
}
io_eff(CID(LiveParagraph.append_chunks), live_paragraph_append_chunks);
io_eff(CID(LiveParagraph.patch_chunks), live_paragraph_patch_chunks);
io_eff(CID(LiveParagraph.close), live_paragraph_close);
io_eff(CID(LiveParagraph.project), live_paragraph_project);
if (typeof CID(LiveParagraph.close_choice) !== "undefined") {
  io_eff(CID(LiveParagraph.close_choice), live_paragraph_close_choice);
}
if (typeof CID(LiveParagraph.status) !== "undefined") {
  io_eff(CID(LiveParagraph.status), live_paragraph_status);
}
