#include "linux_host_syntax.c"
#include <assert.h>

#if defined(__APPLE__)
@interface MarkBendTestEditor : MarkBendEditor
@property(nonatomic) BOOL composing;
@end
@implementation MarkBendTestEditor
- (BOOL)hasMarkedText { return self.composing; }
@end

static NSEvent* history_key(BOOL redo) {
  return [NSEvent keyEventWithType:NSEventTypeKeyDown
    location:NSZeroPoint
    modifierFlags:NSEventModifierFlagCommand | (redo ? NSEventModifierFlagShift : 0)
    timestamp:0 windowNumber:0 context:nil characters:@"z"
    charactersIgnoringModifiers:@"z" isARepeat:NO keyCode:6];
}

static void check_return_composition(void) {
  MarkBendLiveState* state = [MarkBendLiveState new];
  MarkBendTestEditor* editor = [[MarkBendTestEditor alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
  editor.session = state;
  state.direct = YES;
  state.preview = editor;
  editor.string = @"x";
  editor.selectedRange = NSMakeRange(1, 0);
  editor.composing = YES;
  state.response = 123;
  [editor insertNewline:nil];
  assert(state.response == 123);
  editor.composing = NO;
  NSString* before = editor.string.copy;
  NSRange selected = editor.selectedRange;
  [editor insertNewline:nil];
  assert(state.response == NSAlertFirstButtonReturn + 9);
  assert(NSEqualRanges(state.pendingRange, selected));
  assert([editor.string isEqualToString:before]);
}

// Native fallback font objects can differ even when they name the same face.
// Compare full attributes and the displayed font face, size, and traits.
static BOOL same_native_projection(NSAttributedString* a, NSAttributedString* b) {
  if (![a.string isEqualToString:b.string]) return NO;
  for (NSUInteger index = 0; index < a.length; index++) {
    NSMutableDictionary* left = [[a attributesAtIndex:index effectiveRange:NULL] mutableCopy];
    NSMutableDictionary* right = [[b attributesAtIndex:index effectiveRange:NULL] mutableCopy];
    NSFont* leftFont = left[NSFontAttributeName];
    NSFont* rightFont = right[NSFontAttributeName];
    if (![leftFont.fontName isEqualToString:rightFont.fontName] ||
      leftFont.pointSize != rightFont.pointSize ||
      leftFont.fontDescriptor.symbolicTraits != rightFont.fontDescriptor.symbolicTraits) return NO;
    [left removeObjectForKey:NSFontAttributeName];
    [right removeObjectForKey:NSFontAttributeName];
    if (![left isEqual:right]) return NO;
  }
  return YES;
}

static void check_projection_translation(void) {
  NSString* base = @"abcdefgh";
  NSArray* texts = @[@"", @"Q", @"😀"];
  for (NSUInteger e = 0; e <= base.length; e++) {
    for (NSUInteger n = 0; n <= base.length - e; n++) {
      for (NSUInteger p = 0; p <= base.length; p++) {
        for (NSUInteger k = 0; k <= base.length - p; k++) {
          for (NSString* input in texts) {
            for (NSString* replacement in texts) {
              NSRange edit = NSMakeRange(e, n), patch = NSMakeRange(p, k), actual;
              BOOL pending = YES;
              if (!live_paragraph_projection_range(patch, replacement.length,
                  &pending, &edit, input.length, &actual)) continue;
              NSString* field = [base stringByReplacingCharactersInRange:NSMakeRange(e, n) withString:input];
              NSString* scene = [base stringByReplacingCharactersInRange:patch withString:replacement];
              NSString* expected = pending ? [scene stringByReplacingCharactersInRange:edit withString:input] : scene;
              assert(NSMaxRange(actual) <= field.length);
              assert([[field stringByReplacingCharactersInRange:actual withString:replacement] isEqualToString:expected]);
            }
          }
        }
      }
    }
  }
}

static void check_input_ranges(void) {
  NSArray* sources = @[@"abc", @"a😀b", @"aéb", @"a👩‍💻b", @"a\r\nb", @"🇹🇼🇺🇸"];
  NSArray* inputs = @[@"", @"Q", @"😀", @"́", @"‍", @"🇯🇵"];
  for (NSString* before in sources) {
    for (NSUInteger start = 0; start <= before.length; start++) {
      if (start && start < before.length && CFStringIsSurrogateLowCharacter([before characterAtIndex:start])) continue;
      for (NSUInteger end = start; end <= before.length; end++) {
        if (end && end < before.length && CFStringIsSurrogateLowCharacter([before characterAtIndex:end])) continue;
        for (NSString* input in inputs) {
          NSRange removed = NSMakeRange(start, end - start);
          NSString* after = [before stringByReplacingCharactersInRange:removed withString:input];
          NSRange inserted = NSMakeRange(start, input.length);
          removed = live_paragraph_input_range(before, after, removed, &inserted);
          assert(NSMaxRange(removed) <= before.length && NSMaxRange(inserted) <= after.length);
          assert([[before stringByReplacingCharactersInRange:removed
            withString:[after substringWithRange:inserted]] isEqualToString:after]);
          if (removed.length) assert(NSEqualRanges(removed, [before rangeOfComposedCharacterSequencesForRange:removed]));
          if (inserted.length && !NSEqualRanges(inserted, [after rangeOfComposedCharacterSequencesForRange:inserted])) {
            fprintf(stderr, "input range source=%s input=%s start=%lu end=%lu expanded=%lu,%lu\n", before.UTF8String, input.UTF8String,
              (unsigned long)start, (unsigned long)end, (unsigned long)inserted.location, (unsigned long)inserted.length);
            assert(0);
          }
        }
      }
    }
  }
}

static NSString* check_source_tree(MarkBendSourceIndex* node) {
  if (!node) return @"";
  if (node.text) {
    assert(node.height == 1 && node.nativeLength == node.text.length && node.nativeLength <= 512);
    assert(node.scalars == live_source_leaf(node.text).scalars);
    return node.text;
  }
  assert(node.left && node.right);
  assert(node.scalars == node.left.scalars + node.right.scalars);
  assert(node.nativeLength == node.left.nativeLength + node.right.nativeLength);
  assert(node.height == 1 + MAX(node.left.height, node.right.height));
  assert(labs((long)node.left.height - (long)node.right.height) <= 1);
  return [check_source_tree(node.left) stringByAppendingString:check_source_tree(node.right)];
}

static void check_source_index(void) {
  NSMutableString* source = [NSMutableString new];
  for (NSUInteger i = 0; i < 3000; i++) [source appendString:@"ab😀é\r\n👩‍💻"];
  NSString* expected = source;
  MarkBendSourceIndex* tree = live_source_build(expected);
  NSArray* inputs = @[@"Q", @"😀🇹🇼", @"", @"é\r\n", @"👩‍💻"];
  for (NSUInteger edit = 0; edit < 300; edit++) {
    assert([check_source_tree(tree) isEqualToString:expected]);
    NSUInteger start = edit % 3 == 0 ? 0 : edit % 3 == 1 ? tree.scalars / 2 : tree.scalars;
    NSUInteger end = MIN(tree.scalars, start + edit % 7);
    NSRange reference = live_paragraph_scalar_range(expected, start, end);
    NSUInteger at = live_source_native(tree, start);
    assert(at == reference.location && live_source_native(tree, end) == NSMaxRange(reference));
    NSString* input = inputs[edit % inputs.count];
    tree = live_source_replace(tree, start, end, input);
    expected = [expected stringByReplacingCharactersInRange:reference withString:input];
  }
  assert([check_source_tree(tree) isEqualToString:expected]);
  NSUInteger native = 0;
  for (NSUInteger scalar = 0; scalar <= tree.scalars; scalar++) {
    assert(live_source_native(tree, scalar) == native);
    if (native < expected.length) {
      unichar first = [expected characterAtIndex:native++];
      if (CFStringIsSurrogateHighCharacter(first) && native < expected.length &&
          CFStringIsSurrogateLowCharacter([expected characterAtIndex:native])) native++;
    }
  }
  assert(live_source_native(tree, tree.scalars + 1) == expected.length);
  tree = live_source_replace(tree, 0, tree.scalars, @"");
  assert(!tree);
  tree = live_source_replace(tree, 0, 0, @"😀");
  assert(tree.scalars == 1 && tree.nativeLength == 2);
}

static void check_projected_field(MarkBendLiveState* state) {
  NSTextStorage* reference = [[NSTextStorage alloc] init];
  [reference setAttributedString:state.rendered];
  [reference fixAttributesInRange:NSMakeRange(0, reference.length)];
  assert(same_native_projection(state.preview.textStorage, reference));
}
#endif

Term io_hand(intptr_t value) { return (Term)value; }
intptr_t io_hand_v(Term value) { return (intptr_t)value; }
char* io_cstr(Env environment, Term value, u64* length) {
  const char* text = (const char*)(uintptr_t)value;
  *length = strlen(text);
  return strdup(text);
}
Term io_box(Env e, u64 c, Term value) { return value; }
Term io_node(Env e, u64 c, Term first, Term second) { return first; }
Term io_str(Env e, const char* text, u64 length) { return 0; }
Term io_tup(Env e, Term first, Term second) { return first; }
Term term_pak(u64 constructor, u64 location) { return 0; }
Term term_ctr(u64 constructor, u64 location) { return 0; }
u64 heap_alloc(Env e, u64 size_class) { return 0; }
Term io_seal(Env e, Term value, u64 constructor) { return value; }
void io_eff(u64 effect, Effect run, int need) {}
void err_fail(const char* message) { abort(); }
u64 term_aux(Term value) { return value == 0 ? 0 : 1; }
u64 cls_fit(u64 fields) { return fields; }
u64 ctr_take(Env e, Term value, u32 fields, Term* output) {
  memcpy(output, (void*)(uintptr_t)value, fields * sizeof(Term));
  return value;
}
void spare_free(Env e, u64 size_class, u64 location) { free((void*)(uintptr_t)location); }
void term_sink(Env e, Term value) {
  while (value != 0) {
    Term* list = (Term*)(uintptr_t)value;
    Term next = list[1];
    free((void*)(uintptr_t)list[0]);
    free(list);
    value = next;
  }
}

static Term mock_pair(Term first, Term second) {
  Term* fields = malloc(2 * sizeof(Term));
  assert(fields != NULL);
  fields[0] = first;
  fields[1] = second;
  return (Term)(uintptr_t)fields;
}

static Term mock_chunk(u64 id, u64 fresh, const char* text, Term tail) {
  Term runs = mock_pair(mock_pair((Term)(uintptr_t)text, 0), 0);
  Term* chunk = malloc(3 * sizeof(Term));
  assert(chunk != NULL);
  chunk[0] = id; chunk[1] = fresh; chunk[2] = runs;
  return mock_pair((Term)(uintptr_t)chunk, tail);
}

static Term mock_styled_chunk(u64 id, u64 fresh, const char* text, u64 style, Term tail) {
  Term result = mock_chunk(id, fresh, text, tail);
  Term* list = (void*)(uintptr_t)result;
  Term* chunk = (void*)(uintptr_t)list[0];
  Term* runs = (void*)(uintptr_t)chunk[2];
  Term* run = (void*)(uintptr_t)runs[0];
  run[1] = style;
  return result;
}

static Term mock_patch(u64 first, u64 removed, u64 start, u64 length, Term chunks, Term tail) {
  Term* patch = malloc(5 * sizeof(Term));
  assert(patch);
  patch[0] = first; patch[1] = removed; patch[2] = start; patch[3] = length; patch[4] = chunks;
  return mock_pair((Term)(uintptr_t)patch, tail);
}

int main(void) {
#if defined(__APPLE__)
  NSArray<NSString*>* utf8_cases = @[@"\uFEFFa", @"\uFEFF\uFEFFa", @"a\uFEFFb",
    @"\uFEFF", @"\uFEFF\r\né\0x", @"中文😀\r\né\0x"];
  for (NSString* expected in utf8_cases) {
    NSData* bytes = [expected dataUsingEncoding:NSUTF8StringEncoding];
    NSString* decoded = live_paragraph_utf8(bytes.bytes, bytes.length);
    assert([[decoded dataUsingEncoding:NSUTF8StringEncoding] isEqualToData:bytes]);
  }
#endif
  Env e = {0};
  IoWork work = {0};
  Term args[3] = {(Term)(uintptr_t)"initial", 0, 0};
  Term handle = live_paragraph_open_run(e, args, &work);
  args[0] = handle;
  args[1] = (Term)(uintptr_t)"中文 **one**\n**two**";
  live_paragraph_set_run(e, args, &work);
  const char* texts[] = {"中文 ", "one", "\n", "two"};
  for (int i = 0; i < 4; i++) {
    args[1] = (Term)(uintptr_t)texts[i];
    args[2] = i % 2;
    live_paragraph_append_run(e, args, &work);
  }
#if defined(__APPLE__)
  MarkBendLiveState* state = (__bridge MarkBendLiveState*)(void*)(uintptr_t)handle;
  check_return_composition();
  assert([state.text isEqualToString:@"中文 **one**\n**two**"]);
  assert([state.rendered.string isEqualToString:@"中文 one\ntwo"]);
  NSFont* plain = [state.rendered attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
  NSFont* bold = [state.rendered attribute:NSFontAttributeName atIndex:3 effectiveRange:NULL];
  assert(([[NSFontManager sharedFontManager] traitsOfFont:plain] & NSBoldFontMask) == 0);
  assert(([[NSFontManager sharedFontManager] traitsOfFont:bold] & NSBoldFontMask) != 0);
  for (NSUInteger index = 0; index < state.rendered.length; index++) {
    NSColor* color = [state.rendered attribute:NSForegroundColorAttributeName
      atIndex:index effectiveRange:NULL];
    assert([color isEqual:NSColor.textColor]);
  }
  MarkBendTestEditor* editor = [[MarkBendTestEditor alloc]
    initWithFrame:NSMakeRect(0, 0, 100, 100)];
  editor.session = state;
  state.editor = editor;
  state.editor.string = state.text;
  state.editor.selectedRange = NSMakeRange(3, 0);
  state.editor.delegate = state;
  state.editor.textStorage.delegate = state;
  state.sourceFieldSynchronized = YES;
#else
  MarkBendLiveState* state = (void*)(uintptr_t)handle;
  assert(strcmp(state->text, "中文 **one**\n**two**") == 0);
  assert(strcmp(state->preview, "中文 \033[1mone\033[0m\n\033[1mtwo\033[0m") == 0);
#endif
  args[1] = (Term)(uintptr_t)"unfinished **";
  live_paragraph_set_run(e, args, &work);
  args[2] = 0;
  live_paragraph_append_run(e, args, &work);
#if defined(__APPLE__)
  assert([state.rendered.string isEqualToString:@"unfinished **"]);
  assert(state.editor.selectedRange.location == 3);
  state.response = 123;
  state.updating = YES;
  [state textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification
    object:state.editor]];
  assert(state.response == 123);
  state.updating = NO;
  assert([editor performKeyEquivalent:history_key(NO)]);
  assert(state.response == NSAlertSecondButtonReturn);
  assert([editor performKeyEquivalent:history_key(YES)]);
  assert(state.response == NSAlertThirdButtonReturn);
  editor.composing = YES;
  state.response = 123;
  [editor performKeyEquivalent:history_key(NO)];
  assert(state.response == 123);
  [state textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification
    object:editor]];
  assert(state.response == 123);
  editor.composing = NO;
  [state textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification
    object:editor]];
  assert(state.response == NSAlertFirstButtonReturn);
  [NSApplication sharedApplication];
  NSWindow* test_window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 100, 100)
    styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
  assert(![state windowShouldClose:test_window]);
  assert(state.response == NSAlertFirstButtonReturn + 3);
