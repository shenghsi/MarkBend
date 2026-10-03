static Term recovery_config_bytes(Env e, const char* name) {
  const unsigned char* value = (const unsigned char*)getenv(name);
  if (!value) return term_pak(CID(None), 0);
  size_t length = strlen((const char*)value);
  Term bytes = term_pak(CID(Nil), 0);
  while (length) bytes = io_node(e, CID(Con), (Term)value[--length], bytes);
  return io_box(e, CID(Some), bytes);
}

static Term recovery_config_read(Env e, Term* f, IoWork* w) {
  Term host = recovery_config_bytes(e, "MARKBEND_STARTUP_RECOVERY_HOST");
  Term root = recovery_config_bytes(e, "MARKBEND_STARTUP_RECOVERY_ROOT");
  return io_done(e, io_tup(e, term_pak(CID(True), 0), io_tup(e, host, root)));
}

static void __attribute__((constructor)) recovery_config_use(void) {
  io_eff(CID(read), recovery_config_read, 0);
}
