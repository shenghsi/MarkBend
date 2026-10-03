#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/stat.h>
static void new_target_test_swap(const char* path) {
  const char* expected = getenv("MARKBEND_NEW_TARGET_SWAP_PARENT");
  const char* backup = getenv("MARKBEND_NEW_TARGET_SWAP_BACKUP");
  if (!expected || !backup || strcmp(expected, path)) return;
  if (rename(path, backup) || mkdir(path, 0700)) {
    perror("Target parent fixture replacement"); _Exit(91);
  }
}
#define MARKBEND_NEW_TARGET_BEFORE_CHECK(path) new_target_test_swap(path)
