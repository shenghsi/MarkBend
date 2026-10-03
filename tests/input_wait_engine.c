#define MARKBEND_INPUT_WAIT_ENGINE_ONLY
#include "../src/input_wait.c"
#include <assert.h>
#include <dirent.h>
#include <pthread.h>

static int descriptor_count(void) {
#if defined(__APPLE__)
  const char* root = "/dev/fd";
#else
  const char* root = "/proc/self/fd";
#endif
  DIR* directory = opendir(root);
  assert(directory);
  int count = 0;
  struct dirent* entry;
  while ((entry = readdir(directory))) if (entry->d_name[0] != '.') count++;
  assert(closedir(directory) == 0);
  return count;
}

typedef struct { int control, notice, mode; } Peer;
static void* respond(void* argument) {
  Peer* peer = argument;
  unsigned char challenge[20];
  size_t at = 0;
  while (at < sizeof(challenge)) {
    ssize_t n = read(peer->notice, challenge + at, sizeof(challenge) - at);
    assert(n > 0); at += (size_t)n;
  }
  if (peer->mode == 2) assert(shutdown(peer->control, SHUT_WR) == 0);
  else {
    if (peer->mode == 1) challenge[19] ^= 1;
    assert(write(peer->control, challenge, sizeof(challenge)) == sizeof(challenge));
  }
  return NULL;
}

static void completed(int mode) {
  int baseline = descriptor_count();
  int control[2], notice[2];
  assert(socketpair(AF_UNIX, SOCK_STREAM, 0, control) == 0);
  assert(socketpair(AF_UNIX, SOCK_STREAM, 0, notice) == 0);
  Peer peer = {control[1], notice[1], mode};
  pthread_t thread;
  assert(pthread_create(&thread, NULL, respond, &peer) == 0);
  assert(input_wait_engine(control[0], notice[0]) == (mode == 0 ? 0 : 4));
  assert(pthread_join(thread, NULL) == 0);
  assert(descriptor_count() == baseline + 4);
  for (int i = 0; i < 2; i++) {
    assert(close(control[i]) == 0); assert(close(notice[i]) == 0);
  }
  assert(descriptor_count() == baseline);
}

int main(void) {
  for (int n = 0; n < 32; n++) for (int mode = 0; mode < 3; mode++) completed(mode);
  int control[2], notice[2];
  assert(socketpair(AF_UNIX, SOCK_STREAM, 0, control) == 0);
  assert(socketpair(AF_UNIX, SOCK_STREAM, 0, notice) == 0);
  assert(control[0] >= 3 && notice[0] >= 3);
  unsigned char stale = 1;
  assert(write(control[1], &stale, 1) == 1);
  int baseline = descriptor_count();
  for (int n = 0; n < 100; n++) {
    assert(input_wait_engine(control[0], notice[0]) == 4);
    assert(fcntl(control[0], F_GETFD) >= 0);
    assert(fcntl(notice[0], F_GETFD) >= 0);
    assert(descriptor_count() == baseline);
  }
  assert(read(control[0], &stale, 1) == 1);
  assert(close(notice[1]) == 0);
  assert(input_wait_engine(control[0], notice[0]) == 4);
  assert(input_wait_engine(control[0], control[0]) == 4);
  assert(input_wait_engine(0, notice[0]) == 4);
  assert(close(control[0]) == 0);
  assert(close(control[1]) == 0);
  assert(close(notice[0]) == 0);
  return 0;
}
