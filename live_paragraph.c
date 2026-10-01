#if defined(__APPLE__)

#import <Cocoa/Cocoa.h>

@class MarkBendLiveState;

@interface MarkBendEditor : NSTextView
@property(nonatomic, weak) MarkBendLiveState* session;
@end

@interface MarkBendLiveState : NSObject <NSTextViewDelegate, NSWindowDelegate>
@property(nonatomic, copy) NSString* text;
@property(nonatomic, strong) NSMutableAttributedString* rendered;
@property(nonatomic, strong) NSAlert* alert;
@property(nonatomic, strong) NSTextView* editor;
@property(nonatomic, strong) NSTextView* preview;
@property(nonatomic) NSInteger response;
@property(nonatomic) BOOL updating;
@end

@implementation MarkBendEditor

- (BOOL)performKeyEquivalent:(NSEvent*)event {
  NSEventModifierFlags flags = event.modifierFlags;
  if ((flags & NSEventModifierFlagCommand) == 0 ||
      (flags & (NSEventModifierFlagControl | NSEventModifierFlagOption)) != 0) {
    return [super performKeyEquivalent:event];
  }
  NSString* key = event.charactersIgnoringModifiers.lowercaseString;
  if ([key isEqualToString:@"z"]) {
    if (self.hasMarkedText) {
      return YES;
    }
    self.session.response = (flags & NSEventModifierFlagShift) != 0
      ? NSAlertThirdButtonReturn : NSAlertSecondButtonReturn;
    [NSApp stopModal];
    return YES;
  }
  if ([key isEqualToString:@"a"]) {
    [self selectAll:nil];
    return YES;
  }
  if ([key isEqualToString:@"c"]) {
    [self copy:nil];
    return YES;
  }
  if ([key isEqualToString:@"v"]) {
    [self pasteAsPlainText:nil];
    return YES;
  }
  if ([key isEqualToString:@"x"]) {
    [self cut:nil];
    return YES;
  }
  return [super performKeyEquivalent:event];
}

@end

@implementation MarkBendLiveState

- (void)textDidChange:(NSNotification*)notification {
  if (!self.updating && !self.editor.hasMarkedText) {
    self.response = NSAlertFirstButtonReturn;
    [NSApp stopModal];
  }
}

- (void)checkpointAction:(NSButton*)button {
  if (self.editor.hasMarkedText) {
    return;
  }
  self.response = button.tag;
  [NSApp stopModal];
}

- (BOOL)windowShouldClose:(NSWindow*)window {
  self.response = NSAlertFirstButtonReturn + 3;
  [NSApp stopModal];
  return NO;
}

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
  state.rendered = [NSMutableAttributedString new];
  return io_hand((intptr_t)CFBridgingRetain(state));
}

Term live_paragraph_next_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (__bridge MarkBendLiveState*)(void*)handle;
  Term event;

  @autoreleasepool {
    if (state.alert == nil) {
    live_paragraph_activate();
    NSAlert* alert = [NSAlert new];
    NSView* accessory = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 620, 300)];
    NSRect editor_frame = NSMakeRect(0, 100, 620, 200);
    NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:editor_frame];
    MarkBendEditor* editor = [[MarkBendEditor alloc] initWithFrame:editor_frame];
    editor.session = state;
    NSScrollView* preview_scroll = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(0, 0, 620, 80)];
    NSTextView* preview = [[NSTextView alloc]
      initWithFrame:NSMakeRect(0, 0, 620, 80)];
    alert.messageText = @"MarkBend paragraph editor";
    alert.informativeText =
      @"The preview updates after each edit. Undo and Redo use Bend history.";
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;
    scroll.documentView = editor;
    editor.editable = YES;
    editor.selectable = YES;
    editor.richText = NO;
    editor.allowsUndo = NO;
    editor.automaticQuoteSubstitutionEnabled = NO;
    editor.automaticDashSubstitutionEnabled = NO;
    editor.automaticTextReplacementEnabled = NO;
    editor.automaticSpellingCorrectionEnabled = NO;
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
    preview_scroll.borderType = NSBezelBorder;
    preview_scroll.backgroundColor = NSColor.textBackgroundColor;
    preview_scroll.documentView = preview;
    preview.editable = NO;
    preview.selectable = YES;
    preview.drawsBackground = YES;
    preview.backgroundColor = NSColor.textBackgroundColor;
    preview.textColor = NSColor.textColor;
    [preview.textStorage setAttributedString:state.rendered];
    [accessory addSubview:scroll];
    [accessory addSubview:preview_scroll];
    alert.accessoryView = accessory;
    [alert addButtonWithTitle:@"Apply"];
    [alert addButtonWithTitle:@"Undo"];
    [alert addButtonWithTitle:@"Redo"];
    [alert addButtonWithTitle:@"Close"];
    for (NSUInteger i = 0; i < alert.buttons.count; i++) {
      NSButton* button = alert.buttons[i];
      button.tag = NSAlertFirstButtonReturn + i;
      button.target = state;
      button.action = @selector(checkpointAction:);
    }
    state.alert = alert;
    state.editor = editor;
    state.preview = preview;
    editor.delegate = state;
    alert.window.delegate = state;
    [alert layout];
    [alert.window makeFirstResponder:editor];
    [alert.window center];
    }

    state.response = NSAlertFirstButtonReturn + 3;
    [state.alert.window makeKeyAndOrderFront:nil];
    [NSApp runModalForWindow:state.alert.window];
    NSModalResponse response = state.response;
    if (response == NSAlertFirstButtonReturn) {
      state.text = state.editor.string;
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
  state.rendered = [NSMutableAttributedString new];
  if (state.editor != nil && ![state.editor.string isEqualToString:state.text]) {
    NSRange selection = state.editor.selectedRange;
    state.updating = YES;
    state.editor.string = state.text;
    selection.location = MIN(selection.location, state.text.length);
    selection.length = MIN(selection.length, state.text.length - selection.location);
    state.editor.selectedRange = selection;
    state.updating = NO;
  }
  [state.preview.textStorage setAttributedString:state.rendered];
  return io_hand(handle);
}

