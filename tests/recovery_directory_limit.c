// Create an isolated listing fixture larger than the real one-MiB host limit.
#define _POSIX_C_SOURCE 200809L
#if defined(__APPLE__)
#define _DARWIN_C_SOURCE
#endif
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

int main(int argc, char** argv) {
  if (argc != 3) return 1;
  if (!strcmp(argv[1], "create")) {
    if (mkdir(argv[2], 0700) != 0) return 1;
    int root = open(argv[2], O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
    if (root < 0) return 1;
    for (unsigned i = 0; i < 2200; ++i) {
      char name[251];
      memset(name, 'x', 250); name[250] = 0;
      char number[7];
      if (snprintf(number, sizeof(number), "%06u", i) != 6) return 1;
      memcpy(name, number, 6);
      if (mkdirat(root, name, 0700) != 0) return 1;
    }
    return close(root) == 0 ? 0 : 1;
  }
  if (strcmp(argv[1], "check")) return 1;
  int root = open(argv[2], O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
  if (root < 0) return 1;
  DIR* directory = fdopendir(root);
  if (!directory) { close(root); return 1; }
  unsigned count = 0;
  unsigned char seen[2200] = {0};
  struct dirent* entry;
  for (;;) {
    errno = 0;
    entry = readdir(directory);
    if (!entry) {
      if (errno) return 1;
      break;
    }
    if (!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, "..")) continue;
    struct stat info;
    if (strlen(entry->d_name) != 250 ||
        fstatat(dirfd(directory), entry->d_name, &info, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(info.st_mode)) return 1;
    unsigned number = 0;
    for (unsigned i = 0; i < 6; ++i) {
      if (entry->d_name[i] < '0' || entry->d_name[i] > '9') return 1;
      number = number * 10 + (unsigned)(entry->d_name[i] - '0');
    }
    if (number >= 2200 || seen[number]) return 1;
    seen[number] = 1;
    for (unsigned i = 6; i < 250; ++i)
      if (entry->d_name[i] != 'x') return 1;
    ++count;
  }
  return closedir(directory) == 0 && count == 2200 ? 0 : 1;
}
