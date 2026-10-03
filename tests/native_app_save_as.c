#import <Cocoa/Cocoa.h>
#include <stdatomic.h>
static NSTimer* save_as_timer;
static atomic_bool save_as_finished;
static NSUInteger save_as_step;
static NSWindow* save_as_window;
static NSString* save_as_path;
static NSString* save_as_original;
static NSData* save_as_bytes;
static NSString* save_as_diagnostic;
static void save_as_require(BOOL ok, const char* message) {
  if (!ok) { fprintf(stderr, "Native Save As step %lu: %s\n", (unsigned long)save_as_step, message); exit(1); }
}
static NSButton* save_as_button(NSView* view, NSString* title) {
  if ([view isKindOfClass:NSButton.class] && [((NSButton*)view).title isEqualToString:title]) return (NSButton*)view;
  for (NSView* child in view.subviews) { NSButton* found = save_as_button(child, title); if (found) return found; }
  return nil;
}
static void save_as_disk(BOOL published) {
  save_as_require([[NSData dataWithContentsOfFile:save_as_original] isEqualToData:save_as_bytes], "original changed");
  if (published) save_as_require([[NSData dataWithContentsOfFile:save_as_path] isEqualToData:save_as_bytes], "published bytes differ");
  else save_as_require(![[NSFileManager defaultManager] fileExistsAtPath:save_as_path], "cancel created file");
}
Term save_as_prepare_run(Env e, Term* f, IoWork* w) {
  const char* target = getenv("MARKBEND_SAVE_AS_TARGET");
  const char* original = getenv("MARKBEND_OPEN_PATH");
  save_as_require(target && original, "private fixture paths missing");
  save_as_path = [NSString stringWithUTF8String:target];
  save_as_original = [NSString stringWithUTF8String:original];
  save_as_bytes = [NSData dataWithContentsOfFile:save_as_original];
  save_as_require(save_as_bytes != nil, "fixture missing");
  [NSApplication sharedApplication];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    if (!atomic_load(&save_as_finished)) { fprintf(stderr, "Native Save As watchdog step %lu: %s\n", (unsigned long)save_as_step, save_as_diagnostic.UTF8String); _Exit(1); }
  });
  save_as_timer = [NSTimer timerWithTimeInterval:0.05 repeats:YES block:^(NSTimer* timer) {
    NSWindow* window = NSApp.modalWindow; if (!window) return;
    if ([window isKindOfClass:NSSavePanel.class]) {
      NSSavePanel* panel = (NSSavePanel*)window;
      save_as_diagnostic = [NSString stringWithFormat:@"panel directory=%@ name=%@ URL=%@ responder=%@ sheet=%@", panel.directoryURL, panel.nameFieldStringValue, panel.URL, panel.firstResponder, panel.attachedSheet];
    } else if (window == save_as_window) {
      NSAlert* alert = [(id)window.delegate valueForKey:@"alert"];
      save_as_diagnostic = [NSString stringWithFormat:@"app status=%@", alert.informativeText];
    }
    if (save_as_step == 0) {
      save_as_window = window; save_as_disk(NO);
      NSButton* button = save_as_button(window.contentView, @"Save As");
      save_as_require(button != nil, "Save As button missing"); save_as_step++; [button performClick:nil];
    } else if (save_as_step == 1 && [window isKindOfClass:NSSavePanel.class]) {
      save_as_step++; [(NSSavePanel*)window cancel:nil];
    } else if (save_as_step == 2 && window == save_as_window) {
      save_as_disk(NO); id state = window.delegate;
      NSTextView* editor = [state valueForKey:@"editor"];
      NSEvent* event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
        modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagShift timestamp:0
        windowNumber:window.windowNumber context:nil characters:@"S" charactersIgnoringModifiers:@"s" isARepeat:NO keyCode:1];
      save_as_step++; save_as_require([editor performKeyEquivalent:event], "shortcut rejected");
    } else if (save_as_step == 3 && [window isKindOfClass:NSSavePanel.class]) {
      NSSavePanel* panel = (NSSavePanel*)window;
      if ([panel.directoryURL.path isEqualToString:save_as_path.stringByDeletingLastPathComponent] &&
          [panel.nameFieldStringValue isEqualToString:save_as_path.lastPathComponent] &&
          [panel.URL.path isEqualToString:save_as_path]) {
        save_as_step++;
        for (NSUInteger type = NSEventTypeKeyDown; type <= NSEventTypeKeyUp; type++) {
          NSEvent* event = [NSEvent keyEventWithType:type location:NSZeroPoint
            modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime
            windowNumber:panel.windowNumber context:nil characters:@"\r"
            charactersIgnoringModifiers:@"\r" isARepeat:NO keyCode:36];
          [NSApp sendEvent:event];
        }
        return;
      }
      panel.directoryURL = [NSURL fileURLWithPath:save_as_path.stringByDeletingLastPathComponent isDirectory:YES];
      panel.nameFieldStringValue = save_as_path.lastPathComponent;
    } else if (save_as_step == 4 && window == save_as_window) {
      id state = window.delegate; NSAlert* alert = [state valueForKey:@"alert"];
      if (![alert.informativeText isEqualToString:@"Saved"]) return;
      save_as_disk(YES); save_as_step++; [timer invalidate]; [state windowShouldClose:window];
    }
  }];
  [[NSRunLoop currentRunLoop] addTimer:save_as_timer forMode:NSModalPanelRunLoopMode];
  return term_pak(CID(Unit), 0);
}
Term save_as_finish_run(Env e, Term* f, IoWork* w) {
  atomic_store(&save_as_finished, true); [save_as_timer invalidate];
  save_as_require(save_as_step == 5, "event sequence incomplete"); save_as_disk(YES);
  puts("Native Save As button, Cancel, shortcut, dialog, and exact bytes passed");
  return term_pak(CID(Unit), 0);
}
static void __attribute__((constructor)) save_as_test_use(void) {
  io_eff(CID(Driver.prepare), save_as_prepare_run, 0);
  io_eff(CID(Driver.finish), save_as_finish_run, 0);
}
