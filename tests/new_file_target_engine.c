#define _GNU_SOURCE
#define _DARWIN_C_SOURCE
static void replace_parent(const char* path);
#define MARKBEND_NEW_TARGET_BEFORE_CHECK(path) replace_parent(path)
#define MARKBEND_NEW_TARGET_ENGINE_ONLY
#include "../src/new_file_target.c"
#include <assert.h>
#include <dirent.h>

static int replace_enabled;
static char moved_parent[8192];
static void replace_parent(const char* path) {
  if (!replace_enabled) return;
  assert(snprintf(moved_parent, sizeof(moved_parent), "%s.old", path) < (int)sizeof(moved_parent));
  assert(rename(path, moved_parent) == 0);
  assert(mkdir(path, 0700) == 0);
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
static void rejected(const char* path) {
  MarkBendNewTarget result;
  assert(new_target_resolve(path, strlen(path), &result) != 0);
  assert(!result.path && !result.parent_key);
}
int main(void) {
  char directory[] = "/tmp/markbend-new-target.XXXXXX";
  assert(mkdtemp(directory));
  char* canonical = realpath(directory, NULL); assert(canonical);
  char requested[8192], expected[8192], existing[8192], link_name[8192];
  snprintf(requested, sizeof(requested), "%s/中文 😀.md", directory);
  snprintf(expected, sizeof(expected), "%s/中文 😀.md", canonical);
  MarkBendNewTarget result;
  int baseline = descriptors();
  struct stat parent; assert(stat(canonical, &parent) == 0);
  char key[80]; snprintf(key, sizeof(key), "DIR1:%ju:%ju", (uintmax_t)parent.st_dev, (uintmax_t)parent.st_ino);
  for (int n = 0; n < 100; n++) {
    assert(new_target_resolve(requested, strlen(requested), &result) == 0);
    assert(!strcmp(result.path, expected) && !strcmp(result.parent_key, key));
    new_target_free(&result); assert(descriptors() == baseline);
  }
  assert(access(expected, F_OK) != 0 && errno == ENOENT);
  snprintf(existing, sizeof(existing), "%s/existing.md", directory);
  int file = open(existing, O_CREAT | O_EXCL | O_WRONLY, 0600); assert(file >= 0);
  assert(write(file, "guard", 5) == 5); assert(close(file) == 0);
  rejected(existing);
  snprintf(link_name, sizeof(link_name), "%s/link.md", directory);
  assert(symlink("missing", link_name) == 0); rejected(link_name);
  rejected(directory); rejected(""); rejected("."); rejected("..");
  snprintf(requested, sizeof(requested), "%s/missing/new.md", directory); rejected(requested);
  char nul[] = {'a', 0, 'b'};
  assert(new_target_resolve(nul, sizeof(nul), &result) == EINVAL);
  memset(requested, 'x', sizeof(requested));
  assert(new_target_resolve(requested, sizeof(requested), &result) == EINVAL);
  file = open(existing, O_RDONLY); assert(file >= 0); char guard[5];
  assert(read(file, guard, sizeof(guard)) == sizeof(guard)); assert(!memcmp(guard, "guard", 5));
  assert(close(file) == 0); assert(descriptors() == baseline);
  replace_enabled = 1;
  assert(new_target_resolve(expected, strlen(expected), &result) == ESTALE);
  assert(!result.path && !result.parent_key);
  assert(descriptors() == baseline);
  replace_enabled = 0;
  assert(rmdir(canonical) == 0); assert(rename(moved_parent, canonical) == 0);
  assert(unlink(existing) == 0); assert(unlink(link_name) == 0);
  assert(rmdir(directory) == 0); free(canonical);
  puts("New target resolution exact paths, parent identity, rejected targets, and descriptor cleanup passed");
  return 0;
}
