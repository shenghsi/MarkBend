static unsigned app_pump_calls;
static Term app_pump_mark(Env e, Term* f, IoWork* w) {
  app_pump_calls++;
  return term_pak(CID(Unit), 0);
}
static Term app_pump_finish(Env e, Term* f, IoWork* w) {
  if (app_pump_calls != 10000) err_fail("App pump skipped a retained-state continuation");
  return term_pak(CID(Unit), 0);
}
static void __attribute__((constructor)) app_pump_use(void) {
  io_eff(CID(Driver.mark), app_pump_mark, 0);
  io_eff(CID(Driver.finish), app_pump_finish, 0);
}
