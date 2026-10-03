#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <inttypes.h>
#if !defined(_WIN32)
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

static int observe_same(const struct stat* a, const struct stat* b) {
  return S_ISREG(b->st_mode) && a->st_dev == b->st_dev && a->st_ino == b->st_ino &&
    a->st_size == b->st_size && a->st_mode == b->st_mode &&
#if defined(__APPLE__)
    a->st_mtimespec.tv_sec == b->st_mtimespec.tv_sec && a->st_mtimespec.tv_nsec == b->st_mtimespec.tv_nsec &&
    a->st_ctimespec.tv_sec == b->st_ctimespec.tv_sec && a->st_ctimespec.tv_nsec == b->st_ctimespec.tv_nsec;
#else
    a->st_mtim.tv_sec == b->st_mtim.tv_sec && a->st_mtim.tv_nsec == b->st_mtim.tv_nsec &&
    a->st_ctim.tv_sec == b->st_ctim.tv_sec && a->st_ctim.tv_nsec == b->st_ctim.tv_nsec;
#endif


}
static int observe_bytes(int file, const unsigned char* expected, size_t size) {
  unsigned char chunk[4096]; size_t at = 0;
  while (at < size) {
    size_t wanted = size - at < sizeof(chunk) ? size - at : sizeof(chunk);
    ssize_t got = pread(file, chunk, wanted, (off_t)at);
    if (got < 0 && errno == EINTR) continue;
    if (got <= 0 || memcmp(chunk, expected + at, (size_t)got)) return 0;
    at += (size_t)got;
  }
  return 1;
}
static int observe_parent(const char* path, const struct stat* held) {
  struct stat named;
  return !lstat(path, &named) && S_ISDIR(named.st_mode) &&
    named.st_dev == held->st_dev && named.st_ino == held->st_ino;
}
// This confirms a bounded observation. It cannot exclude changes after the
// final check. It opens only for reading and never publishes or removes a file.
static int new_observe_engine(const char* path, const unsigned char* identity, size_t identity_size,
  const unsigned char* parent_key, size_t parent_key_size, const unsigned char* bytes, size_t size) {
  int result = 1, parent = -1, file = -1; char* directory = NULL; char* canonical = NULL;
  size_t path_size = strlen(path); struct stat held, before, after, named;
  if (!path_size || path_size > 4096 || path[0] != '/' || size > 8388608) return 1;
  if (identity_size != path_size + 6 || memcmp(identity, "PATH1:", 6) || memcmp(identity + 6, path, path_size)) return 1;
  const char* leaf = strrchr(path, '/') + 1;
  if (!*leaf || !strcmp(leaf, ".") || !strcmp(leaf, "..")) return 1;
  directory = strdup(path); if (!directory) goto done;
  char* slash = strrchr(directory, '/'); if (slash == directory) slash[1] = 0; else *slash = 0;
  canonical = realpath(directory, NULL); if (!canonical || strcmp(canonical, directory)) goto done;
  parent = open(directory, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
  if (parent < 0 || fstat(parent, &held) || !S_ISDIR(held.st_mode)) goto done;
  char key[80]; int length = snprintf(key, sizeof(key), "DIR1:%ju:%ju", (uintmax_t)held.st_dev, (uintmax_t)held.st_ino);
  if (length < 0 || (size_t)length >= sizeof(key) || parent_key_size != (size_t)length ||
      memcmp(parent_key, key, parent_key_size) || !observe_parent(directory, &held)) goto done;
  file = openat(parent, leaf, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK);
  if (file < 0 || fstat(file, &before) || !S_ISREG(before.st_mode) ||
      before.st_size < 0 || (uintmax_t)before.st_size != size || !observe_bytes(file, bytes, size)) goto done;
#ifdef MARKBEND_OBSERVE_BEFORE_SYNC
  if (MARKBEND_OBSERVE_BEFORE_SYNC(parent, file, leaf, directory)) goto done;
#endif
  if (fsync(file) || fsync(parent)) goto done;
  if (fstat(file, &after) || !observe_same(&before, &after) || !observe_bytes(file, bytes, size)) goto done;
  if (fstat(file, &after) || !observe_same(&before, &after) || !observe_parent(directory, &held) ||
      fstatat(parent, leaf, &named, AT_SYMLINK_NOFOLLOW) || !observe_same(&before, &named)) goto done;
  result = 0;
done:
  if (file >= 0 && close(file)) result = 1;
  if (parent >= 0 && close(parent)) result = 1;
  free(directory); free(canonical); return result;
}
#else
static int new_observe_engine(const char* path, const unsigned char* identity, size_t identity_size,
  const unsigned char* parent_key, size_t parent_key_size, const unsigned char* bytes, size_t size) {
  (void)path; (void)identity; (void)identity_size; (void)parent_key; (void)parent_key_size; (void)bytes; (void)size;
  return 1;
}
#endif

#ifndef MARKBEND_OBSERVE_ENGINE_ONLY
typedef struct {
  char* path; char* identity; char* parent; char* bytes;
  u64 path_size, identity_size, parent_size, size; int result;
} MarkBendObserveWork;
static void new_observe_call(IoWork* work) {
  MarkBendObserveWork* value = (void*)work->data;
  value->result = new_observe_engine(value->path, (unsigned char*)value->identity, value->identity_size,
    (unsigned char*)value->parent, value->parent_size, (unsigned char*)value->bytes, value->size);
}
static Term new_observe_pack(Env e, IoWork* work) {
  (void)e; MarkBendObserveWork* value = (void*)work->data; Term result = value->result;
  free(value->path); free(value->identity); free(value->parent); free(value->bytes);
  free(value); work->data = NULL; return result;
}
static Term new_observe_run(Env e, Term* fields, IoWork* work) {
  MarkBendObserveWork* value = calloc(1, sizeof(*value)); if (!value) return 1;
  value->result = 1;
  value->path = io_cstr(e, fields[0], &value->path_size);
  value->identity = io_cbuf(e, fields[1], &value->identity_size, CID(Con));
  value->parent = io_cbuf(e, fields[2], &value->parent_size, CID(Con));
  value->bytes = io_cbuf(e, fields[3], &value->size, CID(Con));
  work->data = (char*)value;
  if (!value->path || !value->identity || !value->parent || !value->bytes ||
      memchr(value->path, 0, value->path_size)) return new_observe_pack(e, work);
  return io_work(work, new_observe_call, new_observe_pack);
}
static void __attribute__((constructor)) new_observe_use(void) {
  io_eff(CID(observe_raw), new_observe_run, 0);
}
#endif
