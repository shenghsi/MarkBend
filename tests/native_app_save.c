#import <Cocoa/Cocoa.h>
#include <stdatomic.h>

static NSTimer* app_save_timer;
static atomic_bool app_save_finished;
static NSUInteger app_save_step;
static NSWindow* app_save_window;
static NSData* app_save_original;
static NSData* app_save_expected;
static NSString* app_save_path;
static NSUInteger app_save_mode;
static NSData* app_save_observed;

static NSButton* app_save_button(NSView* view, NSString* title) {
  if ([view isKindOfClass:[NSButton class]] &&
      [((NSButton*)view).title isEqualToString:title]) return (NSButton*)view;
  for (NSView* child in view.subviews) {
    NSButton* result = app_save_button(child, title);
    if (result) return result;
  }
  return nil;
}
static void app_save_require(BOOL ok, const char* message) {
  if (!ok) { fprintf(stderr, "Native app save failed at step %lu: %s\n",
    (unsigned long)app_save_step, message); exit(1); }
}
static void app_save_click(NSWindow* window, NSString* title) {
  NSButton* button = app_save_button(window.contentView, title);
  app_save_require(button != nil, "missing runtime button");
  [button performClick:nil];
}
static void app_save_disk(NSData* expected) {
  if (!expected) {
    app_save_require(![[NSFileManager defaultManager] fileExistsAtPath:app_save_path],
      "missing destination was recreated");
    return;
  }
  NSData* actual = [NSData dataWithContentsOfFile:app_save_path];
  if (![actual isEqualToData:expected]) fprintf(stderr, "actual=%s expected=%s\n",
    actual.description.UTF8String, expected.description.UTF8String);
  app_save_require([actual isEqualToData:expected],
    "exact disk bytes");
}
static void app_save_source(id state, NSString* expected) {
  NSTextView* source = [state valueForKey:@"editor"];
  NSData* expected_bytes = [expected dataUsingEncoding:NSUTF8StringEncoding];
  NSData* actual_bytes = [[state valueForKey:@"text"] dataUsingEncoding:NSUTF8StringEncoding];
  if (![actual_bytes isEqualToData:expected_bytes]) fprintf(stderr,
    "source actual=%s expected=%s\n", actual_bytes.description.UTF8String,
    expected_bytes.description.UTF8String);
  app_save_require([actual_bytes isEqualToData:expected_bytes] &&
    [[source.string dataUsingEncoding:NSUTF8StringEncoding] isEqualToData:expected_bytes],
    "exact source bytes");
  app_save_require([[state valueForKey:@"text"] isEqualToString:expected] &&
    [source.string isEqualToString:expected], "exact source mirror");
}

