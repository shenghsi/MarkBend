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
    NSTextField* field = [[NSTextField alloc]
      initWithFrame:NSMakeRect(0, 0, 620, 30)];
    alert.messageText = @"MarkBend paragraph checkpoint";
    alert.informativeText =
      @"Apply sends this text to Bend. Undo and Redo are calculated by Bend.";
    field.editable = YES;
    field.selectable = YES;
    field.font = [NSFont systemFontOfSize:18];
    field.stringValue = state.text;
    alert.accessoryView = field;
    [alert addButtonWithTitle:@"Apply"];
    [alert addButtonWithTitle:@"Undo"];
    [alert addButtonWithTitle:@"Redo"];
    [alert addButtonWithTitle:@"Close"];

    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
      state.text = field.stringValue;
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

Term live_paragraph_open_run(Env e, Term* f, IoWork* w) {
  return io_hand(0);
}

Term live_paragraph_next_run(Env e, Term* f, IoWork* w) {
  Term event = term_pak(CID(ParagraphClosed), 0);
  return io_tup(e, f[0], event);
}

Term live_paragraph_set_run(Env e, Term* f, IoWork* w) {
  return f[0];
}

Term live_paragraph_close_run(Env e, Term* f, IoWork* w) {
  return term_pak(CID(Unit), 0);
}

#endif

static void __attribute__((constructor)) live_paragraph_use(void) {
  io_eff(CID(LiveParagraph.open), live_paragraph_open_run, 0);
  io_eff(CID(LiveParagraph.next), live_paragraph_next_run, 0);
  io_eff(CID(LiveParagraph.set), live_paragraph_set_run, 0);
  io_eff(CID(LiveParagraph.close), live_paragraph_close_run, 0);
}