#else
  assert(strcmp(state->preview, "unfinished **") == 0);
#endif
  args[1] = (Term)(uintptr_t)"italic";
  args[2] = 2;
  live_paragraph_append_run(e, args, &work);
#if defined(__APPLE__)
  NSFont* italic = [state.rendered attribute:NSFontAttributeName
    atIndex:state.rendered.length - 1 effectiveRange:NULL];
  assert(([[NSFontManager sharedFontManager] traitsOfFont:italic] & NSItalicFontMask) != 0);
  assert(([[NSFontManager sharedFontManager] traitsOfFont:italic] & NSBoldFontMask) == 0);
#else
  assert(strcmp(state->preview, "unfinished **\033[3mitalic\033[0m") == 0);
#endif
  args[1] = (Term)(uintptr_t)"**literal**";
  args[2] = 3;
  live_paragraph_append_run(e, args, &work);
#if defined(__APPLE__)
  NSFont* code_font = [state.rendered attribute:NSFontAttributeName
    atIndex:state.rendered.length - 1 effectiveRange:NULL];
  assert(([[NSFontManager sharedFontManager] traitsOfFont:code_font] & NSFixedPitchFontMask) != 0);
#else
  assert(strstr(state->preview, "\033[7m**literal**\033[0m") != NULL);
