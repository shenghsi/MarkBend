// POSIX boundary experiment. No Markdown semantics belong in this host code.
#define _POSIX_C_SOURCE 200809L
#if defined(__APPLE__)
#define _DARWIN_C_SOURCE
#endif
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

static const unsigned char old_bytes[] = {239,187,191,65,13,10,0,255};
static const unsigned char new_bytes[] = {239,187,191,66,13,10,240,159,152,128,0,195,40};

static void require(int ok, const char* message) {
  if (!ok) { fprintf(stderr, "%s: %s\n", message, strerror(errno)); exit(1); }
}

static void write_all(int fd, const unsigned char* bytes, size_t length) {
  while (length) {
    ssize_t written = write(fd, bytes, length);
    if (written < 0 && errno == EINTR) continue;
    require(written > 0, "write bytes");
    bytes += written; length -= (size_t)written;
  }
}

static void exact(int directory, const char* name, const unsigned char* bytes, size_t length) {
  int fd = openat(directory, name, O_RDONLY);
  require(fd >= 0, "open saved file");
  unsigned char actual[64];
  size_t count = 0;
  for (;;) {
    ssize_t got = read(fd, actual + count, sizeof(actual) - count);
    if (got < 0 && errno == EINTR) continue;
    require(got >= 0, "read saved file");
    if (!got) break;
    count += (size_t)got;
    require(count < sizeof(actual), "saved file exceeds fixture size");
  }
  require(close(fd) == 0, "close saved file");
  require(count == length && memcmp(actual, bytes, length) == 0, "saved bytes differ");
}

static void replace(int directory, unsigned stop, const unsigned char* bytes, size_t length) {
  struct stat original;
  require(fstatat(directory, "document", &original, AT_SYMLINK_NOFOLLOW) == 0,
    "read original file mode");
  require(S_ISREG(original.st_mode), "replacement target must be a regular file");
  int fd = openat(directory, "pending", O_WRONLY | O_CREAT | O_EXCL, 0600);
  require(fd >= 0, "create sibling temporary file");
  if (stop == 0) _exit(70);
  size_t first = length < 5 ? length : 5;
  write_all(fd, bytes, first);
  if (stop == 1) _exit(71);
  write_all(fd, bytes + first, length - first);
  if (stop == 2) _exit(72);
  require(fchmod(fd, original.st_mode & 0777) == 0, "retain saved file access mode");
  require(fsync(fd) == 0, "sync temporary file");
  require(close(fd) == 0, "close temporary file");
  if (stop == 3) _exit(73);
  require(renameat(directory, "pending", directory, "document") == 0, "replace saved file");
  if (stop == 4) _exit(74);
  require(fsync(directory) == 0, "sync parent directory");
  _exit(0);
}

static void rejected_replace(int directory) {
  pid_t child = fork();
  require(child >= 0, "start rejected save child");
  if (!child) {
    int quiet = open("/dev/null", O_WRONLY);
    require(quiet >= 0 && dup2(quiet, STDERR_FILENO) >= 0, "redirect expected rejection");
    require(close(quiet) == 0, "close rejection output");
    replace(directory, 5, old_bytes, sizeof(old_bytes));
  }
  int status;
  require(waitpid(child, &status, 0) == child, "wait for rejected save");
  require(WIFEXITED(status) && WEXITSTATUS(status) == 1, "unsafe save target was accepted");
}

