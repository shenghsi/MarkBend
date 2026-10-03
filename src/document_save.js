// No path-based substitute for the held-directory native save operation.
// A JavaScript save service must supply that operation before it can write.
function document_save_write_raw(path, identity, baseline, bytes) {
  return 4;
}
io_eff(CID(write_raw), document_save_write_raw);