#endif
#if defined(__APPLE__)
  MarkBendTestEditor* direct = [[MarkBendTestEditor alloc]
    initWithFrame:NSMakeRect(0, 0, 300, 200)];
  direct.session = state;
  direct.delegate = state;
  direct.allowsUndo = NO;
  state.preview = direct;
  args[1] = (Term)(uintptr_t)"**中文😀**";
  live_paragraph_set_run(e, args, &work);
  args[2] = 0;
  live_paragraph_append_run(e, args, &work);
  state.response = 123;
  args[1] = 4;
  args[2] = 6;
  live_paragraph_project_run(e, args, &work);
  assert(direct.editable);
  assert([direct.string isEqualToString:@"**中文😀**"]);
  assert(NSEqualRanges(direct.selectedRange, NSMakeRange(4, 2)));
  assert(state.response == 123); // A new scene must not send a user event.
  direct.selectedRange = NSMakeRange(2, 2);
  [state textViewDidChangeSelection:[NSNotification
    notificationWithName:NSTextViewDidChangeSelectionNotification object:direct]];
  assert(state.response == NSAlertFirstButtonReturn + 4);
  assert(NSEqualRanges(state.pendingRange, NSMakeRange(2, 2)));
  state.response = 123;
  [direct insertText:@"日\n" replacementRange:NSMakeRange(2, 2)];
  [state textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification object:direct]];
  assert(state.response == NSAlertFirstButtonReturn + 5);
  assert(NSEqualRanges(state.pendingRange, NSMakeRange(2, 2)));
  assert([state.pendingText isEqualToString:@"日\n"]);
  assert([direct.string isEqualToString:@"**日\n😀**"]);
  direct.composing = YES;
  state.response = 123;
  [state textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification object:direct]];
  assert(state.response == 123);
  direct.composing = NO;
  [direct unmarkText];
  assert(state.response == NSAlertFirstButtonReturn + 5);
  NSRange inserted;
  NSRange changed = live_paragraph_difference(@"a😀b", @"a😃b", &inserted);
  assert(NSEqualRanges(changed, NSMakeRange(1, 2)));
  assert(NSEqualRanges(inserted, NSMakeRange(1, 2)));
  changed = live_paragraph_difference(@"aéb", @"aeb", &inserted);
  assert(NSEqualRanges(changed, NSMakeRange(1, 2)));
  assert(NSEqualRanges(inserted, NSMakeRange(1, 1)));
  changed = live_paragraph_difference(@"a👩‍💻b", @"ab", &inserted);
  assert(NSEqualRanges(changed, NSMakeRange(1, 5)));
  assert(NSEqualRanges(inserted, NSMakeRange(1, 0)));
  NSArray<NSString*>* changes = @[@"", @"abc", @"a😀b", @"a😃b", @"aéb",
    @"aeb", @"a👩‍💻b", @"中文\n", @"**a**", @"a👩b", @"é", @"e"];
  for (NSString* before in changes) {
    for (NSString* after in changes) {
      changed = live_paragraph_difference(before, after, &inserted);
      NSString* replacement = [after substringWithRange:inserted];
      assert([[before stringByReplacingCharactersInRange:changed withString:replacement]
        isEqualToString:after]);
      NSMutableAttributedString* expected = [[NSMutableAttributedString alloc]
        initWithString:after attributes:live_paragraph_attributes(state, 0)];
      if (after.length) {
        NSRange cluster = [after rangeOfComposedCharacterSequenceAtIndex:after.length / 2];
        [expected setAttributes:live_paragraph_attributes(state, 1) range:cluster];
      }
      NSTextStorage* storage = [[NSTextStorage alloc] initWithString:before
        attributes:live_paragraph_attributes(state, 3)];
      live_paragraph_update_storage(storage, expected);
      NSTextStorage* reference = [[NSTextStorage alloc] init];
      [reference setAttributedString:expected];
      [reference fixAttributesInRange:NSMakeRange(0, reference.length)];
      assert(same_native_projection(storage, reference));
      // Check the bounded scene-patch comparison against a full attributed build.
      NSTextStorage* bounded = [[NSTextStorage alloc] initWithString:before
        attributes:live_paragraph_attributes(state, 3)];
      NSRange newMiddle;
      NSRange oldMiddle = live_paragraph_patch_middle(bounded, expected, &newMiddle);
      [bounded replaceCharactersInRange:oldMiddle
        withAttributedString:[expected attributedSubstringFromRange:newMiddle]];
      assert(same_native_projection(bounded, reference));
    }
  }
  // Attribute-only changes must keep the text and unchanged suffix attributes.
  NSTextStorage* same_text = [[NSTextStorage alloc] initWithString:@"a😀 é tail"
    attributes:live_paragraph_attributes(state, 0)];
  NSMutableAttributedString* changed_style = [same_text mutableCopy];
  [changed_style setAttributes:live_paragraph_attributes(state, 1) range:NSMakeRange(4, 2)];
  live_paragraph_update_storage(same_text, changed_style);
  NSTextStorage* reference_style = [[NSTextStorage alloc] init];
  [reference_style setAttributedString:changed_style];
  [reference_style fixAttributesInRange:NSMakeRange(0, reference_style.length)];
  assert(same_native_projection(same_text, reference_style));
  // Long append, then an attribute-only patch on the same current chunk.
  NSString* longText = [@"x" stringByPaddingToLength:65536 withString:@"x" startingAtIndex:0];
  NSTextStorage* longStorage = [[NSTextStorage alloc] initWithString:longText
    attributes:live_paragraph_attributes(state, 0)];
  NSMutableAttributedString* longExpected = [[NSMutableAttributedString alloc]
    initWithString:[longText stringByAppendingString:@"\n- "]
    attributes:live_paragraph_attributes(state, 0)];
  for (NSUInteger step = 0; step < 2; step++) {
    if (step) [longExpected setAttributes:live_paragraph_attributes(state, 1) range:NSMakeRange(32768, 2)];
    NSRange insertedMiddle;
    NSRange removedMiddle = live_paragraph_patch_middle(longStorage, longExpected, &insertedMiddle);
    assert(removedMiddle.length == (step ? 2 : 0));
    assert(insertedMiddle.length == (step ? 2 : 3));
    [longStorage replaceCharactersInRange:removedMiddle
      withAttributedString:[longExpected attributedSubstringFromRange:insertedMiddle]];
    NSTextStorage* full = [[NSTextStorage alloc] init];
    [full setAttributedString:longExpected];
    [full fixAttributesInRange:NSMakeRange(0, full.length)];
    assert(same_native_projection(longStorage, full));
  }
  // Distant changes must retain the common middle and match a full native build.
  NSString* middle = [@"中文😀 é 👩‍💻 repeated line\n" stringByPaddingToLength:4096
    withString:@"中文😀 é 👩‍💻 repeated line\n" startingAtIndex:0];
  NSArray<NSString*>* edges = @[@"", @"# ", @"😀", @"**", @"changed prefix\n"];
  for (NSString* oldEdge in edges) {
    for (NSString* newEdge in edges) {
      NSString* oldText = [NSString stringWithFormat:@"%@%@old tail", oldEdge, middle];
      NSString* newText = [NSString stringWithFormat:@"%@%@new ending", newEdge, middle];
      NSTextStorage* storage = [[NSTextStorage alloc] initWithString:oldText
        attributes:live_paragraph_attributes(state, 0)];
      NSAttributedString* expected = [[NSAttributedString alloc] initWithString:newText
        attributes:live_paragraph_attributes(state, 0)];
      NSUInteger patches, maximum;
      live_paragraph_update_storage_details(storage, expected, &patches, &maximum);
      NSTextStorage* reference = [[NSTextStorage alloc] init];
      [reference setAttributedString:expected];
      [reference fixAttributesInRange:NSMakeRange(0, reference.length)];
      assert(same_native_projection(storage, reference));
      assert(patches <= 2 && maximum < 64);
    }
  }
