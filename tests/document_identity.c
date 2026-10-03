// POSIX path identity experiment. The Bend core does not resolve paths.
#define _XOPEN_SOURCE 700
#if defined(__APPLE__)
#define _DARWIN_C_SOURCE
#endif
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

int main(int argc, char** argv) {
  if (argc != 2) return 1;
  char* path = realpath(argv[1], NULL);
  if (!path) { perror("resolve document identity"); return 1; }
  int fd = open(path, O_RDONLY | O_NONBLOCK | O_NOFOLLOW);
  struct stat info;
  if (fd < 0 || fstat(fd, &info) != 0 || !S_ISREG(info.st_mode)) {
    fprintf(stderr, "document identity requires a readable regular file\n");
    if (fd >= 0) close(fd);
    free(path);
    return 1;
  }
  if (close(fd) != 0) { free(path); return 1; }
  // PATH1: plus canonical path bytes. Hex preserves non-UTF-8 path bytes.
  fputs("50415448313a", stdout);
  for (const unsigned char* p = (const unsigned char*)path; *p; ++p)
    printf("%02x", *p);
  putchar('\n');
  free(path);
  return fflush(stdout) == 0 && !ferror(stdout) ? 0 : 1;
}
