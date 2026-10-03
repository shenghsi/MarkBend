#import <Cocoa/Cocoa.h>
#include <execinfo.h>

static NSTimer* driver_timeout;

static void driver_fault(int code) {
  void* frames[40];
  int count = backtrace(frames, 40);
  backtrace_symbols_fd(frames, count, 2);
  _Exit(1);
}

Term driver_enqueue_run(Env e, Term* f, IoWork* w) {
  // A timeout belongs to one event, not to later windows or actions.
  [driver_timeout invalidate];
  driver_timeout = nil;
  signal(SIGSEGV, driver_fault);
  signal(SIGBUS, driver_fault);
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  id state = (__bridge id)(void*)handle;
  u32 action = (u32)f[1];
  [NSApplication sharedApplication];
  NSTimer* timer = [NSTimer timerWithTimeInterval:0.02 repeats:NO block:^(NSTimer* timer) {
    NSTextView* editor = [state valueForKey:@"preview"];
    if (action == 30) {
      editor.selectedRange = NSMakeRange(editor.string.length, 0);
      [editor insertNewline:nil];
    } else if (action == 0) {
      editor.selectedRange = NSMakeRange(8, 0);
    } else if (action == 1) {
      [editor insertText:@"😀" replacementRange:NSMakeRange(NSNotFound, 0)];
    } else if (action == 4) {
      editor.selectedRange = NSMakeRange(1, 0);
    } else if (action == 5) {
      NSInteger response = [[state valueForKey:@"response"] integerValue];
      [editor setMarkedText:@"中文" selectedRange:NSMakeRange(2, 0)
        replacementRange:NSMakeRange(2, 2)];
      if (!editor.hasMarkedText ||
        [[state valueForKey:@"response"] integerValue] != response) {
        fprintf(stderr, "Marked text sent a committed event\n");
        exit(1);
      }
      [editor unmarkText];
    } else if (action == 6) {
      [editor insertText:@"" replacementRange:NSMakeRange(8, 2)];
    } else if (action == 20) {
      editor.selectedRange = NSMakeRange(22, 0);
    } else if (action == 21) {
      editor.selectedRange = NSMakeRange(4, 0);
    } else if (action == 22) {
      [editor insertText:@"X" replacementRange:NSMakeRange(10, 1)];
    } else if (action == 24) {
      editor.selectedRange = NSMakeRange(30, 0);
    } else {
      NSEvent* event = [NSEvent keyEventWithType:NSEventTypeKeyDown
        location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand |
          (action == 3 ? NSEventModifierFlagShift : 0)
        timestamp:0 windowNumber:0 context:nil characters:@"z"
        charactersIgnoringModifiers:@"z" isARepeat:NO keyCode:6];
      [editor performKeyEquivalent:event];
    }
  }];
  [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSModalPanelRunLoopMode];
  // A failed native event must not leave this test waiting for manual input.
  driver_timeout = [NSTimer timerWithTimeInterval:3 repeats:NO block:^(NSTimer* timer) {
    fprintf(stderr, "Native direct event timed out\n");
    exit(1);
  }];
  [[NSRunLoop currentRunLoop] addTimer:driver_timeout forMode:NSModalPanelRunLoopMode];
  return f[0];
}

Term driver_inspect_run(Env e, Term* f, IoWork* w) {
  [driver_timeout invalidate];
  driver_timeout = nil;
  id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
  NSTextView* editor = [state valueForKey:@"preview"];
  u64 length;
  char* bytes = io_cstr(e, f[1], &length);
  NSString* expected = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
  free(bytes);
  if (![editor.string isEqualToString:expected] ||
    editor.selectedRange.location != (NSUInteger)f[2] || editor.selectedRange.length != 0) {
    fprintf(stderr, "Native direct scene or selection failed: actual=%s expected=%s caret=%lu expectedCaret=%llu length=%lu\n",
      editor.string.UTF8String, expected.UTF8String, (unsigned long)editor.selectedRange.location,
      (unsigned long long)f[2], (unsigned long)editor.selectedRange.length);
    exit(1);
  }
  return f[0];
}

Term driver_inspect_source_run(Env e, Term* f, IoWork* w) {
  [driver_timeout invalidate];
  driver_timeout = nil;
  id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
  u64 length;
  char* bytes = io_cstr(e, f[1], &length);
  NSString* expected = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
  free(bytes);
  NSTextView* raw = [state valueForKey:@"editor"];
  if (![[state valueForKey:@"text"] isEqualToString:expected] ||
    ![raw.string isEqualToString:expected]) {
    fprintf(stderr, "Native host source differs from Bend source\n");
    exit(1);
  }
  return f[0];
}

static void __attribute__((constructor)) native_direct_use(void) {
  io_eff(CID(Driver.enqueue), driver_enqueue_run, 0);
  io_eff(CID(Driver.inspect), driver_inspect_run, 0);
  io_eff(CID(Driver.inspect_source), driver_inspect_source_run, 0);
}
