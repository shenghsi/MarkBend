#if defined(_WIN32)
#include <windows.h>
#else
#include <poll.h>
#include <errno.h>
#include <time.h>
#ifndef MARKBEND_SUSPEND_POLL
#define MARKBEND_SUSPEND_POLL() poll(NULL, 0, -1)
#endif
#endif
static void input_suspend_call(IoWork* work) {
  (void)work;
  for (;;) {
#if defined(_WIN32)
    Sleep(INFINITE);
#else
    int result = MARKBEND_SUSPEND_POLL();
    if (result < 0 && errno == EINTR) continue;
    // A failed host poll must not turn retained suspension into busy polling.
    struct timespec pause = {60, 0}, remaining;
    while (nanosleep(&pause, &remaining) < 0 && errno == EINTR) pause = remaining;
#endif
  }
}
static Term input_suspend_pack(Env e, IoWork* work) {
  (void)e; (void)work;
  return term_pak(CID(Unit), 0);
}
static Term input_suspend_run(Env e, Term* fields, IoWork* work) {
  (void)e; (void)fields;
  return io_work(work, input_suspend_call, input_suspend_pack);
}
static void __attribute__((constructor)) input_suspend_use(void) {
  io_eff(CID(wait), input_suspend_run, 0);
}
