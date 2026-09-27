function live_paragraph_open(initial) {
  return { initial, sent: false };
}

function live_paragraph_next(window) {
  if (window.sent || typeof prompt !== "function") {
    return io_tup(window, { $: CID(ParagraphClosed) });
  }
  const value = prompt("MarkBend live paragraph experiment", window.initial);
  window.sent = true;
  if (value === null) {
    return io_tup(window, { $: CID(ParagraphClosed) });
  }
  return io_tup(window, { $: CID(ParagraphChanged), text: value });
}

function live_paragraph_close(window) {
  return { $: CID(Unit) };
}

function live_paragraph_set(window, source, preview, bold) {
  window.initial = source;
  window.preview = preview;
  window.bold = bold !== 0;
  return window;
}

io_eff(CID(LiveParagraph.open), live_paragraph_open);
io_eff(CID(LiveParagraph.next), live_paragraph_next);
io_eff(CID(LiveParagraph.set), live_paragraph_set);
io_eff(CID(LiveParagraph.close), live_paragraph_close);
