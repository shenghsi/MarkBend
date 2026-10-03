#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <inttypes.h>
#if !defined(_WIN32)
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/random.h>
#include <unistd.h>
#endif

enum { MB_NEW_CONFIRMED, MB_NEW_OLD, MB_NEW_UNCERTAIN, MB_NEW_CONFLICT, MB_NEW_UNAVAILABLE };
#if !defined(_WIN32)
static int new_publish_same(const struct stat* owned, const struct stat* named) {
  return S_ISREG(named->st_mode) && owned->st_dev == named->st_dev && owned->st_ino == named->st_ino;
}
static int new_publish_parent(const char* path, const struct stat* held) {
  struct stat named;
  return !lstat(path, &named) && S_ISDIR(named.st_mode) &&
    named.st_dev == held->st_dev && named.st_ino == held->st_ino;
}
// Exclusive link publication cannot replace an occupied leaf. Path checks do
// not exclude changes immediately after the checks or external in-place writes.
static int new_publish_engine(const char* path, const unsigned char* identity,
  size_t identity_size, const unsigned char* parent_key, size_t parent_key_size,
  const unsigned char* bytes, size_t size) {
  int result = MB_NEW_OLD, parent = -1, temporary = -1, owned_known = 0;
  char name[64] = {0}; char* directory = NULL; char* canonical = NULL;
  struct stat held, owned, named;
  size_t path_size = strlen(path);
  if (!path_size || path_size > 4096 || path[0] != '/' || size > 8388608) return MB_NEW_OLD;
  if (identity_size != path_size + 6 || memcmp(identity, "PATH1:", 6) ||
      memcmp(identity + 6, path, path_size)) return MB_NEW_CONFLICT;
  const char* leaf = strrchr(path, '/') + 1;
  if (!*leaf || !strcmp(leaf, ".") || !strcmp(leaf, "..")) return MB_NEW_OLD;
  directory = strdup(path); if (!directory) goto done;
  char* slash = strrchr(directory, '/');
  if (slash == directory) slash[1] = 0; else *slash = 0;
  canonical = realpath(directory, NULL);
  if (!canonical) goto done;
  if (strcmp(directory, canonical)) { result = MB_NEW_CONFLICT; goto done; }
  parent = open(canonical, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
  if (parent < 0 || fstat(parent, &held) || !S_ISDIR(held.st_mode)) goto done;
  char key[80];
  int key_size = snprintf(key, sizeof(key), "DIR1:%ju:%ju", (uintmax_t)held.st_dev, (uintmax_t)held.st_ino);
  if (key_size < 0 || (size_t)key_size >= sizeof(key)) goto done;
  if (parent_key_size != (size_t)key_size || memcmp(parent_key, key, parent_key_size)) {
    result = MB_NEW_CONFLICT; goto done;
  }
  if (fstatat(parent, leaf, &named, AT_SYMLINK_NOFOLLOW) == 0) { result = MB_NEW_CONFLICT; goto done; }
  if (errno != ENOENT) goto done;
  for (int attempt = 0; attempt < 64; attempt++) {
    unsigned char nonce[16]; if (getentropy(nonce, sizeof(nonce))) goto done;
    memcpy(name, ".markbend-new-", 14);
    for (int i = 0; i < 16; i++) snprintf(name + 14 + i * 2, 3, "%02x", nonce[i]);
    temporary = openat(parent, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (temporary >= 0) break;
    name[0] = 0; if (errno != EEXIST) goto done;
  }
  if (temporary < 0 || fstat(temporary, &owned)) goto done;
  owned_known = 1;
  size_t at = 0;
  while (at < size) {
    ssize_t written = write(temporary, bytes + at, size - at);
    if (written < 0 && errno == EINTR) continue;
    if (written <= 0) goto done;
    at += (size_t)written;
  }
  if (fchmod(temporary, 0600) || fsync(temporary)) goto done;
#ifdef MARKBEND_NEW_BEFORE_PUBLICATION
  if (MARKBEND_NEW_BEFORE_PUBLICATION(parent, leaf, name, directory)) goto done;
#endif
  if (!new_publish_parent(directory, &held)) { result = MB_NEW_CONFLICT; goto done; }
  if (fstatat(parent, name, &named, AT_SYMLINK_NOFOLLOW) || !new_publish_same(&owned, &named)) goto done;
  if (linkat(parent, name, parent, leaf, 0)) {
    if (errno == EEXIST) result = MB_NEW_CONFLICT;
    goto done;
  }
  result = MB_NEW_UNCERTAIN;
#ifdef MARKBEND_NEW_AFTER_PUBLICATION
  if (MARKBEND_NEW_AFTER_PUBLICATION(parent, leaf)) goto done;
#endif
  if (fstatat(parent, leaf, &named, AT_SYMLINK_NOFOLLOW) || !new_publish_same(&owned, &named)) goto done;
  if (fstatat(parent, name, &named, AT_SYMLINK_NOFOLLOW) || !new_publish_same(&owned, &named)) goto done;
  if (unlinkat(parent, name, 0)) goto done;
  name[0] = 0;
  if (fsync(parent) || !new_publish_parent(directory, &held) ||
      fstatat(parent, leaf, &named, AT_SYMLINK_NOFOLLOW) || !new_publish_same(&owned, &named)) goto done;
  result = MB_NEW_CONFIRMED;
done:
  if (name[0] && parent >= 0 && owned_known &&
      !fstatat(parent, name, &named, AT_SYMLINK_NOFOLLOW) && new_publish_same(&owned, &named)) {
    if (unlinkat(parent, name, 0) && result == MB_NEW_CONFIRMED) result = MB_NEW_UNCERTAIN;
  }
  if (temporary >= 0 && close(temporary) && result == MB_NEW_CONFIRMED) result = MB_NEW_UNCERTAIN;
  if (parent >= 0 && close(parent) && result == MB_NEW_CONFIRMED) result = MB_NEW_UNCERTAIN;
  free(directory); free(canonical); return result;
}
#else
static int new_publish_engine(const char* path, const unsigned char* identity,
  size_t identity_size, const unsigned char* parent_key, size_t parent_key_size,
  const unsigned char* bytes, size_t size) {
  (void)path; (void)identity; (void)identity_size; (void)parent_key; (void)parent_key_size;
  (void)bytes; (void)size; return MB_NEW_UNAVAILABLE;
}
#endif

#ifndef MARKBEND_NEW_PUBLISH_ENGINE_ONLY
typedef struct {
  char* path; char* identity; char* parent_key; char* bytes;
  u64 path_size, identity_size, parent_key_size, size; int result;
} MarkBendNewPublishWork;
static void new_publish_call(IoWork* work) {
  MarkBendNewPublishWork* value = (void*)work->data;
  value->result = new_publish_engine(value->path, (unsigned char*)value->identity,
    value->identity_size, (unsigned char*)value->parent_key, value->parent_key_size,
    (unsigned char*)value->bytes, value->size);
}
static Term new_publish_pack(Env e, IoWork* work) {
  (void)e; MarkBendNewPublishWork* value = (void*)work->data; Term result = value->result;
  free(value->path); free(value->identity); free(value->parent_key); free(value->bytes);
  free(value); work->data = NULL; return result;
}
static Term new_publish_run(Env e, Term* fields, IoWork* work) {
  MarkBendNewPublishWork* value = calloc(1, sizeof(*value));
  if (!value) return MB_NEW_OLD;
  value->result = MB_NEW_OLD;
  value->path = io_cstr(e, fields[0], &value->path_size);
  value->identity = io_cbuf(e, fields[1], &value->identity_size, CID(Con));
  value->parent_key = io_cbuf(e, fields[2], &value->parent_key_size, CID(Con));
  value->bytes = io_cbuf(e, fields[3], &value->size, CID(Con));
  work->data = (char*)value;
  if (!value->path || !value->identity || !value->parent_key || !value->bytes ||
      memchr(value->path, 0, value->path_size)) return new_publish_pack(e, work);
  return io_work(work, new_publish_call, new_publish_pack);
}
static void __attribute__((constructor)) new_publish_use(void) {
  io_eff(CID(publish_raw), new_publish_run, 0);
}
#endif
