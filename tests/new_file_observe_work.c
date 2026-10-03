#define _GNU_SOURCE
#define _DARWIN_C_SOURCE
#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
typedef uintptr_t Term;
typedef uint64_t u64;
typedef int Env;
typedef struct IoWork { char* data; } IoWork;
static void* owned[8];
static int allocated, released, mode;
static char fixture[8192], identity[8192], parent[80];
static void remember(void* value) {
  assert(value); for (int i = 0; i < 8; i++) if (!owned[i]) { owned[i] = value; allocated++; return; }
  assert(0);
}
static void* tracked_calloc(size_t count, size_t size) {
  void* value = calloc(count, size); if (value) remember(value); return value;
}
static void tracked_free(void* value) {
  if (value) for (int i = 0; i < 8; i++) if (owned[i] == value) { owned[i] = NULL; released++; break; }
  free(value);
}
static char* copied(const char* text, u64* size) {
  *size = strlen(text); char* value = malloc(*size + 1); remember(value);
  memcpy(value, text, *size + 1); return value;
}
static char* io_cstr(Env e, Term value, u64* size) {
  (void)e; (void)value; char* text = copied(fixture, size); if (mode == 2) text[1] = 0; return text;
}
static char* io_cbuf(Env e, Term value, u64* size, int tag) {
  (void)e; (void)tag;
  if (mode == 1 && value == 2) return NULL;
  return copied(value == 1 ? identity : value == 2 ? parent : mode == 3 ? "B" : "A", size);
}
static Term io_work(IoWork* work, void (*call)(IoWork*), Term (*pack)(Env, IoWork*)) {
  call(work); return pack(0, work);
}
static void io_eff(int id, Term (*run)(Env, Term*, IoWork*), int flags) { (void)id; (void)run; (void)flags; }
#define CID(name) 0
#define calloc tracked_calloc
#define free tracked_free
#include "../src/new_file_observe.c"
#undef calloc
#undef free
int main(void) {
  char root[] = "/tmp/markbend-observe-work.XXXXXX"; assert(mkdtemp(root));
  char* canonical = realpath(root, NULL); assert(canonical);
  snprintf(fixture, sizeof(fixture), "%s/new.md", canonical);
  snprintf(identity, sizeof(identity), "PATH1:%s", fixture);
  struct stat info; assert(stat(canonical, &info) == 0);
  snprintf(parent, sizeof(parent), "DIR1:%ju:%ju", (uintmax_t)info.st_dev, (uintmax_t)info.st_ino);
  int file = open(fixture, O_CREAT | O_EXCL | O_WRONLY, 0600); assert(file >= 0);
  assert(write(file, "A", 1) == 1); assert(close(file) == 0);
  for (int i = 0; i < 1000; i++) {
    mode = i % 4; IoWork work = {NULL}; Term arguments[4] = {0, 1, 2, 3};
    assert(new_observe_run(0, arguments, &work) == (mode == 0 ? 0 : 1));
    assert(work.data == NULL && allocated == released);
  }
  file = open(fixture, O_RDONLY); assert(file >= 0); char byte;
  assert(read(file, &byte, 1) == 1 && byte == 'A'); assert(close(file) == 0);
  assert(unlink(fixture) == 0); assert(rmdir(canonical) == 0); free(canonical);
  puts("Observation effect work cleanup passed for 1000 successful and failed completions");
  return 0;
}