#else
  live_paragraph_project_run(e, args, &work);
#endif
  args[1] = (Term)(uintptr_t)"heading";
  args[2] = 4;
  live_paragraph_append_run(e, args, &work);
#if defined(__APPLE__)
  NSFont* heading_font = [state.rendered attribute:NSFontAttributeName
    atIndex:state.rendered.length - 1 effectiveRange:NULL];
  assert(heading_font.pointSize == 32);
  assert(([[NSFontManager sharedFontManager] traitsOfFont:heading_font] & NSBoldFontMask) != 0);
#else
  assert(strstr(state->preview, "\033[1mheading\033[0m") != NULL);
#endif
  args[1] = (Term)(uintptr_t)"> quote";
  args[2] = 10;
  live_paragraph_append_run(e, args, &work);
#if defined(__APPLE__)
  NSParagraphStyle* quote_style = [state.rendered attribute:NSParagraphStyleAttributeName
    atIndex:state.rendered.length - 1 effectiveRange:NULL];
  assert(quote_style.headIndent == 18);
#else
  assert(strstr(state->preview, "\033[3m> quote\033[0m") != NULL);
#endif
  args[1] = (Term)(uintptr_t)"- item";
  args[2] = 11;
  live_paragraph_append_run(e, args, &work);
#if defined(__APPLE__)
  NSParagraphStyle* list_style = [state.rendered attribute:NSParagraphStyleAttributeName
    atIndex:state.rendered.length - 1 effectiveRange:NULL];
  assert(list_style.headIndent == 22);