Term live_paragraph_append_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (__bridge MarkBendLiveState*)(void*)handle;
  NSString* text = live_paragraph_string(f[1], e);
  u32 style = (u32)f[2];
  NSFont* font = [NSFont systemFontOfSize:20];
  if (style == 1) {
    font = [NSFont boldSystemFontOfSize:20];
  } else if (style == 2) {
    font = [[NSFontManager sharedFontManager] convertFont:font
      toHaveTrait:NSItalicFontMask];
  } else if (style == 3) {
    font = [NSFont monospacedSystemFontOfSize:20 weight:NSFontWeightRegular];
  }
  [state.rendered appendAttributedString:[[NSAttributedString alloc]
    initWithString:text attributes:@{
      NSFontAttributeName: font,
      NSForegroundColorAttributeName: NSColor.textColor
    }]];
  [state.preview.textStorage setAttributedString:state.rendered];
  return io_hand(handle);
}

Term live_paragraph_close_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = CFBridgingRelease((void*)handle);
  state.editor.delegate = nil;
  state.alert.window.delegate = nil;
  [state.alert.window orderOut:nil];
  state.alert = nil;
  state.editor = nil;
  state.preview = nil;
  state.text = nil;
  state.rendered = nil;
  return term_pak(CID(Unit), 0);
}

#else

typedef struct {
  char* text;
  u64 length;
  char* preview;
  u64 preview_length;
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
  state->preview = malloc(input_length + 1);
  if (state->preview == NULL) {
    free(input);
    free(state->text);
    free(state);
    err_fail("LiveParagraph: allocation failed");
  }
  memcpy(state->preview, input, input_length + 1);
  state->preview_length = input_length;
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
    "\n--- MarkBend multiline checkpoint ---\nPreview: %.*s\nSource: %.*s\n"
    "Enter replacement text, then .apply on its own line.\n"
    "Commands: .undo .redo .close\n> ",
    (int)state->preview_length, state->preview,
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
  state->preview_length = 0;
  state->preview[0] = 0;
  return io_hand(handle);
}

Term live_paragraph_append_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (MarkBendLiveState*)(void*)handle;
  u64 length = 0;
  char* text = io_cstr(e, f[1], &length);
  u32 style = (u32)f[2];
  int styled = style == 1 || style == 2 || style == 3;
  u64 preview_length = state->preview_length + length + (styled ? 8 : 0);
  char* preview_copy = realloc(state->preview, preview_length + 1);
  if (preview_copy == NULL) {
    free(text);
    err_fail("LiveParagraph: allocation failed");
  }
  state->preview = preview_copy;
  u64 at = state->preview_length;
  if (styled) {
    memcpy(state->preview + at,
      style == 1 ? "\033[1m" : style == 2 ? "\033[3m" : "\033[7m", 4);
    at += 4;
  }
  memcpy(state->preview + at, text, length);
  at += length;
  if (styled) {
    memcpy(state->preview + at, "\033[0m", 4);
    at += 4;
  }
  state->preview[at] = 0;
  state->preview_length = at;
  free(text);
  return io_hand(handle);
}

Term live_paragraph_close_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (MarkBendLiveState*)(void*)handle;
  free(state->text);
  free(state->preview);
  free(state);
  return term_pak(CID(Unit), 0);
}

#endif

static void __attribute__((constructor)) live_paragraph_use(void) {
  io_eff(CID(LiveParagraph.open), live_paragraph_open_run, 0);
  io_eff(CID(LiveParagraph.next), live_paragraph_next_run, 0);
  io_eff(CID(LiveParagraph.set), live_paragraph_set_run, 0);
  io_eff(CID(LiveParagraph.append), live_paragraph_append_run, 0);
  io_eff(CID(LiveParagraph.close), live_paragraph_close_run, 0);
}
