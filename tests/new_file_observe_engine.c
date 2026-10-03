#define _GNU_SOURCE
#define _DARWIN_C_SOURCE
#define MARKBEND_OBSERVE_ENGINE_ONLY
#include <unistd.h>
#include <errno.h>
static int read_mode, read_calls;
static int sync_mode, sync_calls, close_mode, close_calls;
static int observed_sync(int file) {
  sync_calls++;
  if (sync_mode && sync_calls == sync_mode) { errno = EIO; return -1; }
  return fsync(file);
}
static int observed_close(int file) {
  int result = close(file); close_calls++;
  if (!result && close_mode && close_calls == close_mode) { errno = EIO; return -1; }
  return result;
}
static ssize_t observed_read(int file, void* buffer, size_t count, off_t offset) {
  read_calls++;
  if (read_mode == 2 && read_calls == 1) { errno = EINTR; return -1; }
  if (read_mode == 3) { errno = EBADF; return -1; }
  if (read_mode == 1 && count > 2048) count = 2048;
  return pread(file, buffer, count, offset);
}
#define pread observed_read
#define fsync observed_sync
#define close observed_close
static int observe_hook(int parent, int file, const char* leaf, const char* directory);
#define MARKBEND_OBSERVE_BEFORE_SYNC(parent, file, leaf, directory) observe_hook(parent, file, leaf, directory)
#include "../src/new_file_observe.c"
#undef pread
#undef fsync
#undef close
#include <assert.h>
#include <dirent.h>
static int mode;
static char moved[8192];
static char original[8192];
static int descriptors(void) {
#if defined(__APPLE__)
  DIR* scan = opendir("/dev/fd");
#else
  DIR* scan = opendir("/proc/self/fd");
#endif
  assert(scan); int count = 0; struct dirent* entry;
  while ((entry = readdir(scan))) if (entry->d_name[0] != '.') count++;
  assert(closedir(scan) == 0); return count;
}
static int observe_hook(int parent, int file, const char* leaf, const char* directory) {
  (void)file;
  if (mode == 1) return 1;
  if (mode == 2) {
    int writer = openat(parent, leaf, O_WRONLY); assert(writer >= 0);
    assert(pwrite(writer, "X", 1, 0) == 1); assert(close(writer) == 0);
  }
  if (mode == 3) {
    assert(unlinkat(parent, leaf, 0) == 0);
    int replacement = openat(parent, leaf, O_CREAT | O_EXCL | O_WRONLY, 0600); assert(replacement >= 0);
    assert(write(replacement, "replacement", 11) == 11); assert(close(replacement) == 0);
  }
  if (mode == 4) {
    strcpy(original, directory); snprintf(moved, sizeof(moved), "%s.old", directory);
    assert(rename(directory, moved) == 0); assert(mkdir(directory, 0700) == 0);
  }
  return 0;
}
int main(void) {
  char root[] = "/tmp/markbend-observe.XXXXXX"; assert(mkdtemp(root));
  char* directory = realpath(root, NULL); assert(directory);
  char path[8192], identity[8192], key[80];
  snprintf(path, sizeof(path), "%s/new.md", directory);
  snprintf(identity, sizeof(identity), "PATH1:%s", path);
  struct stat info; assert(stat(directory, &info) == 0);
  snprintf(key, sizeof(key), "DIR1:%ju:%ju", (uintmax_t)info.st_dev, (uintmax_t)info.st_ino);
  const unsigned char bytes[] = "\xef\xbb\xbf中文😀\r\n\0";
  int count = descriptors();
  for (mode = 0; mode < 5; mode++) {
    int file = open(path, O_CREAT | O_EXCL | O_WRONLY, 0600); assert(file >= 0);
    assert(write(file, bytes, sizeof(bytes)-1) == sizeof(bytes)-1); assert(close(file) == 0);
    for (int repeat = 0; repeat < (mode >= 3 ? 1 : 32); repeat++) {
      int result = new_observe_engine(path, (unsigned char*)identity, strlen(identity),
        (unsigned char*)key, strlen(key), bytes, sizeof(bytes)-1);
      assert(result == (mode == 0 ? 0 : 1));
      assert(descriptors() == count);
    }
    if (mode == 4) { assert(rmdir(original) == 0); assert(rename(moved, original) == 0); }
    file = open(path, O_RDONLY); assert(file >= 0); unsigned char actual[128];
    ssize_t size = read(file, actual, sizeof(actual)); assert(close(file) == 0);
    if (mode == 3) assert(size == 11 && !memcmp(actual, "replacement", 11));
    else {
      assert(size == sizeof(bytes)-1); assert(actual[0] == (mode == 2 ? 'X' : bytes[0]));
      assert(!memcmp(actual + 1, bytes + 1, sizeof(bytes)-2));
    }
    assert(unlink(path) == 0);
  }
  mode = 0;
  int empty = open(path, O_CREAT | O_EXCL | O_WRONLY, 0600); assert(empty >= 0); assert(close(empty) == 0);
  assert(new_observe_engine(path, (unsigned char*)identity, strlen(identity), (unsigned char*)key, strlen(key), bytes, 0) == 0);
  assert(new_observe_engine(path, (unsigned char*)"wrong", 5, (unsigned char*)key, strlen(key), bytes, 0) == 1);
  assert(new_observe_engine(path, (unsigned char*)identity, strlen(identity), (unsigned char*)"wrong", 5, bytes, 0) == 1);
  assert(unlink(path) == 0);
  unsigned char* large = malloc(8388608); assert(large);
  for (size_t i = 0; i < 8388608; i++) large[i] = (unsigned char)(i % 251);
  int big = open(path, O_CREAT | O_EXCL | O_WRONLY, 0600); assert(big >= 0);
  size_t at = 0;
  while (at < 8388608) { ssize_t got = write(big, large + at, 8388608 - at); assert(got > 0); at += (size_t)got; }
  assert(close(big) == 0);
  assert(new_observe_engine(path, (unsigned char*)identity, strlen(identity), (unsigned char*)key, strlen(key), large, 8388608) == 0);
  for (read_mode = 1; read_mode <= 3; read_mode++) {
    read_calls = 0;
    assert(new_observe_engine(path, (unsigned char*)identity, strlen(identity), (unsigned char*)key, strlen(key), large, 8388608) == (read_mode == 3 ? 1 : 0));
    assert(descriptors() == count);
  }
  read_mode = 0;
  assert(!observe_bytes(-1, bytes, sizeof(bytes)-1));
  for (sync_mode = 1; sync_mode <= 2; sync_mode++) {
    sync_calls = 0;
    assert(new_observe_engine(path, (unsigned char*)identity, strlen(identity), (unsigned char*)key, strlen(key), large, 8388608) == 1);
    assert(descriptors() == count);
  }
  sync_mode = 0;
  for (close_mode = 1; close_mode <= 2; close_mode++) {
    close_calls = 0;
    assert(new_observe_engine(path, (unsigned char*)identity, strlen(identity), (unsigned char*)key, strlen(key), large, 8388608) == 1);
    assert(descriptors() == count);
  }
  close_mode = 0;
  assert(new_observe_engine(path, (unsigned char*)identity, strlen(identity), (unsigned char*)key, strlen(key), large, 8388608) == 0);
  // Reject the length before reading beyond the small expected buffer.
  assert(new_observe_engine(path, (unsigned char*)identity, strlen(identity), (unsigned char*)key, strlen(key), bytes, 8388609) == 1);
  assert(unlink(path) == 0); free(large); assert(descriptors() == count);
  assert(new_observe_engine(path, (unsigned char*)identity, strlen(identity), (unsigned char*)key, strlen(key), bytes, 0) == 1);
  assert(rmdir(directory) == 0); free(directory);
  puts("New-file observation exact bytes, repeated reads, mismatch, and failed sync-stage checks passed");
  return 0;
}
