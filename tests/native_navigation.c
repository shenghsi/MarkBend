#import <Cocoa/Cocoa.h>

static NSTimer* navigation_timeout;
static u32 navigation_wrapped_expected;

Term navigation_expected_run(Env e, Term* f, IoWork* w) {
  return (Term)navigation_wrapped_expected;
}

static void navigation_visible(NSTextView* editor) {
  NSRange selected = editor.selectedRange;
  if (selected.length || !editor.string.length) return;
  NSUInteger character = selected.location ? selected.location - 1 : 0;
  NSRange glyph = [editor.layoutManager glyphRangeForCharacterRange:NSMakeRange(character, 1)
    actualCharacterRange:NULL];
  [editor.layoutManager ensureLayoutForGlyphRange:glyph];
  NSRect bounds = [editor.layoutManager boundingRectForGlyphRange:glyph inTextContainer:editor.textContainer];
  bounds.origin.x += editor.textContainerInset.width;
  bounds.origin.y += editor.textContainerInset.height;
  if (!NSIntersectsRect(bounds, editor.visibleRect)) {
    fprintf(stderr, "Native navigation caret is outside the viewport at %lu\n", (unsigned long)selected.location);
    exit(1);
  }
}

Term navigation_enqueue_run(Env e, Term* f, IoWork* w) {
  id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
  u32 action = (u32)f[1];
  NSTimer* timer = [NSTimer timerWithTimeInterval:0.01 repeats:NO block:^(NSTimer* timer) {
    NSTextView* editor = [state valueForKey:@"preview"];
    if (action == 0) [editor moveToEndOfDocument:nil];
    else if (action == 1 || action == 11) [editor moveLeft:nil];
    else if (action == 3) [editor moveToBeginningOfDocumentAndModifySelection:nil];
    else if (action == 4) [editor moveToBeginningOfDocument:nil];
    else if (action == 13) [editor moveDown:nil];
    else if (action == 14 || action == 17) [editor moveUp:nil];
    else if (action == 18) editor.selectedRange = NSMakeRange(17, 0);
    else if (action == 19) editor.selectedRange = NSMakeRange(12, 0);
    else if (action == 16) {
      NSRange original = editor.selectedRange;
      NSString* source = editor.string.copy;
      NSLayoutManager* layout = editor.layoutManager;
      [layout ensureLayoutForTextContainer:editor.textContainer];
      NSUInteger glyph = [layout glyphIndexForCharacterAtIndex:original.location];
      NSRange line;
      [layout lineFragmentRectForGlyphAtIndex:glyph effectiveRange:&line];
      NSUInteger lineStart = [layout characterIndexForGlyphAtIndex:line.location];
      NSUInteger column = original.location - lineStart;
      NSUInteger expected = [layout characterIndexForGlyphAtIndex:NSMaxRange(line)] + column;
      navigation_wrapped_expected = (u32)expected;
      [editor moveDown:nil];
      if (!NSEqualRanges(editor.selectedRange, NSMakeRange(expected, 0)) ||
          expected <= original.location || ![editor.string isEqualToString:source]) {
        fprintf(stderr, "Native wrapped Down failed: expected %lu, actual %lu\n",
          (unsigned long)expected, (unsigned long)editor.selectedRange.location);
        exit(1);
      }
      navigation_visible(editor);
    }
    else if (action == 15) {
      NSWindow* window = editor.window;
      NSRect original = window.frame;
      NSRange selection = editor.selectedRange;
      NSString* source = editor.string.copy;
      BOOL updating = [[state valueForKey:@"updating"] boolValue];
      [state setValue:@YES forKey:@"updating"];
      for (unsigned i = 0; i < 3; i++) {
        NSRect frame = original;
        if (i < 2) {
          frame.size.width += i ? 240 : 120;
          frame.size.height += i ? 160 : 80;
        }
        [window setFrame:frame display:YES];
        [window.contentView layoutSubtreeIfNeeded];
        [editor scrollRangeToVisible:selection];
        if (!NSEqualRanges(selection, editor.selectedRange) || ![editor.string isEqualToString:source]) {
          fprintf(stderr, "Native window resize changed source or selection\n");
          exit(1);
        }
        navigation_visible(editor);
      }
      [state setValue:@(updating) forKey:@"updating"];
      [state textViewDidChangeSelection:[NSNotification notificationWithName:NSTextViewDidChangeSelectionNotification object:editor]];
    }
    else if (action == 12) {
      NSScrollView* scroll = editor.enclosingScrollView;
      NSRect original = scroll.frame;
      NSRange selection = editor.selectedRange;
      NSString* source = editor.string.copy;
      BOOL updating = [[state valueForKey:@"updating"] boolValue];
      [state setValue:@YES forKey:@"updating"];
      NSSize sizes[] = {NSMakeSize(340, 120), NSMakeSize(600, 180), original.size};
      for (unsigned i = 0; i < 3; i++) {
        [scroll setFrameSize:sizes[i]];
        [scroll tile];
        [editor setFrameSize:NSMakeSize(scroll.contentSize.width, MAX(editor.frame.size.height, scroll.contentSize.height))];
        [editor scrollRangeToVisible:selection];
        [editor.layoutManager ensureLayoutForBoundingRect:editor.visibleRect inTextContainer:editor.textContainer];
        [editor.window displayIfNeeded];
        if (!NSEqualRanges(selection, editor.selectedRange) || ![editor.string isEqualToString:source]) {
          fprintf(stderr, "Native resize changed source or selection\n");
          exit(1);
        }
        NSRange first = [editor.layoutManager glyphRangeForCharacterRange:NSMakeRange(12, 1) actualCharacterRange:NULL];
        NSRange last = [editor.layoutManager glyphRangeForCharacterRange:NSMakeRange(editor.string.length - 1, 1) actualCharacterRange:NULL];
        [editor.layoutManager ensureLayoutForGlyphRange:last];
        NSRect firstBounds = [editor.layoutManager boundingRectForGlyphRange:first inTextContainer:editor.textContainer];
        NSRect lastBounds = [editor.layoutManager boundingRectForGlyphRange:last inTextContainer:editor.textContainer];
        if (lastBounds.origin.y <= NSMaxY(firstBounds)) {
          fprintf(stderr, "Native long line did not wrap after resize\n");
          exit(1);
        }
        navigation_visible(editor);
      }
      [state setValue:@(updating) forKey:@"updating"];
      [state textViewDidChangeSelection:[NSNotification notificationWithName:NSTextViewDidChangeSelectionNotification object:editor]];
    } else [editor moveRight:nil];
  }];
  [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSModalPanelRunLoopMode];
  navigation_timeout = [NSTimer timerWithTimeInterval:10 repeats:NO block:^(NSTimer* timer) {
    fprintf(stderr, "Native navigation event timed out for action %u\n", action);
    exit(1);
  }];
  [[NSRunLoop currentRunLoop] addTimer:navigation_timeout forMode:NSModalPanelRunLoopMode];
  return f[0];
}

