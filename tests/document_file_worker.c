#define _GNU_SOURCE
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <dirent.h>
#include <unistd.h>

typedef uint64_t u64;
typedef uint64_t Term;
typedef struct { int unused; } Env;
typedef struct IoWork { char* data; int code; } IoWork;
typedef Term (*Effect)(Env, Term*, IoWork*);
#define CID(name) 1
static Term io_node(Env e, u64 id, Term a, Term b) { (void)e; (void)id; (void)a; (void)b; return 0; }
static Term term_pak(u64 id, u64 at) { (void)id; (void)at; return 0; }
static Term io_tup(Env e, Term a, Term b) { (void)e; (void)a; (void)b; return 0; }
static Term io_done(Env e, Term value) { (void)e; (void)value; return 0; }
static Term io_fail(Env e, int code, const char* text) { (void)e; (void)text; return (Term)code; }
static char* io_cstr(Env e, Term value, u64* length) {
  (void)e; const char* text = (const char*)(uintptr_t)value;
  *length = strlen(text); return strdup(text);
}
static Term io_work(IoWork* w, void (*call)(IoWork*), Term (*pack)(Env, IoWork*)) {
  call(w); return pack((Env){0}, w);
}
static void io_eff(u64 id, Effect run, int need) { (void)id; (void)run; (void)need; }

static int replace_before_check;
static char replacement[4096];
static void before_check(const char* path) {
  if (replace_before_check) assert(rename(replacement, path) == 0);
}
#define MARKBEND_DOCUMENT_FILE_BEFORE_CHECK(path) before_check(path)
#include "../src/document_file.c"

static int descriptors(void) {
  int count = 0;
  DIR* listing = opendir("/dev/fd");
  assert(listing);
  int own = dirfd(listing);
  struct dirent* entry;
  while ((entry = readdir(listing))) {
    char* end = NULL;
    long fd = strtol(entry->d_name, &end, 10);
    if (end != entry->d_name && !*end && fd != own) count++;
  }
  assert(closedir(listing) == 0);
  return count;
}
static void write_fixture(const char* path, const unsigned char* bytes, size_t size) {
  int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0600);
  assert(fd >= 0);
  assert(write(fd, bytes, size) == (ssize_t)size);
  assert(close(fd) == 0);
}
static void exact_file(const char* path, const unsigned char* bytes, size_t size) {
  unsigned char actual[16];
  int fd = open(path, O_RDONLY);
  assert(fd >= 0 && size < sizeof(actual));
  assert(read(fd, actual, sizeof(actual)) == (ssize_t)size);
  assert(memcmp(actual, bytes, size) == 0);
  assert(close(fd) == 0);
}
static void checked(const char* path, int expected, const unsigned char* bytes, size_t size) {
  int before = descriptors();
  MarkBendFileRead* data = calloc(1, sizeof(*data));
  assert(data);
  data->requested = strdup(path);
  assert(data->requested);
  IoWork work = { (char*)data, 0 };
  document_file_read_call(&work);
  assert(work.code == expected);
  assert(descriptors() == before);
  if (bytes) {
    assert(data->length == size);
    assert(memcmp(data->bytes, bytes, size) == 0);
  }
  assert(document_file_read_pack((Env){0}, &work) == (Term)expected);
  assert(work.data == NULL && descriptors() == before);
}
int main(void) {
  char root[] = "/tmp/markbend-file-worker.XXXXXX";
  assert(mkdtemp(root));
  char file[4096], retained[4096], fifo[4096], missing[4096], over[4096];
  assert(snprintf(file, sizeof(file), "%s/document", root) > 0);
  assert(snprintf(retained, sizeof(retained), "%s/retained", root) > 0);
  assert(snprintf(replacement, sizeof(replacement), "%s/replacement", root) > 0);
  assert(snprintf(fifo, sizeof(fifo), "%s/fifo", root) > 0);
  assert(snprintf(missing, sizeof(missing), "%s/missing", root) > 0);
  assert(snprintf(over, sizeof(over), "%s/over", root) > 0);
  const unsigned char old[] = {'o', 'l', 'd', 0, 255};
  const unsigned char next[] = {'n', 'e', 'w'};
  write_fixture(file, old, sizeof(old));
  assert(link(file, retained) == 0);
  checked(file, 0, old, sizeof(old));
  write_fixture(replacement, next, sizeof(next));
  replace_before_check = 1;
  checked(file, ESTALE, old, sizeof(old));
  replace_before_check = 0;
  exact_file(retained, old, sizeof(old));
  exact_file(file, next, sizeof(next));
  assert(mkfifo(fifo, 0600) == 0);
  int fd = open(over, O_WRONLY | O_CREAT, 0600);
  assert(fd >= 0 && ftruncate(fd, 8388609) == 0 && close(fd) == 0);
  for (int at = 0; at < 32; at++) {
    checked(root, EINVAL, NULL, 0);
    checked(fifo, EINVAL, NULL, 0);
    checked(missing, ENOENT, NULL, 0);
    checked(over, EFBIG, NULL, 0);
  }
  assert(unlink(file) == 0 && unlink(retained) == 0);
  assert(unlink(fifo) == 0 && unlink(over) == 0 && rmdir(root) == 0);
  puts("Resolved file replacement, descriptor closure, and packing cleanup passed");
  return 0;
}
