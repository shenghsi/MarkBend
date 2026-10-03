#define _GNU_SOURCE
#define _DARWIN_C_SOURCE
static int before_publication(int parent, const char* leaf, const char* temporary, const char* path);
static int after_publication(int parent, const char* leaf);
#define MARKBEND_NEW_BEFORE_PUBLICATION(parent, leaf, temporary, path) before_publication(parent, leaf, temporary, path)
#define MARKBEND_NEW_AFTER_PUBLICATION(parent, leaf) after_publication(parent, leaf)
#define MARKBEND_NEW_PUBLISH_ENGINE_ONLY
#define MARKBEND_NEW_TARGET_ENGINE_ONLY
#include "../src/new_file_publish.c"
#include "../src/new_file_target.c"
#include <assert.h>
#include <dirent.h>

static int mode;
static char replaced_temporary[64];
static char moved_parent[8192];
static char original_parent[8192];
static void replace_parent(const char* path) {
  if (path != original_parent) strcpy(original_parent, path);
  snprintf(moved_parent, sizeof(moved_parent), "%s.old", path);
  assert(rename(path, moved_parent) == 0);
  assert(mkdir(path, 0700) == 0);
  assert(chmod(path, 0700) == 0);
}
static void other_file(int parent, const char* leaf) {
  int file = openat(parent, leaf, O_CREAT | O_EXCL | O_WRONLY, 0600); assert(file >= 0);
  assert(write(file, "other", 5) == 5); assert(fchmod(file, 0600) == 0); assert(close(file) == 0);
}
static int before_publication(int parent, const char* leaf, const char* temporary, const char* path) {
  if (mode == 6) replace_parent(path);
  if (mode == 1) return 1;
  if (mode == 3) other_file(parent, leaf);
  if (mode == 4) {
    assert(unlinkat(parent, temporary, 0) == 0); other_file(parent, temporary);
    strcpy(replaced_temporary, temporary);
  }
  return 0;
}
static int after_publication(int parent, const char* leaf) {
  if (mode == 7) replace_parent(original_parent);
  if (mode == 2) return 1;
  if (mode == 5) { assert(unlinkat(parent, leaf, 0) == 0); other_file(parent, leaf); }
  return 0;
}
static int descriptors(void) {
#if defined(__APPLE__)
  DIR* directory = opendir("/dev/fd");
#else
  DIR* directory = opendir("/proc/self/fd");
#endif
  assert(directory); int count = 0; struct dirent* entry;
  while ((entry = readdir(directory))) if (entry->d_name[0] != '.') count++;
  assert(closedir(directory) == 0); return count;
}
static void exact_file(const char* path, const unsigned char* bytes, size_t size) {
  int file = open(path, O_RDONLY | O_NOFOLLOW); assert(file >= 0);
  unsigned char actual[256]; assert(size < sizeof(actual));
  assert(read(file, actual, sizeof(actual)) == (ssize_t)size);
  assert(!memcmp(actual, bytes, size)); struct stat info;
  assert(fstat(file, &info) == 0 && (info.st_mode & 0777) == 0600);
  assert(close(file) == 0);
}
int main(void) {
  const unsigned char bytes[] = "\xef\xbb\xbf中文😀\r\ne\xcc\x81\0\n";
  const int outcomes[] = {MB_NEW_CONFIRMED, MB_NEW_OLD, MB_NEW_UNCERTAIN,
    MB_NEW_CONFLICT, MB_NEW_OLD, MB_NEW_UNCERTAIN, MB_NEW_CONFLICT, MB_NEW_UNCERTAIN};
  for (mode = 0; mode < 8; mode++) {
    char directory[] = "/tmp/markbend-publish.XXXXXX"; assert(mkdtemp(directory));
    char request[8192]; snprintf(request, sizeof(request), "%s/new.md", directory);
    MarkBendNewTarget target; assert(new_target_resolve(request, strlen(request), &target) == 0);
    char identity[8192]; snprintf(identity, sizeof(identity), "PATH1:%s", target.path);
    if (mode == 7) {
      strcpy(original_parent, target.path);
      *strrchr(original_parent, '/') = 0;
    }
    int before = descriptors(); mode_t mask = umask(0777);
    int result = new_publish_engine(target.path, (unsigned char*)identity, strlen(identity),
      (unsigned char*)target.parent_key, strlen(target.parent_key), bytes, sizeof(bytes) - 1);
    umask(mask); assert(result == outcomes[mode]); assert(descriptors() == before);
    if (mode == 6 || mode == 7) {
      assert(access(target.path, F_OK) != 0 && errno == ENOENT);
      assert(rmdir(original_parent) == 0);
      assert(rename(moved_parent, original_parent) == 0);
    }
    if (mode == 0 || mode == 2 || mode == 7) exact_file(target.path, bytes, sizeof(bytes) - 1);
    else if (mode == 3 || mode == 5) exact_file(target.path, (unsigned char*)"other", 5);
    else assert(access(target.path, F_OK) != 0 && errno == ENOENT);
    if (mode == 0) {
      assert(new_publish_engine(target.path, (unsigned char*)identity, strlen(identity),
        (unsigned char*)target.parent_key, strlen(target.parent_key), (unsigned char*)"replace", 7) == MB_NEW_CONFLICT);
      exact_file(target.path, bytes, sizeof(bytes) - 1);
    }
    if (mode == 4) {
      char other[8192]; snprintf(other, sizeof(other), "%s/%s", directory, replaced_temporary);
      exact_file(other, (unsigned char*)"other", 5); assert(unlink(other) == 0);
    }
    DIR* scan = opendir(directory); assert(scan); struct dirent* entry; int names = 0;
    while ((entry = readdir(scan))) if (strcmp(entry->d_name, ".") && strcmp(entry->d_name, "..")) {
      assert(!strcmp(entry->d_name, "new.md")); names++;
    }
    assert(closedir(scan) == 0);
    assert(names == (mode == 0 || mode == 2 || mode == 3 || mode == 5 || mode == 7 ? 1 : 0));
    if (names) assert(unlink(target.path) == 0);
    new_target_free(&target); assert(rmdir(directory) == 0);
  }
  mode = 0;
  char directory[] = "/tmp/markbend-publish-limits.XXXXXX"; assert(mkdtemp(directory));
  char request[8192]; snprintf(request, sizeof(request), "%s/new.md", directory);
  MarkBendNewTarget target; assert(new_target_resolve(request, strlen(request), &target) == 0);
  char identity[8192]; snprintf(identity, sizeof(identity), "PATH1:%s", target.path);
  int before = descriptors();
  for (int i = 0; i < 32; i++) {
    assert(new_publish_engine(target.path, (unsigned char*)"wrong", 5,
      (unsigned char*)target.parent_key, strlen(target.parent_key), bytes, sizeof(bytes)-1) == MB_NEW_CONFLICT);
    // The size check must reject this request before reading the small buffer.
    assert(new_publish_engine(target.path, (unsigned char*)identity, strlen(identity),
      (unsigned char*)"wrong", 5, bytes, sizeof(bytes)-1) == MB_NEW_CONFLICT);
    assert(new_publish_engine(target.path, (unsigned char*)identity, strlen(identity),
      (unsigned char*)target.parent_key, strlen(target.parent_key), bytes, 8388609) == MB_NEW_OLD);
    mode = 1;
    assert(new_publish_engine(target.path, (unsigned char*)identity, strlen(identity),
      (unsigned char*)target.parent_key, strlen(target.parent_key), bytes, sizeof(bytes)-1) == MB_NEW_OLD);
    mode = 0;
    assert(descriptors() == before);
    assert(access(target.path, F_OK) != 0 && errno == ENOENT);
  }
  assert(new_publish_engine(target.path, (unsigned char*)identity, strlen(identity),
    (unsigned char*)target.parent_key, strlen(target.parent_key), bytes, 0) == MB_NEW_CONFIRMED);
  exact_file(target.path, bytes, 0); assert(unlink(target.path) == 0);
  unsigned char* large = malloc(8388608); assert(large);
  for (size_t i = 0; i < 8388608; i++) large[i] = (unsigned char)(i % 251);
  assert(new_publish_engine(target.path, (unsigned char*)identity, strlen(identity),
    (unsigned char*)target.parent_key, strlen(target.parent_key), large, 8388608) == MB_NEW_CONFIRMED);
  int file = open(target.path, O_RDONLY); assert(file >= 0);
  unsigned char chunk[4096]; size_t at = 0; ssize_t got;
  while ((got = read(file, chunk, sizeof(chunk))) > 0) {
    assert(at + (size_t)got <= 8388608 && !memcmp(chunk, large + at, (size_t)got)); at += (size_t)got;
  }
  assert(got == 0 && at == 8388608); assert(close(file) == 0); free(large);
  assert(unlink(target.path) == 0);
  assert(mkdir(target.path, 0700) == 0);
  assert(new_publish_engine(target.path, (unsigned char*)identity, strlen(identity),
    (unsigned char*)target.parent_key, strlen(target.parent_key), bytes, 0) == MB_NEW_CONFLICT);
  assert(rmdir(target.path) == 0);
  assert(symlink("missing", target.path) == 0);
  assert(new_publish_engine(target.path, (unsigned char*)identity, strlen(identity),
    (unsigned char*)target.parent_key, strlen(target.parent_key), bytes, 0) == MB_NEW_CONFLICT);
  char link[32]; assert(readlink(target.path, link, sizeof(link)) == 7 && !memcmp(link, "missing", 7));
  assert(unlink(target.path) == 0); assert(descriptors() == before);
  new_target_free(&target); assert(rmdir(directory) == 0);
  puts("Exclusive new-file publication bytes, permissions, conflicts, and failure stages passed");
  return 0;
}
