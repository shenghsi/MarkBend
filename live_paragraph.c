#if defined(__APPLE__)

#import <Cocoa/Cocoa.h>

@interface MarkBendLiveState : NSObject
@property(nonatomic, copy) NSString* text;
@end

@implementation MarkBendLiveState
@end

static void live_paragraph_activate(void) {
  NSApplication* application = [NSApplication sharedApplication];
  [application setActivationPolicy:NSApplicationActivationPolicyRegular];
  [application finishLaunching];
  if (@available(macOS 14.0, *)) {
    [application activate];
  } else {
    [application activateIgnoringOtherApps:YES];
  }
}

static NSString* live_paragraph_string(Term value, Env e) {
  u64 input_length = 0;
  char* input = io_cstr(e, value, &input_length);
  NSString* text = [[NSString alloc]
    initWithBytes:input
    length:input_length
    encoding:NSUTF8StringEncoding];
  free(input);
  return text == nil ? @"" : text;
}

Term live_paragraph_open_run(Env e, Term* f, IoWork* w) {
  MarkBendLiveState* state = [MarkBendLiveState new];
  state.text = live_paragraph_string(f[0], e);
  return io_hand((intptr_t)CFBridgingRetain(state));
}

Term live_paragraph_next_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (__bridge MarkBendLiveState*)(void*)handle;
  Term event;

  @autoreleasepool {
    live_paragraph_activate();
    NSAlert* alert = [NSAlert new];
    NSRect editor_frame = NSMakeRect(0, 0, 620, 220);
    NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:editor_frame];
    NSTextView* editor = [[NSTextView alloc] initWithFrame:editor_frame];
    alert.messageText = @"MarkBend paragraph checkpoint";
    alert.informativeText =
      @"Apply sends this text to Bend. Undo and Redo are calculated by Bend.";
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;
    scroll.documentView = editor;
    editor.editable = YES;
    editor.selectable = YES;
    editor.richText = NO;
    editor.allowsUndo = NO;
    editor.font = [NSFont systemFontOfSize:18];
    editor.string = state.text;
    editor.minSize = NSMakeSize(0, editor_frame.size.height);
    editor.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    editor.verticallyResizable = YES;
    editor.horizontallyResizable = NO;
    editor.autoresizingMask = NSViewWidthSizable;
    editor.textContainer.containerSize =
      NSMakeSize(editor_frame.size.width, CGFLOAT_MAX);
    editor.textContainer.widthTracksTextView = YES;
    alert.accessoryView = scroll;
    [alert addButtonWithTitle:@"Apply"];
    [alert addButtonWithTitle:@"Undo"];
    [alert addButtonWithTitle:@"Redo"];
    [alert addButtonWithTitle:@"Close"];
    [alert.window makeFirstResponder:editor];

    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
      state.text = editor.string;
      NSData* bytes = [state.text dataUsingEncoding:NSUTF8StringEncoding];
      event = io_box(e, CID(ParagraphChanged),
        io_str(e, bytes.bytes, bytes.length));
    } else if (response == NSAlertSecondButtonReturn) {
      event = term_pak(CID(ParagraphUndo), 0);
    } else if (response == NSAlertThirdButtonReturn) {
      event = term_pak(CID(ParagraphRedo), 0);
    } else {
      event = term_pak(CID(ParagraphClosed), 0);
    }
  }

  return io_tup(e, io_hand(handle), event);
}

Term live_paragraph_set_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (__bridge MarkBendLiveState*)(void*)handle;
  state.text = live_paragraph_string(f[1], e);
  return io_hand(handle);
}

Term live_paragraph_close_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = CFBridgingRelease((void*)handle);
  state.text = nil;
  return term_pak(CID(Unit), 0);
}

#else

typedef struct {
  char* text;
  u64 length;
} MarkBendLiveState;

static void live_paragraph_store(
  MarkBendLiveState* state, const char* text, u64 length
) {
  char* copy = malloc(length + 1);
  if (copy == NULL) {
    err_fail("LiveParagraph: allocation failed");
  }
  memcpy(copy, text, length);
  copy[length] = 0;
  free(state->text);
  state->text = copy;
  state->length = length;
}

Term live_paragraph_open_run(Env e, Term* f, IoWork* w) {
  u64 input_length = 0;
  char* input = io_cstr(e, f[0], &input_length);
  MarkBendLiveState* state = calloc(1, sizeof(MarkBendLiveState));
  if (state == NULL) {
    free(input);
    err_fail("LiveParagraph: allocation failed");
  }
  live_paragraph_store(state, input, input_length);
  free(input);
  return io_hand((intptr_t)state);
}

Term live_paragraph_next_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (MarkBendLiveState*)(void*)handle;
  char* line = NULL;
  size_t line_capacity = 0;
  char* draft = malloc(1);
  u64 draft_length = 0;
  Term event = term_pak(CID(ParagraphClosed), 0);

  if (draft == NULL) {
    err_fail("LiveParagraph: allocation failed");
  }
  draft[0] = 0;
  fprintf(stderr,
    "\n--- MarkBend multiline checkpoint ---\n%.*s\n"
    "Enter replacement text, then .apply on its own line.\n"
    "Commands: .undo .redo .close\n> ",
    (int)state->length, state->text);
  fflush(stderr);

  while (getline(&line, &line_capacity, stdin) >= 0) {
    if (strcmp(line, ".undo\n") == 0 && draft_length == 0) {
      event = term_pak(CID(ParagraphUndo), 0);
      break;
    }
    if (strcmp(line, ".redo\n") == 0 && draft_length == 0) {
      event = term_pak(CID(ParagraphRedo), 0);
      break;
    }
    if (strcmp(line, ".close\n") == 0 && draft_length == 0) {
      event = term_pak(CID(ParagraphClosed), 0);
      break;
    }
    if (strcmp(line, ".apply\n") == 0) {
      live_paragraph_store(state, draft, draft_length);
      event = io_box(e, CID(ParagraphChanged),
        io_str(e, state->text, state->length));
      break;
    }

    u64 line_length = strlen(line);
    char* grown = realloc(draft, draft_length + line_length + 1);
    if (grown == NULL) {
      free(draft);
      free(line);
      err_fail("LiveParagraph: allocation failed");
    }
    draft = grown;
    memcpy(draft + draft_length, line, line_length + 1);
    draft_length += line_length;
  }

  free(draft);
  free(line);
  return io_tup(e, io_hand(handle), event);
}

Term live_paragraph_set_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (MarkBendLiveState*)(void*)handle;
  u64 input_length = 0;
  char* input = io_cstr(e, f[1], &input_length);
  live_paragraph_store(state, input, input_length);
  free(input);
  return io_hand(handle);
}

Term live_paragraph_close_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (MarkBendLiveState*)(void*)handle;
  free(state->text);
  free(state);
  return term_pak(CID(Unit), 0);
}

#endif

static void __attribute__((constructor)) live_paragraph_use(void) {
  io_eff(CID(LiveParagraph.open), live_paragraph_open_run, 0);
  io_eff(CID(LiveParagraph.next), live_paragraph_next_run, 0);
  io_eff(CID(LiveParagraph.set), live_paragraph_set_run, 0);
  io_eff(CID(LiveParagraph.close), live_paragraph_close_run, 0);
}
