#import <Cocoa/Cocoa.h>
#include <stdatomic.h>
static NSTimer* recheck_timer;
static atomic_bool recheck_finished;
static NSUInteger recheck_step;
static void recheck_require(BOOL ok, const char* message) {
  if (!ok) { fprintf(stderr, "Native Recheck step %lu: %s\n", (unsigned long)recheck_step, message); exit(1); }
}
static NSButton* recheck_button(NSView* view, NSString* title) {
  if ([view isKindOfClass:NSButton.class] && [((NSButton*)view).title isEqualToString:title]) return (NSButton*)view;
  for (NSView* child in view.subviews) { NSButton* button = recheck_button(child, title); if (button) return button; }
  return nil;
}
Term recheck_prepare_run(Env e, Term* f, IoWork* w) {
  [NSApplication sharedApplication];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    if (!atomic_load(&recheck_finished)) { fprintf(stderr, "Native Recheck watchdog step %lu\n", (unsigned long)recheck_step); _Exit(1); }
  });
  recheck_timer = [NSTimer timerWithTimeInterval:0.05 repeats:YES block:^(NSTimer* timer) {
    NSWindow* window = NSApp.modalWindow; if (!window || recheck_step >= 3) return;
    id state = window.delegate; NSAlert* alert = [state valueForKey:@"alert"];
    if (recheck_step && ![alert.informativeText isEqualToString:@"Save As is pending or uncertain. Keep this document open"]) return;
    NSString* title = recheck_step == 0 ? @"Save" : recheck_step == 1 ? @"Close" : @"Recheck Save As";
    NSButton* button = recheck_button(window.contentView, title);
    recheck_require(button != nil, "runtime button missing"); recheck_step++; [button performClick:nil];
  }];
  [[NSRunLoop currentRunLoop] addTimer:recheck_timer forMode:NSModalPanelRunLoopMode];
  return term_pak(CID(Unit), 0);
}
Term recheck_finish_run(Env e, Term* f, IoWork* w) {
  atomic_store(&recheck_finished, true); [recheck_timer invalidate];
  recheck_require(recheck_step == 3, "event sequence incomplete");
  id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
  NSAlert* alert = [state valueForKey:@"alert"];
  u64 length = 0; char* expected = io_cstr(e, f[1], &length);
  NSString* message = !strcmp(expected, "confirmed") ? @"Save As confirmed" : @"Save As is still uncertain. Keep this document open";
  free(expected); recheck_require([alert.informativeText isEqualToString:message], "wrong completion status");
  return f[0];
}
static void __attribute__((constructor)) recheck_test_use(void) {
  io_eff(CID(Driver.prepare), recheck_prepare_run, 0);
  io_eff(CID(Driver.finish), recheck_finish_run, 0);
}
