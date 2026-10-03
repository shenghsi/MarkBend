#define main markbend_other_host_checks
#include "host_roundtrip.c"
#undef main
#include <unistd.h>

int main(void) {
  const char draft[] = "\xef\xbb\xbf中文😀\r\ne\xcc\x81\0\n";
  FILE* input = tmpfile();
  assert(input);
  assert(fwrite(draft, 1, sizeof(draft) - 1, input) == sizeof(draft) - 1);
  rewind(input);
  assert(dup2(fileno(input), STDIN_FILENO) == STDIN_FILENO);
  clearerr(stdin);
  Env env = {0}; IoWork work = {0};
  Term fields[1] = {(Term)(uintptr_t)"A"};
  fields[0] = live_paragraph_open_run(env, fields, &work);
  live_paragraph_next_run(env, fields, &work);
  MarkBendLiveState* state = (void*)(intptr_t)io_hand_v(fields[0]);
  assert(state->length == 1 && state->text[0] == 'A');
  assert(state->input_draft_length == sizeof(draft) - 1);
  assert(memcmp(state->input_draft, draft, sizeof(draft) - 1) == 0);
  live_paragraph_close_run(env, fields, &work);
  assert(fclose(input) == 0);
  return 0;
}