int main(int argc, char** argv) {
  if (argc == 3 && strcmp(argv[1], "--sync") == 0) {
    int directory = open(argv[2], O_RDONLY | O_DIRECTORY);
    require(directory >= 0, "open reconciliation directory");
    int file = openat(directory, "document", O_RDONLY | O_NOFOLLOW);
    require(file >= 0, "open reconciliation file");
    struct stat info;
    require(fstat(file, &info) == 0 && S_ISREG(info.st_mode), "reconciliation needs a regular file");
    require(fsync(file) == 0 && close(file) == 0, "sync reconciliation file");
    require(fsync(directory) == 0 && close(directory) == 0, "sync reconciliation directory");
    return 0;
  }
  if ((argc == 3 && strcmp(argv[1], "--save") == 0) ||
      (argc == 4 && strcmp(argv[1], "--save-stop") == 0)) {
    unsigned stop = 5;
    if (argc == 4) {
      require(strlen(argv[3]) == 1 && argv[3][0] >= '0' && argv[3][0] <= '4', "invalid save stop");
      stop = (unsigned)(argv[3][0] - '0');
    }
    int directory = open(argv[2], O_RDONLY | O_DIRECTORY);
    require(directory >= 0, "open save directory");
    /* Three one-MiB snapshots need six MiB in the hexadecimal journal. */
    size_t capacity = 8 * 1024 * 1024 + 1, length = 0;
    unsigned char* bytes = malloc(capacity);
    require(bytes != NULL, "allocate save input");
    for (;;) {
      ssize_t count = read(STDIN_FILENO, bytes + length, capacity - length);
      if (count < 0 && errno == EINTR) continue;
      require(count >= 0, "read save input");
      if (!count) break;
      length += (size_t)count;
      require(length < capacity, "save input exceeds experiment limit");
    }
    replace(directory, stop, bytes, length);
  }
  require(argc == 2, "supply an isolated test directory");
  int directory = open(argv[1], O_RDONLY | O_DIRECTORY);
  require(directory >= 0, "open test directory");
  const mode_t modes[] = {0600, 0640, 0644};
  for (unsigned mode = 0; mode < 3; mode++) {
  for (unsigned stop = 0; stop < 6; stop++) {
    int fd = openat(directory, "document", O_WRONLY | O_CREAT | O_TRUNC, 0600);
    require(fd >= 0, "create old document");
    require(fchmod(fd, modes[mode]) == 0, "set original file mode");
    write_all(fd, old_bytes, sizeof(old_bytes));
    require(fsync(fd) == 0 && close(fd) == 0, "sync old document");
    require(fsync(directory) == 0, "sync old directory entry");
    pid_t child = fork();
    require(child >= 0, "start save child");
    if (!child) replace(directory, stop, new_bytes, sizeof(new_bytes));
    int status;
    require(waitpid(child, &status, 0) == child, "wait for save child");
    require(WIFEXITED(status) && WEXITSTATUS(status) == (stop < 5 ? 70 + stop : 0), "unexpected child result");
    exact(directory, "document", stop < 4 ? old_bytes : new_bytes,
      stop < 4 ? sizeof(old_bytes) : sizeof(new_bytes));
    struct stat saved;
    require(fstatat(directory, "document", &saved, AT_SYMLINK_NOFOLLOW) == 0,
      "read saved file mode");
    require((saved.st_mode & 0777) == modes[mode], "replacement changed file access mode");
    if (stop < 4) require(unlinkat(directory, "pending", 0) == 0, "remove interrupted temporary file");
  }
  }
  require(mkdirat(directory, "blocked", 0700) == 0, "create incompatible replacement target");
  int pending = openat(directory, "pending", O_WRONLY | O_CREAT | O_EXCL, 0600);
  require(pending >= 0, "create failed-save temporary file");
  write_all(pending, old_bytes, sizeof(old_bytes));
  require(fsync(pending) == 0 && close(pending) == 0, "sync failed-save bytes");
  require(renameat(directory, "pending", directory, "blocked") == -1, "replacement must reject directory target");
  exact(directory, "document", new_bytes, sizeof(new_bytes));
  exact(directory, "pending", old_bytes, sizeof(old_bytes));
  rejected_replace(directory);
  exact(directory, "document", new_bytes, sizeof(new_bytes));
  exact(directory, "pending", old_bytes, sizeof(old_bytes));
  require(unlinkat(directory, "pending", 0) == 0, "remove failed-save temporary file");
  require(unlinkat(directory, "blocked", AT_REMOVEDIR) == 0, "remove incompatible target");
  require(renameat(directory, "document", directory, "original") == 0, "retain original target");
  require(symlinkat("original", directory, "document") == 0, "create symbolic-link target");
  rejected_replace(directory);
  struct stat target;
  require(fstatat(directory, "document", &target, AT_SYMLINK_NOFOLLOW) == 0 && S_ISLNK(target.st_mode),
    "rejected save changed symbolic link");
  exact(directory, "original", new_bytes, sizeof(new_bytes));
  require(unlinkat(directory, "document", 0) == 0, "remove test symbolic link");
  require(mkdirat(directory, "document", 0700) == 0, "create directory save target");
  rejected_replace(directory);
  require(fstatat(directory, "document", &target, AT_SYMLINK_NOFOLLOW) == 0 && S_ISDIR(target.st_mode),
    "rejected save changed directory");
  exact(directory, "original", new_bytes, sizeof(new_bytes));
  errno = 0;
  require(fstatat(directory, "pending", &target, AT_SYMLINK_NOFOLLOW) == -1 && errno == ENOENT,
    "unsafe target created a temporary file");
  require(unlinkat(directory, "document", AT_REMOVEDIR) == 0, "remove test directory target");
  require(renameat(directory, "original", directory, "document") == 0, "restore regular test target");
  require(close(directory) == 0, "close test directory");
  puts("Atomic replacement process-exit check passed");
  return 0;
}
