#include <errno.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if !defined(_WIN32)
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#endif

typedef struct { char* path; char* parent_key; } MarkBendNewTarget;
static void new_target_free(MarkBendNewTarget* value) {
  free(value->path); free(value->parent_key);
  value->path = NULL; value->parent_key = NULL;
}

// Resolution is read-only. The publication service must reacquire the parent
// and compare its identity. This result is not a held-directory capability.
static int new_target_resolve(const char* input, size_t length, MarkBendNewTarget* output) {
  memset(output, 0, sizeof(*output));
#if defined(_WIN32)
  (void)input; (void)length; return ENOSYS;
#else
  int result = EINVAL, parent = -1;
  char* copy = NULL; char* canonical = NULL;
  if (!length || length > 4096 || memchr(input, 0, length)) return EINVAL;
  copy = malloc(length + 1);
  if (!copy) return ENOMEM;
  memcpy(copy, input, length); copy[length] = 0;
  char* slash = strrchr(copy, '/');
  const char* leaf = slash ? slash + 1 : copy;
  if (!*leaf || !strcmp(leaf, ".") || !strcmp(leaf, "..")) goto done;
  char* directory;
  if (!slash) directory = ".";
  else if (slash == copy) directory = "/";
  else { *slash = 0; directory = copy; }
  canonical = realpath(directory, NULL);
  if (!canonical) { result = errno; goto done; }
  parent = open(canonical, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
  if (parent < 0) { result = errno; goto done; }
  struct stat held, named, target;
  if (fstat(parent, &held)) { result = errno; goto done; }
  if (!S_ISDIR(held.st_mode)) goto done;
  if (fstatat(parent, leaf, &target, AT_SYMLINK_NOFOLLOW) == 0) { result = EEXIST; goto done; }
  if (errno != ENOENT) { result = errno; goto done; }
#ifdef MARKBEND_NEW_TARGET_BEFORE_CHECK
  MARKBEND_NEW_TARGET_BEFORE_CHECK(canonical);
#endif
  if (lstat(canonical, &named)) { result = errno; goto done; }
  if (!S_ISDIR(named.st_mode) || named.st_dev != held.st_dev || named.st_ino != held.st_ino) {
    result = ESTALE; goto done;
  }
  size_t parent_size = strlen(canonical), leaf_size = strlen(leaf);
  size_t separator = strcmp(canonical, "/") ? 1 : 0;
  if (parent_size + separator + leaf_size > 4096) { result = ENAMETOOLONG; goto done; }
  output->path = malloc(parent_size + separator + leaf_size + 1);
  if (!output->path) { result = ENOMEM; goto done; }
  memcpy(output->path, canonical, parent_size);
  if (separator) output->path[parent_size] = '/';
  memcpy(output->path + parent_size + separator, leaf, leaf_size + 1);
  char key[80];
  int size = snprintf(key, sizeof(key), "DIR1:%ju:%ju", (uintmax_t)held.st_dev, (uintmax_t)held.st_ino);
  if (size < 0 || (size_t)size >= sizeof(key)) { result = EOVERFLOW; goto done; }
  output->parent_key = strdup(key);
  if (!output->parent_key) { result = ENOMEM; goto done; }
  result = 0;
done:
  if (parent >= 0 && close(parent) && !result) result = errno;
  free(copy); free(canonical);
  if (result) new_target_free(output);
  return result;
#endif
}

#ifndef MARKBEND_NEW_TARGET_ENGINE_ONLY
typedef struct { char* requested; size_t length; MarkBendNewTarget target; } MarkBendNewTargetWork;
static void new_target_call(IoWork* work) {
  MarkBendNewTargetWork* value = (void*)work->data;
  work->code = new_target_resolve(value->requested, value->length, &value->target);
}
static Term new_target_bytes(Env e, const char* bytes, size_t length, Term tail) {
  while (length) tail = io_node(e, CID(Con), (Term)(unsigned char)bytes[--length], tail);
  return tail;
}
static Term new_target_pack(Env e, IoWork* work) {
  MarkBendNewTargetWork* value = (void*)work->data;
  Term result;
  if (work->code) result = io_fail(e, work->code, NULL);
  else {
    Term path = new_target_bytes(e, value->target.path, strlen(value->target.path), term_pak(CID(Nil), 0));
    Term key = new_target_bytes(e, value->target.path, strlen(value->target.path), term_pak(CID(Nil), 0));
    key = new_target_bytes(e, "PATH1:", 6, key);
    Term parent = new_target_bytes(e, value->target.parent_key, strlen(value->target.parent_key), term_pak(CID(Nil), 0));
    result = io_done(e, io_tup(e, path, io_tup(e, key, parent)));
  }
  new_target_free(&value->target); free(value->requested); free(value); work->data = NULL;
  return result;
}
static Term new_target_run(Env e, Term* fields, IoWork* work) {
  MarkBendNewTargetWork* value = calloc(1, sizeof(*value));
  if (!value) return io_fail(e, ENOMEM, NULL);
  u64 length = 0;
  value->requested = io_cstr(e, fields[0], &length); value->length = length;
  if (!value->requested) { free(value); return io_fail(e, ENOMEM, NULL); }
  work->data = (char*)value; work->code = 0;
  return io_work(work, new_target_call, new_target_pack);
}
static void __attribute__((constructor)) new_target_use(void) {
  io_eff(CID(resolve_raw), new_target_run, 0);
}
#endif
