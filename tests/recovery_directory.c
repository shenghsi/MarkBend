// Read-only POSIX recovery directory effects. Record validation belongs in Bend.
#define _POSIX_C_SOURCE 200809L
#if defined(__APPLE__)
#define _DARWIN_C_SOURCE
#endif
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static int nibble(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  return -1;
}

static int name_bytes(const char* text, char name[256]) {
  size_t length = strlen(text);
  if (!length || length > 510 || length % 2) return 0;
  for (size_t i = 0; i < length / 2; ++i) {
    int high = nibble(text[2*i]), low = nibble(text[2*i+1]);
    if (high < 0 || low < 0) return 0;
    unsigned byte = (unsigned)(high * 16 + low);
    if (!byte || byte == '/') return 0;
    name[i] = (char)byte;
  }
  name[length/2] = 0;
  return strcmp(name, ".") && strcmp(name, "..");
}

static int list(int root) {
  DIR* directory = fdopendir(root);
  if (!directory) { close(root); return 1; }
  size_t emitted = 4; // Reserve END and newline. Output is bounded and complete.
  int failed = 0;
  for (;;) {
    errno = 0;
    struct dirent* entry = readdir(directory);
    if (!entry) { failed = errno != 0; break; }
    if (!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, "..")) continue;
    size_t size = 3 + 2 * strlen(entry->d_name);
    if (size > 1048576 - emitted) { failed = 1; break; }
    emitted += size;
    struct stat info;
    int is_directory = fstatat(dirfd(directory), entry->d_name, &info,
      AT_SYMLINK_NOFOLLOW) == 0 && S_ISDIR(info.st_mode);
    printf("%c ", is_directory ? 'D' : 'X');
    for (const unsigned char* p = (const unsigned char*)entry->d_name; *p; ++p)
      printf("%02x", *p);
    putchar('\n');
  }
  if (closedir(directory) != 0) failed = 1;
  if (failed) return 1;
  fputs("END\n", stdout);
  return fflush(stdout) == 0 && !ferror(stdout) ? 0 : 1;
}

static int read_record(int root, const char* text) {
  char name[256];
  if (!name_bytes(text, name)) { close(root); return 1; }
  int directory = openat(root, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
  close(root);
  if (directory < 0) return 1;
  int file = openat(directory, "document", O_RDONLY | O_NONBLOCK | O_NOFOLLOW);
  close(directory);
  struct stat info;
  if (file < 0) return 1;
  if (fstat(file, &info) != 0 || !S_ISREG(info.st_mode)) { close(file); return 1; }
  size_t limit = 8 * 1024 * 1024;
  unsigned char* bytes = malloc(limit + 1);
  if (!bytes) { close(file); return 1; }
  size_t length = 0;
  int failed = 0;
  for (;;) {
    ssize_t count = read(file, bytes + length, limit + 1 - length);
    if (count < 0 && errno == EINTR) continue;
    if (count < 0) { failed = 1; break; }
    if (!count) break;
    length += (size_t)count;
    if (length > limit) { failed = 1; break; }
  }
  if (close(file) != 0) failed = 1;
  if (!failed && fwrite(bytes, 1, length, stdout) != length) failed = 1;
  free(bytes);
  return !failed && fflush(stdout) == 0 && !ferror(stdout) ? 0 : 1;
}

int main(int argc, char** argv) {
  if (argc != 3 && argc != 4) return 1;
  if ((argc == 3 && strcmp(argv[1], "--list")) ||
      (argc == 4 && strcmp(argv[1], "--read"))) return 1;
  int root = open(argv[2], O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
  if (root < 0) return 1;
  return argc == 3 ? list(root) : read_record(root, argv[3]);
}
