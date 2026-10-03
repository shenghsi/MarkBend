function native_paragraph_edit(initial) {
  if (typeof prompt === "function") {
    const value = prompt("MarkBend native paragraph experiment", initial);
    return value === null ? initial : value;
  }
  return initial;
}

io_eff(CID(NativeParagraph.edit), native_paragraph_edit);
