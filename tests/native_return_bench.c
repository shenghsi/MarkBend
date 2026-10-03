#import <Cocoa/Cocoa.h>
#include <time.h>
#include <math.h>

static double return_bench_started;
static NSUInteger return_bench_events, return_bench_frames;
static NSTimer* return_bench_watchdog;
static NSRect return_bench_viewport;
static BOOL return_bench_has_viewport;
static NSTimer* return_bench_initial_watchdog;

Term returnbench_initialize_run(Env e, Term* f, IoWork* w) {
  id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
  NSTimer* action = [NSTimer timerWithTimeInterval:0.001 repeats:NO block:^(NSTimer* timer) {
    NSTextView* preview = [state valueForKey:@"preview"];
    if (!preview || ![state valueForKey:@"editor"]) {
      fprintf(stderr, "Native Return initial surface missing\n");
      exit(1);
    }
    NSScrollView* scroll = preview.enclosingScrollView;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = NO;
    scroll.scrollerStyle = NSScrollerStyleLegacy;
    [scroll tile];
    [state setValue:[NSValue valueWithRange:preview.selectedRange] forKey:@"pendingRange"];
    [state setValue:@YES forKey:@"pendingSelectionEvent"];
    [state setValue:@(NSSelectionAffinityDownstream) forKey:@"pendingSelectionAffinity"];
    [state setValue:@(NSAlertFirstButtonReturn + 4) forKey:@"response"];
    [return_bench_initial_watchdog invalidate];
    return_bench_initial_watchdog = nil;
    [NSApp stopModal];
  }];
  [[NSRunLoop currentRunLoop] addTimer:action forMode:NSModalPanelRunLoopMode];
  return_bench_initial_watchdog = [NSTimer timerWithTimeInterval:30 repeats:NO block:^(NSTimer* timer) {
    fprintf(stderr, "Native Return initialization timed out\n");
    exit(1);
  }];
  [[NSRunLoop currentRunLoop] addTimer:return_bench_initial_watchdog forMode:NSModalPanelRunLoopMode];
  return f[0];
}

static double return_bench_now(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return (double)t.tv_sec + (double)t.tv_nsec / 1e9;
}

static void return_bench_fail(const char* message) {
  fprintf(stderr, "Native Return benchmark failed: %s\n", message);
  exit(1);
}

Term returnbench_prepare_run(Env e, Term* f, IoWork* w) {
  id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
  NSTextView* editor = [state valueForKey:@"preview"];
  [state setValue:@(f[1] != 0) forKey:@"measurePresentation"];
  if (editor.selectedRange.location != editor.string.length || editor.selectedRange.length)
    return_bench_fail("baseline selection");
  [editor.layoutManager ensureLayoutForBoundingRect:editor.visibleRect inTextContainer:editor.textContainer];
  if (!return_bench_has_viewport) {
    [editor scrollRangeToVisible:editor.selectedRange];
  } else {
    NSScrollView* scroll = editor.enclosingScrollView;
    [scroll.contentView scrollToPoint:return_bench_viewport.origin];
    [scroll reflectScrolledClipView:scroll.contentView];
  }
  [editor.layoutManager ensureLayoutForBoundingRect:editor.visibleRect inTextContainer:editor.textContainer];
  [editor setNeedsDisplay:YES];
  [editor.window displayIfNeeded];
  if (!return_bench_has_viewport) {
    return_bench_viewport = editor.visibleRect;
    return_bench_has_viewport = YES;
    NSFont* font = [editor.textStorage attribute:NSFontAttributeName
      atIndex:editor.string.length - 1 effectiveRange:NULL];
    printf("native_return_surface width=%.3f height=%.3f y=%.3f scale=%.3f caret_font=%s caret_font_size=%.3f\n",
      editor.visibleRect.size.width, editor.visibleRect.size.height, editor.visibleRect.origin.y,
      editor.window.backingScaleFactor, font.fontName.UTF8String, font.pointSize);
  } else if (!NSEqualRects(editor.visibleRect, return_bench_viewport)) {
    fprintf(stderr, "requested viewport=%s actual=%s\n",
      NSStringFromRect(return_bench_viewport).UTF8String, NSStringFromRect(editor.visibleRect).UTF8String);
    return_bench_fail("baseline viewport changed");
  }
  NSRange glyphs = [editor.layoutManager glyphRangeForCharacterRange:
    NSMakeRange(editor.string.length - 1, 1) actualCharacterRange:NULL];
  NSRect caret = [editor.layoutManager boundingRectForGlyphRange:glyphs inTextContainer:editor.textContainer];
  caret.origin.x += editor.textContainerInset.width;
  caret.origin.y += editor.textContainerInset.height;
  if (!NSIntersectsRect(caret, editor.visibleRect)) return_bench_fail("baseline caret outside viewport");
  return f[0];
}

Term returnbench_enqueue_run(Env e, Term* f, IoWork* w) {
  id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
  if (return_bench_events != return_bench_frames || return_bench_events >= 20)
    return_bench_fail("event count");
  NSTimer* action = [NSTimer timerWithTimeInterval:0.001 repeats:NO block:^(NSTimer* timer) {
    NSTextView* editor = [state valueForKey:@"preview"];
    return_bench_events++;
    return_bench_started = return_bench_now();
    [editor insertNewline:nil];
  }];
  [[NSRunLoop currentRunLoop] addTimer:action forMode:NSModalPanelRunLoopMode];
  return_bench_watchdog = [NSTimer timerWithTimeInterval:30 repeats:NO block:^(NSTimer* timer) {
    return_bench_fail("event watchdog");
  }];
  [[NSRunLoop currentRunLoop] addTimer:return_bench_watchdog forMode:NSModalPanelRunLoopMode];
  return f[0];
}

