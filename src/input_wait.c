#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <limits.h>
#if !defined(_WIN32)
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <sys/socket.h>
#include <sys/random.h>
#include <sys/stat.h>
#include <unistd.h>

static int input_wait_ready(int fd, short events, int timeout) {
  struct pollfd descriptor = {fd, events, 0};
  int result;
  do { result = poll(&descriptor, 1, timeout); } while (result < 0 && errno == EINTR);
  return result;
}

static int input_wait_stream(int fd, struct stat* identity) {
  int kind = 0;
  socklen_t size = sizeof(kind);
  return !fstat(fd, identity) && S_ISSOCK(identity->st_mode) &&
    !getsockopt(fd, SOL_SOCKET, SO_TYPE, &kind, &size) && kind == SOCK_STREAM;
}

static int input_wait_engine(uint32_t control, uint32_t notice) {
  int reader = -1, writer = -1, result = 4;
  struct stat read_identity, write_identity;
  unsigned char challenge[20], response[20];
  if (control < 3 || notice < 3 || control == notice || control > INT_MAX || notice > INT_MAX) return 4;
  reader = fcntl((int)control, F_DUPFD_CLOEXEC, 5);
  if (reader < 0) goto done;
  writer = fcntl((int)notice, F_DUPFD_CLOEXEC, 5);
  if (writer < 0) goto done;
  if (!input_wait_stream(reader, &read_identity) || !input_wait_stream(writer, &write_identity)) goto done;
  if (!read_identity.st_ino || !write_identity.st_ino ||
      (read_identity.st_dev == write_identity.st_dev && read_identity.st_ino == write_identity.st_ino)) goto done;
  // Any queued bytes, EOF, or socket error make this wait unavailable. Do not
  // consume a stale token and restart input polling.
  if (input_wait_ready(reader, POLLIN, 0) != 0) goto done;
  memcpy(challenge, "MBW1", 4);
  if (getentropy(challenge + 4, 16)) goto done;
  size_t at = 0;
  while (at < sizeof(challenge)) {
    ssize_t sent;
#if defined(MSG_NOSIGNAL)
    sent = send(writer, challenge + at, sizeof(challenge) - at, MSG_NOSIGNAL);
#else
    // No silent process-wide signal-policy change on an unsupported host.
    goto done;
#endif
    if (sent < 0 && errno == EINTR) continue;
    if (sent < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
      if (input_wait_ready(writer, POLLOUT, -1) > 0) continue;
    }
    if (sent <= 0) goto done;
    at += (size_t)sent;
  }
  at = 0;
#ifdef MARKBEND_INPUT_WAIT_INTERRUPT_ONCE
  int interrupted = 0;
#endif
  while (at < sizeof(response)) {
    ssize_t received;
#ifdef MARKBEND_INPUT_WAIT_INTERRUPT_ONCE
    if (!interrupted) { interrupted = 1; errno = EINTR; received = -1; }
    else
#endif
    received = recv(reader, response + at, sizeof(response) - at, 0);
    if (received < 0 && errno == EINTR) continue;
    if (received < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
      if (input_wait_ready(reader, POLLIN, -1) > 0) continue;
    }
    if (received <= 0) goto done;
    at += (size_t)received;
  }
  if (!memcmp(challenge, response, sizeof(challenge))) result = 0;
done:
  if (reader >= 0 && close(reader)) result = 4;
  if (writer >= 0 && close(writer)) result = 4;
  return result;
}
#else
static int input_wait_engine(uint32_t control, uint32_t notice) {
  (void)control; (void)notice; return 4;
}
#endif

#ifndef MARKBEND_INPUT_WAIT_ENGINE_ONLY
typedef struct { uint32_t control, notice; int result; } MarkBendInputWait;
static void input_wait_call(IoWork* w) {
  MarkBendInputWait* data = (MarkBendInputWait*)w->data;
  data->result = input_wait_engine(data->control, data->notice);
}
static Term input_wait_pack(Env e, IoWork* w) {
  (void)e;
  MarkBendInputWait* data = (MarkBendInputWait*)w->data;
  Term result = (Term)data->result;
  free(data); w->data = NULL;
  return result;
}
static Term input_wait_run(Env e, Term* f, IoWork* w) {
  (void)e;
  MarkBendInputWait* data = calloc(1, sizeof(*data));
  if (!data) return (Term)4;
  data->control = (uint32_t)f[0]; data->notice = (uint32_t)f[1]; data->result = 4;
  w->data = (char*)data;
  return io_work(w, input_wait_call, input_wait_pack);
}
static void __attribute__((constructor)) input_wait_use(void) {
  io_eff(CID(wait_raw), input_wait_run, 0);
}
#endif
