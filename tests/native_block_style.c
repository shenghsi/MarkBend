#import <Cocoa/Cocoa.h>

Term block_style_check_run(Env e, Term* f, IoWork* w) {
  id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
  NSTextView* editor = [state valueForKey:@"preview"];
  NSFont* heading = [editor.textStorage attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
  NSFont* code = [editor.textStorage attribute:NSFontAttributeName atIndex:3 effectiveRange:NULL];
  if (heading.pointSize != 32 ||
    ([[NSFontManager sharedFontManager] traitsOfFont:heading] & NSBoldFontMask) == 0 ||
    ([[NSFontManager sharedFontManager] traitsOfFont:code] & NSFixedPitchFontMask) == 0 ||
    !editor.textContainer.widthTracksTextView || !editor.enclosingScrollView.hasVerticalScroller) {
    fprintf(stderr, "Native block style failed\n");
    exit(1);
  }
  return f[0];
}

static void __attribute__((constructor)) native_block_style_use(void) {
  io_eff(CID(BlockStyle.check), block_style_check_run, 0);
}
