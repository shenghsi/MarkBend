#import <Cocoa/Cocoa.h>
#include <time.h>
#include <mach/mach.h>

static void live_paragraph_text_edges(NSString* before, NSString* after, NSUInteger limit,
  NSUInteger* prefixResult, NSUInteger* suffixResult);

static double native_document_started;
static NSTimer* native_document_timeout;
static id native_document_edits;
static NSUInteger native_document_changed_length;
static double native_document_last_storage_edit;
static NSString* native_document_previous_projection;
static BOOL native_document_measure;
static BOOL native_document_cold;
static BOOL native_document_initial_scroll_skipped;
static double native_document_configured_at;
static double native_document_presented_at;
static unichar* native_document_source;
static NSUInteger native_document_source_length;
static NSUInteger native_document_source_edits;
static double native_document_input_seconds;

static double native_document_now(void) {
  struct timespec value;
  clock_gettime(CLOCK_MONOTONIC, &value);
  return (double)value.tv_sec + (double)value.tv_nsec / 1e9;
}

Term native_document_begin_run(Env e, Term* f, IoWork* w) {
  native_document_measure = (f[0] & 1) != 0;
  native_document_cold = (f[0] & 2) != 0;
  native_document_initial_scroll_skipped = NO;
  native_document_started = native_document_now();
  return term_pak(CID(Unit), 0);
}

Term native_document_configure_run(Env e, Term* f, IoWork* w) {
  id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
  [state setValue:@(native_document_measure) forKey:@"measurePresentation"];
  if (native_document_measure) native_document_configured_at = native_document_now();
  return f[0];
}

Term native_document_presented_run(Env e, Term* f, IoWork* w) {
  if (native_document_measure) {
    id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
    native_document_presented_at = native_document_now();
    printf("native_open_stage_ms before_presentation=%.3f presentation=%.3f source_update=%.3f chunks=%.3f projection=%.3f\n",
      (native_document_configured_at - native_document_started) * 1000,
      (native_document_presented_at - native_document_configured_at) * 1000,
      [[state valueForKey:@"sourceUpdateSeconds"] doubleValue] * 1000,
      [[state valueForKey:@"chunkUpdateSeconds"] doubleValue] * 1000,
      [[state valueForKey:@"projectionSeconds"] doubleValue] * 1000);
    printf("native_open_chunk_stage_ms conversion=%.3f styled_runs=%.3f copies=%.3f assembly=%.3f\n",
      [[state valueForKey:@"textConvertSeconds"] doubleValue] * 1000,
      [[state valueForKey:@"styledRunSeconds"] doubleValue] * 1000,
      [[state valueForKey:@"chunkCopySeconds"] doubleValue] * 1000,
      [[state valueForKey:@"sceneAssemblySeconds"] doubleValue] * 1000);
  }
  return f[0];
}

Term native_document_enqueue_run(Env e, Term* f, IoWork* w) {
  id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
  [state setValue:@(native_document_measure) forKey:@"measurePresentation"];
  u32 action = (u32)f[1];
  if (action != 0 && native_document_edits == nil) {
    NSTextView* editor = [state valueForKey:@"preview"];
    native_document_edits = [[NSNotificationCenter defaultCenter]
      addObserverForName:NSTextStorageDidProcessEditingNotification object:editor.textStorage
      queue:nil usingBlock:^(NSNotification* notification) {
        NSTextStorage* storage = notification.object;
        native_document_changed_length = MAX(native_document_changed_length, storage.editedRange.length);
        native_document_last_storage_edit = native_document_now();
      }];
  }
  NSTimer* actionTimer = [NSTimer timerWithTimeInterval:0.001 repeats:NO block:^(NSTimer* timer) {
    NSTextView* editor = [state valueForKey:@"preview"];
    if (action == 0) {
      // Wake the initial modal loop with its unchanged native selection.
      [state setValue:[NSValue valueWithRange:editor.selectedRange] forKey:@"pendingRange"];
      [state setValue:@(NSAlertFirstButtonReturn + 4) forKey:@"response"];
      [NSApp stopModal];
    } else {
      native_document_started = native_document_now();
      native_document_changed_length = 0;
      [state setValue:@0 forKey:@"projectionCount"];
      [state setValue:@0 forKey:@"projectionMaximumLength"];
      native_document_previous_projection = [[state valueForKey:@"rendered"] string].copy;
      double inputStarted = native_document_measure ? native_document_now() : 0;
      [editor insertText:@"X" replacementRange:NSMakeRange(editor.string.length, 0)];
      if (native_document_measure) native_document_input_seconds = native_document_now() - inputStarted;
    }
  }];
  [[NSRunLoop currentRunLoop] addTimer:actionTimer forMode:NSModalPanelRunLoopMode];
  native_document_timeout = [NSTimer timerWithTimeInterval:30 repeats:NO block:^(NSTimer* timer) {
    fprintf(stderr, "Native document event timed out\n");
    exit(1);
  }];
  [[NSRunLoop currentRunLoop] addTimer:native_document_timeout forMode:NSModalPanelRunLoopMode];
  return f[0];
}

