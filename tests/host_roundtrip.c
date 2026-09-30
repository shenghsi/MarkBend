#include "linux_host_syntax.c"
#include <assert.h>

Term io_hand(intptr_t value) { return (Term)value; }
intptr_t io_hand_v(Term value) { return (intptr_t)value; }
char* io_cstr(Env environment, Term value, u64* length) {
  const char* text = (const char*)(uintptr_t)value;
  *length = strlen(text);
  return strdup(text);
}
Term io_box(Env e, u64 c, Term value) { return value; }
Term io_str(Env e, const char* text, u64 length) { return 0; }
Term io_tup(Env e, Term first, Term second) { return first; }
Term term_pak(u64 constructor, u64 location) { return 0; }
void io_eff(u64 effect, Effect run, int need) {}
void err_fail(const char* message) { abort(); }

int main(void) {
  Env e = {0};
  IoWork work = {0};
  Term args[3] = {(Term)(uintptr_t)"initial", 0, 0};
  Term handle = live_paragraph_open_run(e, args, &work);
  args[0] = handle;
  args[1] = (Term)(uintptr_t)"中文 **one**\n**two**";
  live_paragraph_set_run(e, args, &work);
  const char* texts[] = {"中文 ", "one", "\n", "two"};
  for (int i = 0; i < 4; i++) {
    args[1] = (Term)(uintptr_t)texts[i];
    args[2] = i % 2;
    live_paragraph_append_run(e, args, &work);
  }
  MarkBendLiveState* state = (void*)(uintptr_t)handle;
  assert(strcmp(state->text, "中文 **one**\n**two**") == 0);
  assert(strcmp(state->preview, "中文 \033[1mone\033[0m\n\033[1mtwo\033[0m") == 0);
  args[1] = (Term)(uintptr_t)"unfinished **";
  live_paragraph_set_run(e, args, &work);
  args[2] = 0;
  live_paragraph_append_run(e, args, &work);
  assert(strcmp(state->preview, "unfinished **") == 0);
  live_paragraph_close_run(e, args, &work);
  puts("POSIX host round trip passed");
}
