#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#include <stdatomic.h>

static BOOL app_open_checked;
static NSTimer* app_open_timer;
static atomic_bool app_open_finished;
static IMP app_open_original_show;
static NSWindow* app_open_editor_window;

static NSButton* app_open_button(NSView* view, NSString* title) {
  if ([view isKindOfClass:[NSButton class]] &&
      [((NSButton*)view).title isEqualToString:title]) return (NSButton*)view;
  for (NSView* child in view.subviews) {
    NSButton* button = app_open_button(child, title);
    if (button) return button;
  }
  return nil;
}

static void app_open_show(id window, SEL selector, id sender) {
  if (getenv("MARKBEND_APP_REJECT")) {
    fprintf(stderr, "Rejected file opened an editor (display call)\n"); exit(1);
  }
  ((void (*)(id, SEL, id))app_open_original_show)(window, selector, sender);
}

Term app_open_prepare_run(Env e, Term* f, IoWork* w) {
  Method show = class_getInstanceMethod([NSWindow class], @selector(makeKeyAndOrderFront:));
  app_open_original_show = method_setImplementation(show, (IMP)app_open_show);
  const char* path = getenv("MARKBEND_APP_EXPECTED");
  if (!path) { fprintf(stderr, "Missing app startup fixture\n"); exit(1); }
  NSData* bytes = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:path]];
  NSString* expected = [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding];
  if (!expected) { fprintf(stderr, "Invalid app startup fixture\n"); exit(1); }
  [NSApplication sharedApplication];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC),
    dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      if (!atomic_load(&app_open_finished)) {
        fprintf(stderr, "Native app startup watchdog timed out\n"); _Exit(1);
      }
    });
  NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:10];
  app_open_timer = [NSTimer timerWithTimeInterval:0.02 repeats:YES block:^(NSTimer* timer) {
    NSWindow* window = NSApp.modalWindow;
    if (!window) {
      if ([deadline timeIntervalSinceNow] <= 0) {
        fprintf(stderr, "Native app startup timed out\n"); exit(1);
      }
      return;
    }
    if (app_open_checked) {
      if (window == app_open_editor_window) return;
      NSButton* discard = app_open_button(window.contentView, @"Discard");
      if (!discard) { fprintf(stderr, "Unexpected startup close dialog\n"); exit(1); }
      [timer invalidate];
      [discard performClick:nil];
      return;
    }
    if (getenv("MARKBEND_APP_REJECT")) {
      fprintf(stderr, "Rejected file opened an editor\n"); exit(1);
    }
    id state = window.delegate;
    NSTextView* source = [state valueForKey:@"editor"];
    NSTextView* preview = [state valueForKey:@"preview"];
    NSAttributedString* rendered = [state valueForKey:@"rendered"];
    if (![[[state valueForKey:@"text"] dataUsingEncoding:NSUTF8StringEncoding] isEqualToData:bytes] ||
        ![[source.string dataUsingEncoding:NSUTF8StringEncoding] isEqualToData:bytes] ||
        ![preview.string isEqualToString:rendered.string] ||
        !preview.editable || !source.editable) {
      fprintf(stderr, "Native app startup source or preview failed\n"); exit(1);
    }
    app_open_checked = YES;
    app_open_editor_window = window;
    [state windowShouldClose:window];
  }];
  [[NSRunLoop currentRunLoop] addTimer:app_open_timer forMode:NSModalPanelRunLoopMode];
  return term_pak(CID(Unit), 0);
}

Term app_open_finish_run(Env e, Term* f, IoWork* w) {
  [app_open_timer invalidate];
  app_open_timer = nil;
  atomic_store(&app_open_finished, true);
  method_setImplementation(class_getInstanceMethod([NSWindow class],
    @selector(makeKeyAndOrderFront:)), app_open_original_show);
  if (!app_open_checked) { fprintf(stderr, "Native app startup was not checked\n"); exit(1); }
  printf("Native app startup exact source and preview passed\n");
  return term_pak(CID(Unit), 0);
}

static void __attribute__((constructor)) native_app_open_use(void) {
  io_eff(CID(Driver.prepare), app_open_prepare_run, 0);
  io_eff(CID(Driver.finish), app_open_finish_run, 0);
}