Term native_document_frame_run(Env e, Term* f, IoWork* w) {
  [native_document_timeout invalidate];
  native_document_timeout = nil;
  id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
  NSTextView* editor = [state valueForKey:@"preview"];
  if (!editor.window || editor.string.length == 0) {
    fprintf(stderr, "Native document has no readable surface\n");
    exit(1);
  }
  double drawingStarted = native_document_measure ? native_document_now() : 0;
  [editor.layoutManager ensureLayoutForBoundingRect:editor.visibleRect inTextContainer:editor.textContainer];
  [editor setNeedsDisplay:YES];
  [editor.window displayIfNeeded];
  double drawingSeconds = native_document_measure ? native_document_now() - drawingStarted : 0;
  NSRange glyphs = [editor.layoutManager glyphRangeForBoundingRect:editor.visibleRect
    inTextContainer:editor.textContainer];
  if (glyphs.length == 0) {
    fprintf(stderr, "Native document viewport has no glyphs\n");
    exit(1);
  }
  if (f[1] != 0) {
    NSRange caretCharacter = NSMakeRange(editor.string.length - 1, 1);
    NSRange caretGlyph = [editor.layoutManager glyphRangeForCharacterRange:caretCharacter actualCharacterRange:NULL];
    NSRect caretBounds = [editor.layoutManager boundingRectForGlyphRange:caretGlyph inTextContainer:editor.textContainer];
    caretBounds.origin.x += editor.textContainerInset.width;
    caretBounds.origin.y += editor.textContainerInset.height;
    if (!NSIntersectsRect(caretBounds, editor.visibleRect)) {
      fprintf(stderr, "Native document edit caret is outside the viewport\n");
      exit(1);
    }
  }
  printf("native_%s_frame_ms=%.3f\n", f[1] == 0 ? "open" : "edit",
    (native_document_now() - native_document_started) * 1000);
  if (f[1] == 0) {
    if (native_document_measure) printf("native_open_surface_ms=%.3f\n",
      (native_document_now() - native_document_presented_at) * 1000);
    NSString* source = [state valueForKey:@"text"];
    native_document_source_length = source.length;
    free(native_document_source);
    native_document_source = malloc(source.length * sizeof(unichar));
    if (source.length && !native_document_source) {
      fprintf(stderr, "Native source reference allocation failed\n");
      exit(1);
    }
    [source getCharacters:native_document_source range:NSMakeRange(0, source.length)];
    native_document_source_edits = 0;
    struct mach_task_basic_info memory;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO,
      (task_info_t)&memory, &count) != KERN_SUCCESS) {
      fprintf(stderr, "Native document memory query failed\n");
      exit(1);
    }
    printf("native_open_resident_bytes=%llu\n", (unsigned long long)memory.resident_size);
  }
  NSAttributedString* expected = [state valueForKey:@"rendered"];
  if (![editor.textStorage isEqualToAttributedString:expected] ||
    (f[1] != 0 && (editor.selectedRange.location != editor.string.length ||
      editor.selectedRange.length != 0))) {
    fprintf(stderr, "Native document projection or cursor failed\n");
    exit(1);
  }
  if (f[1] != 0) {
    NSString* source = [state valueForKey:@"text"];
    NSTextView* raw = [state valueForKey:@"editor"];
    native_document_source_edits++;
    unichar* actual = malloc(source.length * sizeof(unichar));
    if (source.length && !actual) {
      fprintf(stderr, "Native source check allocation failed\n");
      exit(1);
    }
    [source getCharacters:actual range:NSMakeRange(0, source.length)];
    BOOL sourceMatches = source.length == native_document_source_length + native_document_source_edits &&
      memcmp(actual, native_document_source, native_document_source_length * sizeof(unichar)) == 0 &&
      [raw.string isEqualToString:source];
    for (NSUInteger i = native_document_source_length; sourceMatches && i < source.length; i++)
      sourceMatches = actual[i] == 'X';
    free(actual);
    if (!sourceMatches) {
      NSUInteger mismatch = 0;
      while (mismatch < MIN(source.length, native_document_source_length) &&
        [source characterAtIndex:mismatch] == native_document_source[mismatch]) mismatch++;
      fprintf(stderr, "Native source range update failed: edit=%lu source_length=%lu expected_length=%lu raw_equal=%d first_prefix_mismatch=%lu\n",
        (unsigned long)native_document_source_edits, (unsigned long)source.length,
        (unsigned long)(native_document_source_length + native_document_source_edits),
        [raw.string isEqualToString:source], (unsigned long)mismatch);
      exit(1);
    }
    NSUInteger rebuilt = [[state valueForKey:@"nativeChunksRebuilt"] unsignedIntegerValue];
    NSUInteger reused = [[state valueForKey:@"nativeChunksReused"] unsignedIntegerValue];
    NSUInteger retained = [[state valueForKey:@"nativeChunks"] count];
    NSUInteger transferred = [[state valueForKey:@"nativeChunksTransferred"] unsignedIntegerValue];
    NSUInteger ordered = [[state valueForKey:@"nativeOrder"] count];
    NSUInteger comparisons = [[state valueForKey:@"projectionFullComparisons"] unsignedIntegerValue];
    BOOL projected = [[state valueForKey:@"projectionPatchesApplied"] boolValue];
    NSUInteger inputComparisons = [[state valueForKey:@"inputFullComparisons"] unsignedIntegerValue];
    NSUInteger rangeUpdates = [[state valueForKey:@"inputRangeUpdates"] unsignedIntegerValue];
    if (rebuilt > 2 || reused == 0 || retained != rebuilt + reused ||
        ordered != retained || transferred == 0 || transferred > 4 || comparisons != 0 || !projected ||
        inputComparisons != 0 || rangeUpdates < native_document_source_edits) {
      fprintf(stderr, "Native block reuse or cache bound failed\n");
      exit(1);
    }
    printf("native_chunks rebuilt=%lu reused=%lu retained=%lu transferred=%lu\n",
      (unsigned long)rebuilt, (unsigned long)reused, (unsigned long)retained, (unsigned long)transferred);
    printf("native_projection_full_comparisons=%lu\n", (unsigned long)comparisons);
    printf("native_input_full_comparisons=%lu range_updates=%lu\n",
      (unsigned long)inputComparisons, (unsigned long)rangeUpdates);
    if (native_document_measure) {
      printf("native_surface_stage_ms input=%.3f drawing=%.3f viewport_y=%.3f\n",
        native_document_input_seconds * 1000, drawingSeconds * 1000, editor.visibleRect.origin.y);
      double beforeSet = [[state valueForKey:@"presentationStarted"] doubleValue] - native_document_started;
      double sourceUpdate = [[state valueForKey:@"sourceUpdateSeconds"] doubleValue];
      double runBuild = [[state valueForKey:@"runBuildSeconds"] doubleValue];
      double projection = [[state valueForKey:@"projectionSeconds"] doubleValue];
      double chunkUpdate = [[state valueForKey:@"chunkUpdateSeconds"] doubleValue];
      NSUInteger runs = [[state valueForKey:@"presentationRunCount"] unsignedIntegerValue];
      if (beforeSet < 0 || sourceUpdate < 0 || runBuild < 0 || projection < 0 || chunkUpdate < 0 || runs == 0) {
        fprintf(stderr, "Native presentation clock failed\n");
        exit(1);
      }
      printf("native_stage_ms before_set=%.3f source_update=%.3f run_build=%.3f chunk_update=%.3f projection=%.3f runs=%lu\n",
        beforeSet * 1000, sourceUpdate * 1000, runBuild * 1000, chunkUpdate * 1000, projection * 1000,
        (unsigned long)runs);
      printf("native_source_stage_ms lookup=%.3f compare=%.3f copy=%.3f storage=%.3f selection=%.3f\n",
        [[state valueForKey:@"sourceLookupSeconds"] doubleValue] * 1000,
        [[state valueForKey:@"sourceCompareSeconds"] doubleValue] * 1000,
        [[state valueForKey:@"sourceCopySeconds"] doubleValue] * 1000,
        [[state valueForKey:@"sourceStorageSeconds"] doubleValue] * 1000,
        [[state valueForKey:@"sourceSelectionSeconds"] doubleValue] * 1000);
    }
    NSRange projectionRange = [[state valueForKey:@"projectionRange"] rangeValue];
    NSRange removedRange = [[state valueForKey:@"projectionRemovedRange"] rangeValue];
    printf("native_projection_range_start=%lu length=%lu\n",
      (unsigned long)projectionRange.location, (unsigned long)projectionRange.length);
    printf("native_projection_removed_start=%lu length=%lu\n",
      (unsigned long)removedRange.location, (unsigned long)removedRange.length);
    printf("native_projection_count=%lu maximum_length=%lu\n",
      (unsigned long)[[state valueForKey:@"projectionCount"] unsignedIntegerValue],
      (unsigned long)[[state valueForKey:@"projectionMaximumLength"] unsignedIntegerValue]);
    printf("native_projection_patch_count=%lu\n",
      (unsigned long)[[state valueForKey:@"projectionPatchCount"] unsignedIntegerValue]);
    printf("native_projection_before_length=%lu after_length=%lu before_first=%lu after_first=%lu\n",
      (unsigned long)[[state valueForKey:@"projectionBeforeLength"] unsignedIntegerValue],
      (unsigned long)[[state valueForKey:@"projectionAfterLength"] unsignedIntegerValue],
      (unsigned long)[[state valueForKey:@"projectionBeforeFirst"] unsignedIntegerValue],
      (unsigned long)[[state valueForKey:@"projectionAfterFirst"] unsignedIntegerValue]);
    NSUInteger prefix, suffix;
    live_paragraph_text_edges(native_document_previous_projection, expected.string,
      NSUIntegerMax, &prefix, &suffix);
    printf("projection_text_prefix=%lu suffix=%lu old_changed=%lu new_changed=%lu\n",
      (unsigned long)prefix, (unsigned long)suffix,
      (unsigned long)(native_document_previous_projection.length - prefix - suffix),
      (unsigned long)(expected.length - prefix - suffix));
    if (prefix == 0 && native_document_previous_projection.length && expected.length) {
      printf("projection_first_unit_before=%u after=%u\n",
        [native_document_previous_projection characterAtIndex:0],
        [expected.string characterAtIndex:0]);
    }
    native_document_previous_projection = nil;
    printf("native_storage_changed_length=%lu storage_edit_ms=%.3f\n",
      (unsigned long)native_document_changed_length,
      (native_document_last_storage_edit - native_document_started) * 1000);
  }
  fflush(stdout);
  return f[0];
}