#else
  assert(strstr(state->preview, "- item") != NULL);
#endif
  // Compare batch transfer with the single-run adapter, including empty text,
  // Unicode, CRLF, and every defined style. The mock constructors are consumed.
  const char* batchTexts[] = {"", "中文😀\r\n", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j"};
  args[1] = (Term)(uintptr_t)"batch";
  live_paragraph_set_run(e, args, &work);
  for (u32 style = 0; style < 12; style++) {
    args[1] = (Term)(uintptr_t)batchTexts[style];
    args[2] = style;
    live_paragraph_append_run(e, args, &work);
  }
#if defined(__APPLE__)
  NSAttributedString* singleScene = state.rendered.copy;
#else
  char* singleScene = strdup(state->preview);
#endif
  args[1] = (Term)(uintptr_t)"batch";
  live_paragraph_set_run(e, args, &work);
  Term batch = 0;
  for (u32 style = 12; style > 0; style--) {
    Term run = mock_pair((Term)(uintptr_t)batchTexts[style - 1], style - 1);
    batch = mock_pair(run, batch);
  }
  args[1] = batch;
  live_paragraph_append_scene_run(e, args, &work);
#if defined(__APPLE__)
  assert(same_native_projection(singleScene, state.rendered));
  BOOL wasDirect = state.direct;
  state.direct = NO;
  state.updating = YES;
  [state.preview.textStorage setAttributedString:singleScene];
  [state.preview.textStorage fixAttributesInRange:NSMakeRange(0, state.preview.textStorage.length)];
  NSAttributedString* singleField = state.preview.textStorage.copy;
  state.updating = NO;
  args[1] = (Term)(uintptr_t)"chunk ranges";
  live_paragraph_set_run(e, args, &work);
  Term multiRuns = 0;
  for (u32 style = 12; style > 0; style--)
    multiRuns = mock_pair(mock_pair((Term)(uintptr_t)batchTexts[style - 1], style - 1), multiRuns);
  Term* multiChunk = malloc(3 * sizeof(Term));
  assert(multiChunk);
  multiChunk[0] = 991; multiChunk[1] = 1; multiChunk[2] = multiRuns;
  args[1] = mock_pair((Term)(uintptr_t)multiChunk, 0);
  args[2] = term_pak(CID(True), 0);
  live_paragraph_append_chunks_run(e, args, &work);
  assert(same_native_projection(singleScene, state.rendered));
  [state.preview.textStorage fixAttributesInRange:NSMakeRange(0, state.preview.textStorage.length)];
  assert(same_native_projection(singleField, state.preview.textStorage));
  assert([state.preview.string isEqualToString:state.rendered.string]);
  assert(!state.direct);
  state.direct = wasDirect;
#else
  assert(strcmp(singleScene, state->preview) == 0);
  free(singleScene);
#endif
  args[1] = 0;
  live_paragraph_append_scene_run(e, args, &work);
  args[1] = (Term)(uintptr_t)"chunks";
  live_paragraph_set_run(e, args, &work);
  args[1] = mock_chunk(7, 1, "old", mock_chunk(8, 1, "tail", 0));
  args[2] = 1;
  live_paragraph_append_chunks_run(e, args, &work);
  args[1] = (Term)(uintptr_t)"chunks";
  live_paragraph_set_run(e, args, &work);
  args[1] = mock_chunk(7, 1, "new", mock_chunk(8, 0, "tail", 0));
  live_paragraph_append_chunks_run(e, args, &work);
#if defined(__APPLE__)
  assert([state.rendered.string isEqualToString:@"newtail"]);
  assert(state.nativeChunksRebuilt == 1 && state.nativeChunksReused == 1);
  assert(state.nativeChunks.count == 2);
#else
  assert(strcmp(state->preview, "newtail") == 0);
#endif
  args[1] = (Term)(uintptr_t)"chunks";
  live_paragraph_set_run(e, args, &work);
  args[1] = mock_chunk(99, 0, "only", 0);
  live_paragraph_append_chunks_run(e, args, &work);
#if defined(__APPLE__)
  assert([state.rendered.string isEqualToString:@"only"]);
  assert(state.nativeChunks.count == 1 && state.nativeChunksRebuilt == 1);
#else
  assert(strcmp(state->preview, "only") == 0);
#endif
  args[1] = (Term)(uintptr_t)"chunks";
  live_paragraph_set_run(e, args, &work);
  args[1] = mock_chunk(99, 1, "legacy", 0);
  args[2] = 0;
  live_paragraph_append_chunks_run(e, args, &work);
#if defined(__APPLE__)
  assert(state.nativeChunks == nil);
#endif
  Term legacyKeep[4] = {handle, 0, 0, (Term)(uintptr_t)""};
  live_paragraph_replace_run(e, legacyKeep, &work);
  args[1] = 0;
  live_paragraph_patch_chunks_run(e, args, &work);
#if defined(__APPLE__)
  assert([state.rendered.string isEqualToString:@"legacy"]);
#else
  assert(strcmp(state->preview, "legacy") == 0);
#endif
  args[1] = (Term)(uintptr_t)"chunks";
  live_paragraph_set_run(e, args, &work);
  args[1] = mock_chunk(99, 0, "restored", 0);
  args[2] = 1;
  live_paragraph_append_chunks_run(e, args, &work);
#if defined(__APPLE__)
  assert([state.rendered.string isEqualToString:@"restored"]);
#else
  assert(strcmp(state->preview, "restored") == 0);
#endif
  // Patches use successive block and UTF-16 ranges. Retain an untouched chunk,
  // replace a zero-width chunk, change only attributes, and remove the final block.
  args[1] = (Term)(uintptr_t)"patch source";
  live_paragraph_set_run(e, args, &work);
  args[1] = mock_chunk(41, 1, "a😀", mock_chunk(42, 1, "", mock_chunk(43, 1, "tail", 0)));
  args[2] = 1;
  live_paragraph_append_chunks_run(e, args, &work);
#if defined(__APPLE__)
  NSAttributedString* retainedTail = state.nativeChunks[@43];
#endif
  Term noSourceChange[4] = {handle, 0, 0, (Term)(uintptr_t)""};
  live_paragraph_replace_run(e, noSourceChange, &work);
  args[1] = mock_patch(0, 1, 0, 3, mock_styled_chunk(41, 1, "中文", 1, 0),
    mock_patch(1, 1, 2, 0, mock_chunk(44, 0, "😀", mock_chunk(45, 1, "", 0)), 0));
  live_paragraph_patch_chunks_run(e, args, &work);
#if defined(__APPLE__)
  assert([state.rendered.string isEqualToString:@"中文😀tail"]);
  assert(state.nativeChunks[@43] == retainedTail);
  assert(state.nativeChunks[@42] == nil && state.nativeChunks.count == 4);
  assert(state.nativeOrder.count == 4 && [state.nativeOrder[2] isEqual:@45]);
#else
  assert(strcmp(state->preview, "\033[1m中文\033[0m😀tail") == 0);
  assert(state->chunk_count == 4 && state->chunks[2].id == 45);
#endif
  live_paragraph_replace_run(e, noSourceChange, &work);
  args[1] = mock_patch(3, 1, 4, 4, 0,
    mock_patch(0, 1, 0, 2, mock_styled_chunk(41, 1, "中文", 2, 0), 0));
  live_paragraph_patch_chunks_run(e, args, &work);
#if defined(__APPLE__)
  NSAttributedString* patched = state.rendered.copy;
  assert([patched.string isEqualToString:@"中文😀"]);
  assert(state.nativeChunks[@43] == nil && state.nativeChunks.count == 3);
#else
  char* patched = strdup(state->preview);
  assert(strcmp(patched, "\033[3m中文\033[0m😀") == 0);
  assert(state->chunk_count == 3);
#endif
  args[1] = (Term)(uintptr_t)"patch source";
  live_paragraph_set_run(e, args, &work);
  args[1] = mock_styled_chunk(41, 1, "中文", 2,
    mock_chunk(44, 1, "😀", mock_chunk(45, 1, "", 0)));
  live_paragraph_append_chunks_run(e, args, &work);
#if defined(__APPLE__)
  assert(same_native_projection(patched, state.rendered));
#else
  assert(strcmp(patched, state->preview) == 0);
  free(patched);
#endif
  live_paragraph_replace_run(e, noSourceChange, &work);
  args[1] = 0;
  live_paragraph_patch_chunks_run(e, args, &work);
#if defined(__APPLE__)
  assert([state.rendered.string isEqualToString:@"中文😀"]);
#else
  assert(strcmp(state->preview, "\033[3m中文\033[0m😀") == 0);
#endif
  args[1] = (Term)(uintptr_t)"empty";
  live_paragraph_set_run(e, args, &work);
  args[1] = 0;
  live_paragraph_append_chunks_run(e, args, &work);
  live_paragraph_replace_run(e, noSourceChange, &work);
  args[1] = mock_patch(0, 0, 0, 0, mock_chunk((1ULL << 47) + 7, 0, "é\r\n", 0),
    mock_patch(0, 1, 0, 4, 0, 0));
  live_paragraph_patch_chunks_run(e, args, &work);
#if defined(__APPLE__)
  assert(state.rendered.length == 0 && state.nativeChunks.count == 0 && state.nativeOrder.count == 0);
#else
  assert(state->preview_length == 0 && state->chunk_count == 0);
#endif
#if defined(__APPLE__)
  check_projection_translation();
  check_input_ranges();
  check_source_index();
  // Apply disjoint patches on both sides of an uncommitted native edit, then
  // cover that edit. Check positive and negative changes in UTF-16 width.
  for (NSString* input in @[@"😀Q", @"", @"Q"]) {
    args[1] = (Term)(uintptr_t)"storage";
    live_paragraph_set_run(e, args, &work);
    args[1] = mock_chunk(61, 1, "x", mock_chunk(62, 1, "YZ", mock_chunk(63, 1, "tail", 0)));
    args[2] = 1;
    live_paragraph_append_chunks_run(e, args, &work);
    args[1] = args[2] = 0;
    live_paragraph_project_run(e, args, &work);
    [direct insertText:input replacementRange:NSMakeRange(1, 2)];
    [state textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification object:direct]];
    assert(state.pendingProjectionEdit);
    live_paragraph_replace_run(e, noSourceChange, &work);
    state.response = 123;
    args[1] = mock_patch(2, 1, 3, 4, mock_styled_chunk(63, 1, "END", 3, 0),
      mock_patch(0, 1, 0, 1, mock_styled_chunk(61, 1, "ab", 1, 0),
        mock_patch(1, 1, 2, 2, mock_styled_chunk(62, 1, "é", 2, 0), 0)));
    live_paragraph_patch_chunks_run(e, args, &work);
    assert(state.projectionPatchesApplied);
    args[1] = args[2] = 4;
    live_paragraph_project_run(e, args, &work);
    assert([direct.string isEqualToString:@"abéEND"]);
    assert(state.projectionFullComparisons == 0 && state.projectionPatchCount == 3);
    assert(state.response == 123);
    check_projected_field(state);
    // An unknown baseline must use the complete comparison, even at equal length.
    [direct.textStorage replaceCharactersInRange:NSMakeRange(0, 1) withString:@"?"];
    state.projectionBaselineKnown = NO;
    live_paragraph_replace_run(e, noSourceChange, &work);
    args[1] = 0;
    live_paragraph_patch_chunks_run(e, args, &work);
    assert(!state.projectionPatchesApplied);
    args[1] = args[2] = 4;
    live_paragraph_project_run(e, args, &work);
    assert(state.projectionFullComparisons == 1);
    check_projected_field(state);
  }
  // Partial overlap after an earlier direct patch must still match a full build.
  args[1] = (Term)(uintptr_t)"storage";
  live_paragraph_set_run(e, args, &work);
  args[1] = mock_chunk(61, 1, "x", mock_chunk(62, 1, "YZ", mock_chunk(63, 1, "tail", 0)));
  args[2] = 1;
  live_paragraph_append_chunks_run(e, args, &work);
  args[1] = args[2] = 0;
  live_paragraph_project_run(e, args, &work);
  [direct insertText:@"Q" replacementRange:NSMakeRange(0, 2)];
  [state textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification object:direct]];
  live_paragraph_replace_run(e, noSourceChange, &work);
  args[1] = mock_patch(2, 1, 3, 4, mock_styled_chunk(63, 1, "END", 3, 0),
    mock_patch(1, 1, 1, 2, mock_styled_chunk(62, 1, "ZZ", 2, 0), 0));
  live_paragraph_patch_chunks_run(e, args, &work);
  assert(!state.projectionPatchesApplied && state.projectionPatchCount == 1);
  args[1] = args[2] = 0;
  live_paragraph_project_run(e, args, &work);
  assert(state.projectionFullComparisons == 1 && state.projectionPatchCount >= 2);
  assert([direct.string isEqualToString:@"xZZEND"]);
  check_projected_field(state);
