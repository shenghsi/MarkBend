#import <Cocoa/Cocoa.h>
@class MarkBendLiveState;
static NSDictionary* live_paragraph_attributes(MarkBendLiveState* state, u32 style);

Term patchdriver_inspect_run(Env e, Term* f, IoWork* w) {
  id state = (__bridge id)(void*)(intptr_t)io_hand_v(f[0]);
  NSMutableAttributedString* expected = [NSMutableAttributedString new];
  Term runs = f[1];
  NSUInteger count = 0;
  // This bound applies only to the short reference fixtures in this test.
  while (term_aux(runs) == CID(Con)) {
    if (++count > 64 || term_tag(runs) != TAG_CTR) {
      fprintf(stderr, "Native Return reference run bound or list shape failed\n");
      exit(1);
    }
    Term list[2], run[2];
    spare_free(e, cls_fit(2), ctr_take(e, runs, 2, list));
    // The Bend signature supplies Run; check the shape needed by ctr_take.
    if (term_tag(list[0]) != TAG_CTR || cid_arity(term_aux(list[0])) != 2) {
      fprintf(stderr, "Native Return reference run shape failed\n");
      exit(1);
    }
    spare_free(e, cls_fit(2), ctr_take(e, list[0], 2, run));
    u64 length;
    char* bytes = io_cstr(e, run[0], &length);
    NSString* text = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
    free(bytes);
    if (!text) {
      fprintf(stderr, "Native Return reference UTF-8 failed\n");
      exit(1);
    }
    [expected appendAttributedString:[[NSAttributedString alloc] initWithString:text
      attributes:live_paragraph_attributes(state, (u32)run[1])]];
    runs = list[1];
  }
  if (term_aux(runs) != CID(Nil)) {
    fprintf(stderr, "Native Return reference list terminator failed\n");
    exit(1);
  }
  NSTextView* editor = [state valueForKey:@"preview"];
  if (![editor.textStorage isEqualToAttributedString:expected] ||
      editor.selectedRange.location != expected.length || editor.selectedRange.length != 0) {
    fprintf(stderr, "Native Return differs from independent full attributed scene\n");
    exit(1);
  }
  return f[0];
}

static void __attribute__((constructor)) return_patch_use(void) {
  io_eff(CID(PatchDriver.inspect), patchdriver_inspect_run, 0);
}
