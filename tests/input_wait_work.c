#include <assert.h>
#include <stdint.h>
#include <stdlib.h>

typedef uintptr_t Term;
typedef int Env;
typedef struct IoWork { char* data; } IoWork;
static int allocated, released;
static void* tracked_calloc(size_t count, size_t size) {
  void* value = calloc(count, size);
  if (value) allocated++;
  return value;
}
static void tracked_free(void* value) {
  if (value) released++;
  free(value);
}
static Term io_work(IoWork* work, void (*call)(IoWork*), Term (*pack)(Env, IoWork*)) {
  call(work);
  return pack(0, work);
}
static void io_eff(int id, Term (*run)(Env, Term*, IoWork*), int flags) {
  (void)id; (void)run; (void)flags;
}
#define CID(name) 0
#define calloc tracked_calloc
#define free tracked_free
#include "../src/input_wait.c"
#undef calloc
#undef free

int main(void) {
  for (int n = 0; n < 1000; n++) {
    IoWork work = {NULL};
    Term arguments[2] = {0, 0};
    assert(input_wait_run(0, arguments, &work) == 4);
    assert(work.data == NULL);
    assert(allocated == n + 1 && released == allocated);
  }
  return 0;
}
