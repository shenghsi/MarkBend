static Term open_config_read_bytes(Env e, Term* f, IoWork* w) {
  (void)f; (void)w;
  const unsigned char* path = (const unsigned char*)getenv("MARKBEND_OPEN_PATH");
  if (!path) return term_pak(CID(None), 0);
  size_t length = strlen((const char*)path);
  Term bytes = term_pak(CID(Nil), 0);
  while (length) bytes = io_node(e, CID(Con), (Term)path[--length], bytes);
  return io_box(e, CID(Some), bytes);
}

static void __attribute__((constructor)) open_config_use(void) {
  io_eff(CID(read_bytes), open_config_read_bytes, 0);
}
