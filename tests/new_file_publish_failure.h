#define _GNU_SOURCE
#define _DARWIN_C_SOURCE
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
static int markbend_publish_before(int parent, const char* leaf) {
  const char* selected = getenv("MARKBEND_PUBLISH_FAILURE");
  if (selected && !strcmp(selected, "conflict")) {
    int file = openat(parent, leaf, O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (file < 0 || write(file, "occupied", 8) != 8 || close(file)) _Exit(91);
  }
  return selected && !strcmp(selected, "old");
}
static int markbend_publish_after(int parent, const char* leaf) {
  const char* selected = getenv("MARKBEND_PUBLISH_FAILURE");
  if (!selected) return 0;
  if (!strcmp(selected, "uncertain-mismatch")) {
    int file = openat(parent, leaf, O_WRONLY | O_TRUNC);
    if (file < 0 || write(file, "other", 5) != 5 || close(file)) _Exit(91);
    return 1;
  }
  if (!strcmp(selected, "uncertain-missing")) {
    if (unlinkat(parent, leaf, 0)) _Exit(91);
    return 1;
  }
  return !strcmp(selected, "uncertain");
}
#define MARKBEND_NEW_BEFORE_PUBLICATION(parent, leaf, temporary, path) markbend_publish_before(parent, leaf)
#define MARKBEND_NEW_AFTER_PUBLICATION(parent, leaf) markbend_publish_after(parent, leaf)
