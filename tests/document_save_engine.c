#define _GNU_SOURCE
#define _POSIX_C_SOURCE 200809L
#if defined(__APPLE__)
#define _DARWIN_C_SOURCE
#endif
#include <assert.h>
#include <errno.h>
#include <dirent.h>
#include <stdint.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

static int fail_before, fail_after, replace_temporary;
static char replaced_name[96];
static int before_replace(int directory, const char* name, const char* temporary) {
  (void)name;
  if (replace_temporary) {
    assert(!strncmp(temporary, ".markbend-save-", 15));
    assert(strlen(temporary) < sizeof(replaced_name));
    strcpy(replaced_name, temporary);
    assert(unlinkat(directory, replaced_name, 0) == 0);
    int fd = openat(directory, replaced_name, O_WRONLY | O_CREAT | O_EXCL, 0600);
    assert(fd >= 0 && write(fd, "unowned", 7) == 7 && close(fd) == 0);
  }
  return fail_before;
}
static int after_replace(int directory, const char* name) {
  (void)directory; (void)name; return fail_after;
}
#define MARKBEND_SAVE_ENGINE_ONLY
#define MARKBEND_SAVE_BEFORE_REPLACE(parent, leaf, temporary) before_replace(parent, leaf, temporary)
#define MARKBEND_SAVE_AFTER_REPLACE(parent, leaf) after_replace(parent, leaf)
#include "../src/document_save.c"

static const unsigned char old[] = {65, 13, 10, 0, 255};
static const unsigned char next[] = {239, 187, 191, 228, 184, 173, 240, 159, 152, 128, 13, 10, 0};

static void write_fixture(const char* path, const unsigned char* bytes, size_t length) {
  int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0640);
  assert(fd >= 0 && fchmod(fd, 0640) == 0);
  assert(write(fd, bytes, length) == (ssize_t)length);
  assert(close(fd) == 0);
}
static void exact(const char* path, const unsigned char* bytes, size_t length) {
  unsigned char actual[64];
  int fd = open(path, O_RDONLY);
  struct stat info;
  assert(fd >= 0 && fstat(fd, &info) == 0);
  assert((info.st_mode & 0777) == 0640);
  assert(read(fd, actual, sizeof(actual)) == (ssize_t)length);
  assert(!memcmp(actual, bytes, length));
  assert(close(fd) == 0);
}
static int entries(const char* path) {
  DIR* dir = opendir(path);
  assert(dir);
  int count = 0;
  struct dirent* entry;
  while ((entry = readdir(dir))) {
    if (strcmp(entry->d_name, ".") && strcmp(entry->d_name, "..")) count++;
  }
  assert(closedir(dir) == 0);
  return count;
}
static int save(const char* path, const unsigned char* baseline, size_t length) {
  size_t size = strlen(path) + 6;
  unsigned char* key = malloc(size + 1);
  assert(key);
  memcpy(key, "PATH1:", 6); memcpy(key + 6, path, size - 6);
  int result = document_save_engine(path, key, size, baseline, length, next, sizeof(next));
  free(key); return result;
}
int main(void) {
  char root[] = "/tmp/markbend-save-engine.XXXXXX";
  assert(mkdtemp(root));
  char* canonical = realpath(root, NULL);
  assert(canonical);
  char path[4096], alias[4096], fifo[4096], missing[4096];
  assert(snprintf(path, sizeof(path), "%s/中文 😀.md", canonical) > 0);
  assert(snprintf(alias, sizeof(alias), "%s/alias", canonical) > 0);
  assert(snprintf(fifo, sizeof(fifo), "%s/fifo", canonical) > 0);
  assert(snprintf(missing, sizeof(missing), "%s/missing", canonical) > 0);
  write_fixture(path, old, sizeof(old));
  assert(save(path, old, sizeof(old)) == MB_SAVE_CONFIRMED);
  exact(path, next, sizeof(next));
  assert(entries(root) == 1);
  assert(save(path, old, sizeof(old)) == MB_SAVE_CONFLICT);
  exact(path, next, sizeof(next));
  write_fixture(path, old, sizeof(old));
  fail_before = 1;
  int descriptors = entries("/dev/fd");
  for (int at = 0; at < 32; at++) {
    assert(save(path, old, sizeof(old)) == MB_SAVE_OLD);
    exact(path, old, sizeof(old)); assert(entries(root) == 1);
    assert(entries("/dev/fd") == descriptors);
  }
  fail_before = 0; fail_after = 1;
  assert(save(path, old, sizeof(old)) == MB_SAVE_UNCERTAIN);
  exact(path, next, sizeof(next)); assert(entries(root) == 1);
  fail_after = 0;
  write_fixture(path, old, sizeof(old));
  replace_temporary = 1;
  assert(save(path, old, sizeof(old)) == MB_SAVE_OLD);
  exact(path, old, sizeof(old)); assert(entries(root) == 2);
  char retained[4096];
  assert(snprintf(retained, sizeof(retained), "%s/%s", canonical, replaced_name) > 0);
  unsigned char replacement[8];
  int retained_fd = open(retained, O_RDONLY);
  assert(retained_fd >= 0 && read(retained_fd, replacement, sizeof(replacement)) == 7);
  assert(!memcmp(replacement, "unowned", 7) && close(retained_fd) == 0);
  assert(unlink(retained) == 0); replace_temporary = 0;
  write_fixture(path, next, sizeof(next));
  assert(symlink(path, alias) == 0 && mkfifo(fifo, 0600) == 0);
  assert(save(alias, next, sizeof(next)) == MB_SAVE_CONFLICT);
  assert(save(fifo, old, sizeof(old)) == MB_SAVE_OLD);
  assert(save(missing, old, sizeof(old)) == MB_SAVE_OLD);
  assert(save(canonical, old, sizeof(old)) == MB_SAVE_OLD);
  assert(document_save_engine(path, (const unsigned char*)"bad", 3,
    next, sizeof(next), old, sizeof(old)) == MB_SAVE_CONFLICT);
  assert(document_save_engine(path, (const unsigned char*)"bad", 3,
    next, 8388609, old, sizeof(old)) == MB_SAVE_OLD);
  exact(path, next, sizeof(next)); assert(entries(root) == 3);
  write_fixture(path, old, 0);
  assert(save(path, old, 0) == MB_SAVE_CONFIRMED);
  exact(path, next, sizeof(next));
  assert(unlink(path) == 0 && unlink(alias) == 0 && unlink(fifo) == 0);
  assert(rmdir(root) == 0); free(canonical);
  puts("Native save exact bytes, modes, conflict, and failure stages passed");
  return 0;
}