Term native_document_scroll_run(Env e, Term* f, IoWork* w) {
  if (native_document_cold && !native_document_initial_scroll_skipped &&
      native_document_source_edits == 0) {
    native_document_initial_scroll_skipped = YES;
    printf("native_initial_scroll_skipped=1\n");
    return f[0];
  }
  id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
  NSTextView* editor = [state valueForKey:@"preview"];
  NSScrollView* scroll = editor.enclosingScrollView;
  BOOL updating = [[state valueForKey:@"updating"] boolValue];
  [state setValue:@YES forKey:@"updating"];
  double start = native_document_now();
  [editor.layoutManager ensureLayoutForTextContainer:editor.textContainer];
  NSUInteger positions[] = {editor.string.length - 1, editor.string.length / 2, 0};
  for (unsigned i = 0; i < 3; i++) {
    NSRange character = NSMakeRange(positions[i], 1);
    [editor scrollRangeToVisible:character];
    NSRange glyph = [editor.layoutManager glyphRangeForCharacterRange:character actualCharacterRange:NULL];
    NSRect bounds = [editor.layoutManager boundingRectForGlyphRange:glyph inTextContainer:editor.textContainer];
    bounds.origin.x += editor.textContainerInset.width;
    bounds.origin.y += editor.textContainerInset.height;
    if (!NSIntersectsRect(bounds, editor.visibleRect) ||
      (i == 0 && scroll.contentView.bounds.origin.y <= 0)) {
      fprintf(stderr, "Native document scroll failed at position %lu; view y=%.2f height=%.2f\n",
        (unsigned long)positions[i], scroll.contentView.bounds.origin.y, editor.frame.size.height);
      exit(1);
    }
  }
  [state setValue:@(updating) forKey:@"updating"];
  if (native_document_edits != nil) {
    [[NSNotificationCenter defaultCenter] removeObserver:native_document_edits];
    native_document_edits = nil;
  }
  printf("native_scroll_layout_ms=%.3f\n", (native_document_now() - start) * 1000);
  fflush(stdout);
  return f[0];
}

static void __attribute__((constructor)) native_document_use(void) {
  io_eff(CID(NativeDocument.begin), native_document_begin_run, 0);
  io_eff(CID(NativeDocument.enqueue), native_document_enqueue_run, 0);
  io_eff(CID(NativeDocument.configure), native_document_configure_run, 0);
  io_eff(CID(NativeDocument.presented), native_document_presented_run, 0);
  io_eff(CID(NativeDocument.frame), native_document_frame_run, 0);
  io_eff(CID(NativeDocument.scroll), native_document_scroll_run, 0);
}