Term app_save_prepare_run(Env e, Term* f, IoWork* w) {
  const char* path = getenv("MARKBEND_SAVE_FIXTURE_PATH");
  if (!path) path = getenv("MARKBEND_OPEN_PATH");
  const char* expected = getenv("MARKBEND_SAVE_EXPECTED");
  app_save_require(path && expected, "missing temporary fixtures");
  app_save_path = [NSString stringWithUTF8String:path];
  app_save_original = [NSData dataWithContentsOfFile:app_save_path];
  const char* mode = getenv("MARKBEND_SAVE_MODE");
  app_save_mode = mode && !strcmp(mode, "conflict") ? 1 : mode && !strcmp(mode, "missing") ? 2 :
    mode && !strcmp(mode, "before") ? 3 : mode && !strcmp(mode, "uncertain") ? 4 :
    mode && !strcmp(mode, "untitled") ? 5 : 0;
  app_save_observed = app_save_original;
  if (app_save_mode == 5) app_save_original =
    [@"Edit this paragraph. 中文输入 and 日本語入力 are welcome." dataUsingEncoding:NSUTF8StringEncoding];
  app_save_expected = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:expected]];
  NSString* next = [[NSString alloc] initWithData:app_save_expected encoding:NSUTF8StringEncoding];
  // Foundation's UTF-8 decoder consumes a leading BOM. Construct U+FEFF
  // explicitly so the actual input event carries all fixture bytes.
  const unsigned char* raw = app_save_expected.bytes;
  if (app_save_expected.length >= 3 && raw[0] == 239 && raw[1] == 187 && raw[2] == 191)
    next = [@"\uFEFF" stringByAppendingString:next];
  app_save_require(app_save_original && next, "invalid fixture");
  [NSApplication sharedApplication];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC),
    dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      if (!atomic_load(&app_save_finished)) {
        fprintf(stderr, "Native app save watchdog timed out at step %lu\n",
          (unsigned long)app_save_step); _Exit(1);
      }
    });
  app_save_timer = [NSTimer timerWithTimeInterval:0.04 repeats:YES block:^(NSTimer* timer) {
    NSWindow* window = NSApp.modalWindow;
    if (!window) return;
    id state = window.delegate;
    if (app_save_mode == 5 && app_save_step >= 7) {
      if (app_save_step == 7 && window != app_save_window) {
        app_save_step++; app_save_click(window, @"Save");
      } else if (app_save_step == 8 && window == app_save_window) {
        NSAlert* alert = [state valueForKey:@"alert"];
        if (![alert.informativeText isEqualToString:@"Save As is unavailable for this document"]) return;
        app_save_source(state, next); app_save_disk(app_save_observed);
        app_save_step++; [state windowShouldClose:window];
      } else if (app_save_step == 9 && window != app_save_window) {
        app_save_step++; [timer invalidate]; app_save_click(window, @"Discard");
      }
      return;
    }
    if (app_save_mode == 4 && app_save_step >= 5) {
      if (app_save_step == 5 && window == app_save_window) {
        NSAlert* alert = [state valueForKey:@"alert"];
        if (![alert.informativeText isEqualToString:@"Save is pending. Keep this document open"]) return;
        app_save_source(state, next); app_save_disk(app_save_expected);
        app_save_step++; app_save_click(window, @"Undo");
      } else if (app_save_step == 6 && window == app_save_window) {
        NSString* original = [[NSString alloc] initWithData:app_save_original encoding:NSUTF8StringEncoding];
        app_save_source(state, original); app_save_disk(app_save_expected);
        app_save_step++; [state windowShouldClose:window];
      } else if (app_save_step == 7 && window != app_save_window) {
        app_save_step++; app_save_click(window, @"Cancel");
      } else if (app_save_step == 8 && window == app_save_window) {
        app_save_disk(app_save_expected); app_save_step++; app_save_click(window, @"Redo");
      } else if (app_save_step == 9 && window == app_save_window) {
        app_save_source(state, next); app_save_disk(app_save_expected);
        app_save_step++; [state windowShouldClose:window];
      } else if (app_save_step == 10 && window != app_save_window) {
        app_save_step++; app_save_click(window, @"Save");
      } else if (app_save_step == 11 && window == app_save_window) {
        NSAlert* alert = [state valueForKey:@"alert"];
        if (![alert.informativeText isEqualToString:@"Save is pending. Keep this document open"]) return;
        app_save_source(state, next); app_save_disk(app_save_expected);
        app_save_step++; [state windowShouldClose:window];
      } else if (app_save_step == 12 && window != app_save_window) {
        app_save_step++; [timer invalidate]; app_save_click(window, @"Discard");
      }
      return;
    }
    if (app_save_step == 0) {
      app_save_window = window;
      NSTextView* source = [state valueForKey:@"editor"];
      source.string = next;
      app_save_step++;
      app_save_click(window, @"Apply");
    } else if (app_save_step == 1 && window == app_save_window) {
      app_save_source(state, next); app_save_disk(app_save_observed);
      if (app_save_mode == 1) {
        app_save_observed = [@"external\r\n" dataUsingEncoding:NSUTF8StringEncoding];
        app_save_require([app_save_observed writeToFile:app_save_path atomically:NO], "external fixture edit");
      } else if (app_save_mode == 2) {
        app_save_require([[NSFileManager defaultManager] removeItemAtPath:app_save_path error:nil],
          "remove temporary destination");
        app_save_observed = nil;
      }
      app_save_step++; [state windowShouldClose:window];
    } else if (app_save_step == 2 && window != app_save_window) {
      app_save_disk(app_save_observed); app_save_step++; app_save_click(window, @"Cancel");
    } else if (app_save_step == 3 && window == app_save_window) {
      app_save_source(state, next); app_save_disk(app_save_observed);
      app_save_step++; app_save_click(window, @"Save");
    } else if (app_save_step == 4 && window == app_save_window) {
      // The native save runs on a worker while the IO continuation retains the
      // document. Wait for its completion presentation before the next action.
      NSAlert* alert = [state valueForKey:@"alert"];
      NSString* status = app_save_mode == 1 ? @"The file changed on disk. Save stopped" :
        app_save_mode == 2 || app_save_mode == 3 ? @"Save failed. The file was not replaced" :
        app_save_mode == 4 ? @"Save could not be confirmed. Keep this document open" :
        app_save_mode == 5 ? @"Save As is unavailable for this document" : @"Saved";
      if (![alert.informativeText isEqualToString:status]) return;
      if (!app_save_mode || app_save_mode == 4) app_save_observed = app_save_expected;
      app_save_source(state, next); app_save_disk(app_save_observed);
      app_save_step++; app_save_click(window, app_save_mode == 4 ? @"Save" : @"Undo");
    } else if (app_save_step == 5 && window == app_save_window) {
      NSString* original = [[NSString alloc] initWithData:app_save_original encoding:NSUTF8StringEncoding];
      app_save_source(state, original); app_save_disk(app_save_observed);
      app_save_step++; app_save_click(window, @"Redo");
    } else if (app_save_step == 6 && window == app_save_window) {
      app_save_source(state, next); app_save_disk(app_save_observed);
      app_save_step++;
      if (!app_save_mode) [timer invalidate];
      [state windowShouldClose:window];
    } else if (app_save_step == 7 && app_save_mode && window != app_save_window) {
      app_save_disk(app_save_observed);
      app_save_step++; [timer invalidate]; app_save_click(window, @"Discard");
    }
  }];
  [[NSRunLoop currentRunLoop] addTimer:app_save_timer forMode:NSModalPanelRunLoopMode];
  return term_pak(CID(Unit), 0);
}

Term app_save_finish_run(Env e, Term* f, IoWork* w) {
  atomic_store(&app_save_finished, true); [app_save_timer invalidate];
  app_save_require(app_save_step == (app_save_mode == 5 ? 10 : app_save_mode == 4 ? 13 : app_save_mode ? 8 : 7), "missing completed event sequence");
  app_save_disk(app_save_observed);
  printf("Native app save sequence passed: %s\n", app_save_mode == 1 ? "conflict retained" :
    app_save_mode == 2 ? "missing destination retained" : app_save_mode == 3 ? "pre-replacement failure retained" :
    app_save_mode == 4 ? "uncertain ticket blocked retry and close" :
    app_save_mode == 5 ? "untitled Save and Save-on-close retained" : "confirmed exact bytes");
  return term_pak(CID(Unit), 0);
}
static void __attribute__((constructor)) app_save_test_use(void) {
  io_eff(CID(Driver.prepare), app_save_prepare_run, 0);
  io_eff(CID(Driver.finish), app_save_finish_run, 0);
}
