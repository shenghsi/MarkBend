#include "linux_host_syntax.c"
#include <assert.h>

#if defined(__APPLE__)
@interface MarkBendTestEditor : MarkBendEditor
@property(nonatomic) BOOL composing;
@end
@implementation MarkBendTestEditor
- (BOOL)hasMarkedText { return self.composing; }
@end

static NSEvent* history_key(BOOL redo) {
  return [NSEvent keyEventWithType:NSEventTypeKeyDown
    location:NSZeroPoint
    modifierFlags:NSEventModifierFlagCommand | (redo ? NSEventModifierFlagShift : 0)
    timestamp:0 windowNumber:0 context:nil characters:@"z"
    charactersIgnoringModifiers:@"z" isARepeat:NO keyCode:6];
}
#endif

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
#if defined(__APPLE__)
  MarkBendLiveState* state = (__bridge MarkBendLiveState*)(void*)(uintptr_t)handle;
  assert([state.text isEqualToString:@"中文 **one**\n**two**"]);
  assert([state.rendered.string isEqualToString:@"中文 one\ntwo"]);
  NSFont* plain = [state.rendered attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
  NSFont* bold = [state.rendered attribute:NSFontAttributeName atIndex:3 effectiveRange:NULL];
  assert(([[NSFontManager sharedFontManager] traitsOfFont:plain] & NSBoldFontMask) == 0);
  assert(([[NSFontManager sharedFontManager] traitsOfFont:bold] & NSBoldFontMask) != 0);
  for (NSUInteger index = 0; index < state.rendered.length; index++) {
    NSColor* color = [state.rendered attribute:NSForegroundColorAttributeName
      atIndex:index effectiveRange:NULL];
    assert([color isEqual:NSColor.textColor]);
  }
  MarkBendTestEditor* editor = [[MarkBendTestEditor alloc]
    initWithFrame:NSMakeRect(0, 0, 100, 100)];
  editor.session = state;
  state.editor = editor;
  state.editor.string = state.text;
  state.editor.selectedRange = NSMakeRange(3, 0);
  state.editor.delegate = state;
#else
  MarkBendLiveState* state = (void*)(uintptr_t)handle;
  assert(strcmp(state->text, "中文 **one**\n**two**") == 0);
  assert(strcmp(state->preview, "中文 \033[1mone\033[0m\n\033[1mtwo\033[0m") == 0);
#endif
  args[1] = (Term)(uintptr_t)"unfinished **";
  live_paragraph_set_run(e, args, &work);
  args[2] = 0;
  live_paragraph_append_run(e, args, &work);
#if defined(__APPLE__)
  assert([state.rendered.string isEqualToString:@"unfinished **"]);
  assert(state.editor.selectedRange.location == 3);
  state.response = 123;
  state.updating = YES;
  [state textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification
    object:state.editor]];
  assert(state.response == 123);
  state.updating = NO;
  assert([editor performKeyEquivalent:history_key(NO)]);
  assert(state.response == NSAlertSecondButtonReturn);
  assert([editor performKeyEquivalent:history_key(YES)]);
  assert(state.response == NSAlertThirdButtonReturn);
  editor.composing = YES;
  state.response = 123;
  [editor performKeyEquivalent:history_key(NO)];
  assert(state.response == 123);
  [state textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification
    object:editor]];
  assert(state.response == 123);
  editor.composing = NO;
  [state textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification
    object:editor]];
  assert(state.response == NSAlertFirstButtonReturn);
  [NSApplication sharedApplication];
  NSWindow* test_window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 100, 100)
    styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
  assert(![state windowShouldClose:test_window]);
  assert(state.response == NSAlertFirstButtonReturn + 3);
#else
  assert(strcmp(state->preview, "unfinished **") == 0);
#endif
  args[1] = (Term)(uintptr_t)"italic";
  args[2] = 2;
  live_paragraph_append_run(e, args, &work);
#if defined(__APPLE__)
  NSFont* italic = [state.rendered attribute:NSFontAttributeName
    atIndex:state.rendered.length - 1 effectiveRange:NULL];
  assert(([[NSFontManager sharedFontManager] traitsOfFont:italic] & NSItalicFontMask) != 0);
  assert(([[NSFontManager sharedFontManager] traitsOfFont:italic] & NSBoldFontMask) == 0);
#else
  assert(strcmp(state->preview, "unfinished **\033[3mitalic\033[0m") == 0);
#endif
  args[1] = (Term)(uintptr_t)"**literal**";
  args[2] = 3;
  live_paragraph_append_run(e, args, &work);
#if defined(__APPLE__)
  NSFont* code_font = [state.rendered attribute:NSFontAttributeName
    atIndex:state.rendered.length - 1 effectiveRange:NULL];
  assert(([[NSFontManager sharedFontManager] traitsOfFont:code_font] & NSFixedPitchFontMask) != 0);
#else
  assert(strstr(state->preview, "\033[7m**literal**\033[0m") != NULL);
#endif
  live_paragraph_close_run(e, args, &work);
  puts("Host round trip passed");
}
