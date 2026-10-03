// Test-only value outside the valid Unicode scalar constructor contract.
Term invalid_string_run(Env e, Term* f, IoWork* w) {
  return io_node(e, CID(SCon), (Term)55296, term_pak(CID(SNil), 0));
}

static void __attribute__((constructor)) invalid_string_use(void) {
  io_eff(CID(Driver.invalid), invalid_string_run, 0);
}
