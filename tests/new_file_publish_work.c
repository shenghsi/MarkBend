#define _GNU_SOURCE
#define _DARWIN_C_SOURCE
#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
typedef uintptr_t Term;
typedef uint64_t u64;
typedef int Env;
typedef struct IoWork { char* data; } IoWork;
static int allocated, released, invalid;
static void* tracked_calloc(size_t count, size_t size) {
  void* value = calloc(count, size); if (value) allocated++; return value;
}
static void tracked_free(void* value) { if (value) released++; free(value); }
static char* copied(const char* text, u64* size) {
  *size = strlen(text); char* value = malloc(*size + 1); assert(value);
  memcpy(value, text, *size + 1); allocated++; return value;
}
static char* io_cstr(Env e, Term value, u64* size) {
  (void)e; (void)value; return copied("relative.md", size);
}
static char* io_cbuf(Env e, Term value, u64* size, int tag) {
  (void)e; (void)tag;
  if (invalid && value == 2) return NULL;
  return copied("bytes", size);
}
static Term io_work(IoWork* work, void (*call)(IoWork*), Term (*pack)(Env, IoWork*)) {
  call(work); return pack(0, work);
}
static void io_eff(int id, Term (*run)(Env, Term*, IoWork*), int flags) {
  (void)id; (void)run; (void)flags;
}
#define CID(name) 0
#define calloc tracked_calloc
#define free tracked_free
#include "../src/new_file_publish.c"
#undef calloc
#undef free
int main(void) {
  for (int i = 0; i < 1000; i++) {
    IoWork work = {NULL}; Term arguments[4] = {0, 1, 2, 3}; invalid = i % 2;
    assert(new_publish_run(0, arguments, &work) == MB_NEW_OLD);
    assert(work.data == NULL && allocated == released);
  }
  return 0;
}