#endif
  const char* rangeExpected[] = {
    "中文日\n\r\né", "中日\n\né", "中文😀\r\né日\n", "日\n", "中文😀日\n\r\né"
  };
  u64 rangeStarts[] = {2, 4, 20, 0, 3};
  u64 rangeEnds[] = {3, 1, 10, 100, 3};
  for (u64 i = 0; i < 5; i++) {
    args[1] = (Term)(uintptr_t)"中文😀\r\né";
    live_paragraph_set_run(e, args, &work);
    Term replaceArgs[4] = {handle, rangeStarts[i], rangeEnds[i], (Term)(uintptr_t)"日\n"};
    live_paragraph_replace_run(e, replaceArgs, &work);
#if defined(__APPLE__)
    assert([state.text isEqualToString:@(rangeExpected[i])]);
    assert([state.editor.string isEqualToString:state.text]);
#else
    assert(strcmp(state->text, rangeExpected[i]) == 0);
#endif
  }
  Term keepArgs[4] = {handle, 0, 0, (Term)(uintptr_t)""};
  live_paragraph_replace_run(e, keepArgs, &work);
#if defined(__APPLE__)
  assert([state.text isEqualToString:@"中文😀日\n\r\né"]);
#else
  assert(strcmp(state->text, "中文😀日\n\r\né") == 0);
