#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

typedef struct {
  char* requested;
  char* resolved;
  unsigned char* bytes;
  size_t length;
} MarkBendFileRead;

static void document_file_read_call(IoWork* w) {
  MarkBendFileRead* data = (MarkBendFileRead*)w->data;
  int fd = -1;
  struct stat opened, current;
  data->resolved = realpath(data->requested, NULL);
  if (!data->resolved) { w->code = errno; return; }
  fd = open(data->resolved, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
  if (fd < 0) { w->code = errno; return; }
  if (fstat(fd, &opened)) { w->code = errno; goto done; }
  if (!S_ISREG(opened.st_mode)) { w->code = EINVAL; goto done; }
  if (opened.st_size > 8388608) { w->code = EFBIG; goto done; }
  data->bytes = malloc(8388609);
  if (!data->bytes) { w->code = ENOMEM; goto done; }
  for (;;) {
    size_t remaining = 8388609 - data->length;
    size_t amount = remaining < 4096 ? remaining : 4096;
    ssize_t count = read(fd, data->bytes + data->length, amount);
    if (count < 0 && errno == EINTR) continue;
    if (count < 0) { w->code = errno; goto done; }
    if (!count) break;
    data->length += (size_t)count;
    if (data->length > 8388608) { w->code = EFBIG; goto done; }
  }
#ifdef MARKBEND_DOCUMENT_FILE_BEFORE_CHECK
  MARKBEND_DOCUMENT_FILE_BEFORE_CHECK(data->resolved);
#endif
  if (lstat(data->resolved, &current)) { w->code = errno; goto done; }
  if (!S_ISREG(current.st_mode) || current.st_dev != opened.st_dev ||
      current.st_ino != opened.st_ino) { w->code = ESTALE; goto done; }
done:
  if (close(fd) && !w->code) w->code = errno;
}

static Term document_file_bytes(Env e, const unsigned char* bytes, size_t length,
  Term tail) {
  while (length) tail = io_node(e, CID(Con), (Term)bytes[--length], tail);
  return tail;
}

static Term document_file_read_pack(Env e, IoWork* w) {
  MarkBendFileRead* data = (MarkBendFileRead*)w->data;
  Term result;
  if (w->code) {
    result = io_fail(e, w->code, NULL);
  } else {
    size_t length = strlen(data->resolved);
    Term path = document_file_bytes(e, (const unsigned char*)data->resolved,
      length, term_pak(CID(Nil), 0));
    Term key = document_file_bytes(e, (const unsigned char*)data->resolved,
      length, term_pak(CID(Nil), 0));
    key = document_file_bytes(e, (const unsigned char*)"PATH1:", 6, key);
    Term bytes = document_file_bytes(e, data->bytes, data->length,
      term_pak(CID(Nil), 0));
    result = io_done(e, io_tup(e, path, io_tup(e, key, bytes)));
  }
  free(data->requested);
  free(data->resolved);
  free(data->bytes);
  free(data);
  w->data = NULL;
  return result;
}

static Term document_file_read_run(Env e, Term* f, IoWork* w) {
  u64 length = 0;
  MarkBendFileRead* data = calloc(1, sizeof(*data));
  if (!data) return io_fail(e, ENOMEM, NULL);
  data->requested = io_cstr(e, f[0], &length);
  if (!data->requested) { free(data); return io_fail(e, ENOMEM, NULL); }
  if (memchr(data->requested, 0, length)) {
    free(data->requested); free(data);
    return io_fail(e, EINVAL, "Document path contains NUL");
  }
  w->data = (char*)data;
  w->code = 0;
  return io_work(w, document_file_read_call, document_file_read_pack);
}

static void __attribute__((constructor)) document_file_use(void) {
  io_eff(CID(read_raw), document_file_read_run, 0);
}