Term returnbench_frame_run(Env e, Term* f, IoWork* w) {
  id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
  NSTextView* editor = [state valueForKey:@"preview"];
  double drawing = return_bench_now();
  [editor.layoutManager ensureLayoutForBoundingRect:editor.visibleRect inTextContainer:editor.textContainer];
  [editor setNeedsDisplay:YES];
  [editor.window displayIfNeeded];
  double stopped = return_bench_now();
  [return_bench_watchdog invalidate];
  return_bench_watchdog = nil;
  if (return_bench_events != return_bench_frames + 1) return_bench_fail("frame count");
  return_bench_frames++;
  if (!editor.window || !editor.string.length ||
      ![editor.layoutManager glyphRangeForBoundingRect:editor.visibleRect
        inTextContainer:editor.textContainer].length) return_bench_fail("visible glyphs");
  printf("native_return sample=%lu elapsed_ms=%.3f drawing_ms=%.3f\n",
    (unsigned long)return_bench_frames, (stopped - return_bench_started) * 1000,
    (stopped - drawing) * 1000);
  if ([[state valueForKey:@"measurePresentation"] boolValue]) {
    printf("native_return_stage sample=%lu before_set_ms=%.3f source_update_ms=%.3f chunk_update_ms=%.3f projection_ms=%.3f\n",
      (unsigned long)return_bench_frames,
      ([[state valueForKey:@"presentationStarted"] doubleValue] - return_bench_started) * 1000,
      [[state valueForKey:@"sourceUpdateSeconds"] doubleValue] * 1000,
      [[state valueForKey:@"chunkUpdateSeconds"] doubleValue] * 1000,
      [[state valueForKey:@"projectionSeconds"] doubleValue] * 1000);
    printf("native_return_patch sample=%lu comparison_ms=%.3f storage_ms=%.3f removed=%lu inserted=%lu maximum=%lu count=%lu\n",
      (unsigned long)return_bench_frames,
      [[state valueForKey:@"projectionComparisonSeconds"] doubleValue] * 1000,
      [[state valueForKey:@"projectionStorageSeconds"] doubleValue] * 1000,
      (unsigned long)[[state valueForKey:@"projectionRemovedRange"] rangeValue].length,
      (unsigned long)[[state valueForKey:@"projectionRange"] rangeValue].length,
      (unsigned long)[[state valueForKey:@"projectionMaximumLength"] unsignedIntegerValue],
      (unsigned long)[[state valueForKey:@"projectionPatchCount"] unsignedIntegerValue]);
    NSUInteger patch = 0;
    for (NSArray<NSValue*>* ranges in [state valueForKey:@"projectionPatchRanges"]) {
      NSRange removed = ranges[0].rangeValue, inserted = ranges[1].rangeValue;
      printf("native_return_patch_range sample=%lu patch=%lu start=%lu removed=%lu inserted=%lu\n",
        (unsigned long)return_bench_frames, (unsigned long)++patch,
        (unsigned long)removed.location, (unsigned long)removed.length, (unsigned long)inserted.length);
    }
  }
  fflush(stdout);
  return f[0];
}

Term returnbench_inspect_run(Env e, Term* f, IoWork* w) {
  id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
  u64 count;
  char* bytes = io_cstr(e, f[1], &count);
  NSString* source = [[NSString alloc] initWithBytes:bytes length:count encoding:NSUTF8StringEncoding];
  free(bytes);
  NSTextView* raw = [state valueForKey:@"editor"];
  NSTextView* preview = [state valueForKey:@"preview"];
  if (!source || ![[state valueForKey:@"text"] isEqualToString:source] ||
      ![raw.string isEqualToString:source] ||
      ![preview.textStorage isEqualToAttributedString:[state valueForKey:@"rendered"]] ||
      preview.selectedRange.location != preview.string.length || preview.selectedRange.length) {
    fprintf(stderr, "source=%d raw=%d scene=%d caret=%lu visible_length=%lu selection_length=%lu\n",
      [[state valueForKey:@"text"] isEqualToString:source], [raw.string isEqualToString:source],
      [preview.textStorage isEqualToAttributedString:[state valueForKey:@"rendered"]],
      (unsigned long)preview.selectedRange.location, (unsigned long)preview.string.length,
      (unsigned long)preview.selectedRange.length);
    return_bench_fail("exact source, scene, or selection");
  }
  NSRange glyphs = [preview.layoutManager glyphRangeForCharacterRange:
    NSMakeRange(preview.string.length - 1, 1) actualCharacterRange:NULL];
  NSRect caret = [preview.layoutManager boundingRectForGlyphRange:glyphs inTextContainer:preview.textContainer];
  caret.origin.x += preview.textContainerInset.width;
  caret.origin.y += preview.textContainerInset.height;
  if (!NSIntersectsRect(caret, preview.visibleRect)) return_bench_fail("result caret outside viewport");
  return f[0];
}

Term returnbench_done_run(Env e, Term* f, IoWork* w) {
  if (return_bench_events != 20 || return_bench_frames != 20 || return_bench_watchdog)
    return_bench_fail("complete sample count");
  return f[0];
}

static void __attribute__((constructor)) return_bench_use(void) {
  io_eff(CID(ReturnBench.initialize), returnbench_initialize_run, 0);
  io_eff(CID(ReturnBench.prepare), returnbench_prepare_run, 0);
  io_eff(CID(ReturnBench.enqueue), returnbench_enqueue_run, 0);
  io_eff(CID(ReturnBench.frame), returnbench_frame_run, 0);
  io_eff(CID(ReturnBench.inspect), returnbench_inspect_run, 0);
  io_eff(CID(ReturnBench.done), returnbench_done_run, 0);
}