Term navigation_inspect_run(Env e, Term* f, IoWork* w) {
  [navigation_timeout invalidate];
  navigation_timeout = nil;
  id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
  NSTextView* editor = [state valueForKey:@"preview"];
  NSTextView* raw = [state valueForKey:@"editor"];
  u64 length;
  char* bytes = io_cstr(e, f[1], &length);
  NSString* expected = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
  free(bytes);
  NSRange selected = NSMakeRange((NSUInteger)f[2], (NSUInteger)f[3]);
  if (![editor.string isEqualToString:expected] || ![raw.string isEqualToString:expected] ||
      ![[state valueForKey:@"text"] isEqualToString:expected] || !NSEqualRanges(editor.selectedRange, selected)) {
    fprintf(stderr, "Native navigation source or selection failed: expected %lu,%lu, actual %lu,%lu\n",
      (unsigned long)selected.location, (unsigned long)selected.length,
      (unsigned long)editor.selectedRange.location, (unsigned long)editor.selectedRange.length);
    exit(1);
  }
  [editor.layoutManager ensureLayoutForBoundingRect:editor.visibleRect inTextContainer:editor.textContainer];
  [editor.window displayIfNeeded];
  navigation_visible(editor);
  return f[0];
}

static void __attribute__((constructor)) native_navigation_use(void) {
  io_eff(CID(Driver.expected), navigation_expected_run, 0);
  io_eff(CID(Driver.enqueue), navigation_enqueue_run, 0);
  io_eff(CID(Driver.inspect), navigation_inspect_run, 0);
}