#endif
  args[1] = (Term)(uintptr_t)"";
  live_paragraph_set_run(e, args, &work);
  Term emptyArgs[4] = {handle, 0, 100, (Term)(uintptr_t)"😀"};
  live_paragraph_replace_run(e, emptyArgs, &work);
#if defined(__APPLE__)
  assert([state.text isEqualToString:@"😀"]);
#else
  assert(strcmp(state->text, "😀") == 0);
#endif
  Term deleteArgs[4] = {handle, 10, 0, (Term)(uintptr_t)""};
  live_paragraph_replace_run(e, deleteArgs, &work);
#if defined(__APPLE__)
  assert([state.text isEqualToString:@""]);
#else
  assert(state->length == 0 && state->text[0] == 0);
#endif
  #if defined(__APPLE__)
  args[1] = (Term)(uintptr_t)"a😀bc";
  live_paragraph_set_run(e, args, &work);
  assert(state.sourceFieldSynchronized);
  [state.editor.textStorage addAttribute:@"SourceCheck" value:@1 range:NSMakeRange(0, 1)];
  assert(state.sourceFieldSynchronized);
  [state.editor.textStorage replaceCharactersInRange:NSMakeRange(0, 1) withString:@"Z"];
  assert(!state.sourceFieldSynchronized);
  Term restoreSource[4] = {handle, 2, 3, (Term)(uintptr_t)"Q"};
  live_paragraph_replace_run(e, restoreSource, &work);
  assert([state.text isEqualToString:@"a😀Qc"]);
  assert([state.editor.string isEqualToString:state.text] && state.sourceFieldSynchronized);
  [state.editor.textStorage replaceCharactersInRange:NSMakeRange(0, 1) withString:@"ZZ"];
  assert(!state.sourceFieldSynchronized);
  restoreSource[1] = restoreSource[2] = 4;
  live_paragraph_replace_run(e, restoreSource, &work);
  assert([state.text isEqualToString:@"a😀QcQ"]);
  assert([state.editor.string isEqualToString:state.text] && state.sourceFieldSynchronized);
  #endif
  live_paragraph_close_run(e, args, &work);
  puts("Host round trip passed");
  return 0;
}
