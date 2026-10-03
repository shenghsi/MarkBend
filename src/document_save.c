#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#if !defined(_WIN32)
#include <fcntl.h>
#include <stdatomic.h>
#include <sys/stat.h>
#include <unistd.h>
#endif

enum { MB_SAVE_CONFIRMED, MB_SAVE_OLD, MB_SAVE_UNCERTAIN,
  MB_SAVE_CONFLICT, MB_SAVE_UNAVAILABLE };

/* This checks a baseline before rename, not atomic compare-and-replace. */
#if !defined(_WIN32)
static atomic_uint document_save_sequence;

static int document_save_same_file(const struct stat* a, const struct stat* b) {
  return S_ISREG(b->st_mode) && a->st_dev == b->st_dev && a->st_ino == b->st_ino;
}

static int document_save_compare(int fd, const unsigned char* expected, size_t size) {
  unsigned char block[4096];
  size_t at = 0;
  for (;;) {
    ssize_t n = read(fd, block, sizeof(block));
    if (n < 0 && errno == EINTR) continue;
    if (n < 0) return -1;
    if (!n) return at == size;
    if ((size_t)n > size - at || memcmp(block, expected + at, (size_t)n)) return 0;
    at += (size_t)n;
  }
}

static int document_save_engine(const char* path, const unsigned char* identity,
  size_t identity_size, const unsigned char* baseline, size_t baseline_size,
  const unsigned char* bytes, size_t size) {
  int result = MB_SAVE_OLD, parent = -1, original = -1, temporary = -1;
  char name[96] = {0};
  char* resolved = NULL;
  char* directory = NULL;
  struct stat opened, current, parent_info, parent_now;
  struct stat temporary_info;
  int temporary_known = 0;
  size_t path_size = strlen(path);
  if (!path_size || path[0] != '/' || baseline_size > 8388608 || size > 8388608)
    return MB_SAVE_OLD;
  if (identity_size != path_size + 6 || memcmp(identity, "PATH1:", 6) ||
      memcmp(identity + 6, path, path_size)) return MB_SAVE_CONFLICT;
  resolved = realpath(path, NULL);
  if (!resolved) goto done;
  if (strcmp(resolved, path)) { result = MB_SAVE_CONFLICT; goto done; }
  directory = strdup(path);
  if (!directory) goto done;
  char* slash = strrchr(directory, '/');
  const char* leaf = strrchr(path, '/') + 1;
  if (!*leaf) goto done;
  if (slash == directory) slash[1] = 0; else *slash = 0;
  parent = open(directory, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
  if (parent < 0 || fstat(parent, &parent_info)) goto done;
  original = openat(parent, leaf, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
  if (original < 0 || fstat(original, &opened)) goto done;
  if (!S_ISREG(opened.st_mode) || opened.st_size < 0 || opened.st_size > 8388608) goto done;
  int same = document_save_compare(original, baseline, baseline_size);
  if (same < 0) goto done;
  if (!same) { result = MB_SAVE_CONFLICT; goto done; }
  if (fstatat(parent, leaf, &current, AT_SYMLINK_NOFOLLOW) ||
      !document_save_same_file(&opened, &current)) { result = MB_SAVE_CONFLICT; goto done; }
  for (unsigned attempt = 0; attempt < 64; attempt++) {
    unsigned sequence = atomic_fetch_add(&document_save_sequence, 1);
    snprintf(name, sizeof(name), ".markbend-save-%ld-%u", (long)getpid(), sequence);
    temporary = openat(parent, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (temporary >= 0) break;
    name[0] = 0;
    if (errno != EEXIST) goto done;
  }
  if (temporary < 0) goto done;
  if (fstat(temporary, &temporary_info)) goto done;
  temporary_known = 1;
  size_t at = 0;
  while (at < size) {
    ssize_t n = write(temporary, bytes + at, size - at);
    if (n < 0 && errno == EINTR) continue;
    if (n <= 0) goto done;
    at += (size_t)n;
  }
  if (fchmod(temporary, opened.st_mode & 0777) || fsync(temporary)) goto done;
#ifdef MARKBEND_SAVE_BEFORE_REPLACE
  if (MARKBEND_SAVE_BEFORE_REPLACE(parent, leaf, name)) goto done;
#endif
  /* Recheck immediately before replacement. In-place writes can still race. */
  if (lseek(original, 0, SEEK_SET) < 0) goto done;
  same = document_save_compare(original, baseline, baseline_size);
  if (same < 0) goto done;
  if (!same || fstatat(parent, leaf, &current, AT_SYMLINK_NOFOLLOW) ||
      !document_save_same_file(&opened, &current) || stat(directory, &parent_now) ||
      parent_info.st_dev != parent_now.st_dev || parent_info.st_ino != parent_now.st_ino) {
    result = MB_SAVE_CONFLICT; goto done;
  }
  if (fstatat(parent, name, &current, AT_SYMLINK_NOFOLLOW) ||
      !document_save_same_file(&temporary_info, &current)) goto done;
  if (renameat(parent, name, parent, leaf)) goto done;
  name[0] = 0;
  result = MB_SAVE_UNCERTAIN;
#ifdef MARKBEND_SAVE_AFTER_REPLACE
  if (MARKBEND_SAVE_AFTER_REPLACE(parent, leaf)) goto done;
#endif
  if (fsync(parent)) goto done;
  result = MB_SAVE_CONFIRMED;
done:
  /* Never remove a detected replacement of this operation's temporary file.
     This pathname check cannot exclude another change immediately after it. */
  if (name[0] && parent >= 0 && temporary_known &&
      !fstatat(parent, name, &current, AT_SYMLINK_NOFOLLOW) &&
      document_save_same_file(&temporary_info, &current)) unlinkat(parent, name, 0);
  if (temporary >= 0 && close(temporary) && result == MB_SAVE_CONFIRMED)
    result = MB_SAVE_UNCERTAIN;
  if (original >= 0 && close(original) && result == MB_SAVE_CONFIRMED)
    result = MB_SAVE_UNCERTAIN;
  if (parent >= 0 && close(parent) && result == MB_SAVE_CONFIRMED)
    result = MB_SAVE_UNCERTAIN;
  free(resolved);
  free(directory);
  return result;
}
#else
static int document_save_engine(const char* path, const unsigned char* identity,
  size_t identity_size, const unsigned char* baseline, size_t baseline_size,
  const unsigned char* bytes, size_t size) {
  (void)path; (void)identity; (void)identity_size; (void)baseline;
  (void)baseline_size; (void)bytes; (void)size;
  return MB_SAVE_UNAVAILABLE;
}
#endif

#ifndef MARKBEND_SAVE_ENGINE_ONLY
typedef struct {
  char* path;
  char* identity;
  char* baseline;
  char* bytes;
  u64 path_size, identity_size, baseline_size, size;
  int result;
} MarkBendSaveWork;

static void document_save_call(IoWork* w) {
  MarkBendSaveWork* data = (MarkBendSaveWork*)w->data;
  data->result = document_save_engine(data->path, (unsigned char*)data->identity,
    data->identity_size, (unsigned char*)data->baseline, data->baseline_size,
    (unsigned char*)data->bytes, data->size);
}

static Term document_save_pack(Env e, IoWork* w) {
  (void)e;
  MarkBendSaveWork* data = (MarkBendSaveWork*)w->data;
  Term result = (Term)data->result;
  free(data->path); free(data->identity); free(data->baseline); free(data->bytes);
  free(data); w->data = NULL;
  return result;
}

static Term document_save_run(Env e, Term* f, IoWork* w) {
  MarkBendSaveWork* data = calloc(1, sizeof(*data));
  if (!data) return (Term)MB_SAVE_OLD;
  data->result = MB_SAVE_OLD;
  data->path = io_cstr(e, f[0], &data->path_size);
  data->identity = io_cbuf(e, f[1], &data->identity_size, CID(Con));
  data->baseline = io_cbuf(e, f[2], &data->baseline_size, CID(Con));
  data->bytes = io_cbuf(e, f[3], &data->size, CID(Con));
  w->data = (char*)data;
  if (!data->path || !data->identity || !data->baseline || !data->bytes ||
      memchr(data->path, 0, data->path_size)) return document_save_pack(e, w);
  return io_work(w, document_save_call, document_save_pack);
}

static void __attribute__((constructor)) document_save_use(void) {
  io_eff(CID(write_raw), document_save_run, 0);
}
#endif
