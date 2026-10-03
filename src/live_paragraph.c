#if defined(__APPLE__)

#import <Cocoa/Cocoa.h>
#include <time.h>

static double live_paragraph_now(void) {
  struct timespec value;
  clock_gettime(CLOCK_MONOTONIC, &value);
  return (double)value.tv_sec + (double)value.tv_nsec / 1e9;
}

@class MarkBendLiveState;

// Native source-position index. Markdown meaning remains in Bend.
// Nodes are immutable after construction; edits share retained branches.
@interface MarkBendSourceIndex : NSObject
@property(nonatomic, strong) MarkBendSourceIndex* left;
@property(nonatomic, strong) MarkBendSourceIndex* right;
@property(nonatomic, copy) NSString* text;
@property(nonatomic) NSUInteger scalars;
@property(nonatomic) NSUInteger nativeLength;
@property(nonatomic) NSUInteger height;
@end
@implementation MarkBendSourceIndex
@end

static MarkBendSourceIndex* live_source_leaf(NSString* text) {
  if (!text.length) return nil;
  MarkBendSourceIndex* node = [MarkBendSourceIndex new];
  node.text = text;
  node.nativeLength = text.length;
  node.height = 1;
  unichar chars[512];
  if (text.length > 512) err_fail("LiveParagraph: source leaf exceeds bound");
  [text getCharacters:chars range:NSMakeRange(0, text.length)];
  for (NSUInteger at = 0; at < text.length; at++) {
    if (CFStringIsSurrogateHighCharacter(chars[at]) && at + 1 < text.length &&
        CFStringIsSurrogateLowCharacter(chars[at + 1])) at++;
    node.scalars++;
  }
  return node;
}

static MarkBendSourceIndex* live_source_node(MarkBendSourceIndex* left, MarkBendSourceIndex* right) {
  if (!left) return right;
  if (!right) return left;
  MarkBendSourceIndex* node = [MarkBendSourceIndex new];
  node.left = left; node.right = right;
  node.scalars = left.scalars + right.scalars;
  node.nativeLength = left.nativeLength + right.nativeLength;
  node.height = 1 + MAX(left.height, right.height);
  return node;
}

static MarkBendSourceIndex* live_source_balance(MarkBendSourceIndex* left, MarkBendSourceIndex* right) {
  if (left.height > right.height + 1) {
    if (left.left.height >= left.right.height)
      return live_source_node(left.left, live_source_node(left.right, right));
    return live_source_node(live_source_node(left.left, left.right.left),
      live_source_node(left.right.right, right));
  }
  if (right.height > left.height + 1) {
    if (right.right.height >= right.left.height)
      return live_source_node(live_source_node(left, right.left), right.right);
    return live_source_node(live_source_node(left, right.left.left),
      live_source_node(right.left.right, right.right));
  }
  return live_source_node(left, right);
}

static MarkBendSourceIndex* live_source_join(MarkBendSourceIndex* left, MarkBendSourceIndex* right) {
  if (!left) return right;
  if (!right) return left;
  if (left.text && right.text && left.nativeLength + right.nativeLength <= 512)
    return live_source_leaf([left.text stringByAppendingString:right.text]);
  if (left.height > right.height + 1)
    return live_source_balance(left.left, live_source_join(left.right, right));
  if (right.height > left.height + 1)
    return live_source_balance(live_source_join(left, right.left), right.right);
  return live_source_node(left, right);
}

static MarkBendSourceIndex* live_source_build_range(NSString* text, NSRange range) {
  if (range.length <= 512) return live_source_leaf([text substringWithRange:range]);
  NSUInteger middle = range.location + range.length / 2;
  if (CFStringIsSurrogateLowCharacter([text characterAtIndex:middle]) &&
      CFStringIsSurrogateHighCharacter([text characterAtIndex:middle - 1])) middle--;
  return live_source_node(live_source_build_range(text, NSMakeRange(range.location, middle - range.location)),
    live_source_build_range(text, NSMakeRange(middle, NSMaxRange(range) - middle)));
}

static MarkBendSourceIndex* live_source_build(NSString* text) {
  return live_source_build_range(text, NSMakeRange(0, text.length));
}

static NSUInteger live_source_native(MarkBendSourceIndex* node, NSUInteger scalar) {
  if (!node || !scalar) return 0;
  if (scalar >= node.scalars) return node.nativeLength;
  if (!node.text) {
    if (scalar <= node.left.scalars) return live_source_native(node.left, scalar);
    return node.left.nativeLength + live_source_native(node.right, scalar - node.left.scalars);
  }
  unichar chars[512];
  [node.text getCharacters:chars range:NSMakeRange(0, node.nativeLength)];
  NSUInteger at = 0;
  for (NSUInteger count = 0; count < scalar; count++) {
    unichar first = chars[at++];
    if (CFStringIsSurrogateHighCharacter(first) && at < node.nativeLength &&
        CFStringIsSurrogateLowCharacter(chars[at])) at++;
  }
  return at;
}

static void live_source_split(MarkBendSourceIndex* node, NSUInteger scalar,
  MarkBendSourceIndex* __strong* left, MarkBendSourceIndex* __strong* right) {
  if (!scalar) { *left = nil; *right = node; return; }
  if (scalar >= node.scalars) { *left = node; *right = nil; return; }
  if (node.text) {
    NSUInteger at = live_source_native(node, scalar);
    *left = live_source_leaf([node.text substringToIndex:at]);
    *right = live_source_leaf([node.text substringFromIndex:at]);
    return;
  }
  MarkBendSourceIndex *a, *b;
  if (scalar < node.left.scalars) {
    live_source_split(node.left, scalar, &a, &b);
    *left = a; *right = live_source_join(b, node.right);
  } else {
    live_source_split(node.right, scalar - node.left.scalars, &a, &b);
    *left = live_source_join(node.left, a); *right = b;
  }
}

static MarkBendSourceIndex* live_source_replace(MarkBendSourceIndex* node,
  NSUInteger start, NSUInteger end, NSString* text) {
  MarkBendSourceIndex *prefix, *tail, *removed, *suffix;
  live_source_split(node, start, &prefix, &tail);
  live_source_split(tail, end - start, &removed, &suffix);
  return live_source_join(live_source_join(prefix, live_source_build(text)), suffix);
}

@interface MarkBendEditor : NSTextView
@property(nonatomic, weak) MarkBendLiveState* session;
@end

@interface MarkBendLiveState : NSObject <NSTextViewDelegate, NSTextStorageDelegate, NSWindowDelegate>
@property(nonatomic, copy) NSString* text;
@property(nonatomic, strong) MarkBendSourceIndex* sourceIndex;
@property(nonatomic, copy) NSString* indexedSource;
@property(nonatomic, strong) NSMutableAttributedString* rendered;
@property(nonatomic, strong) NSMutableAttributedString* retainedScene;
@property(nonatomic, strong) NSMutableDictionary<NSNumber*, NSDictionary*>* attributes;
@property(nonatomic, strong) NSMutableDictionary<NSNumber*, NSAttributedString*>* nativeChunks;
@property(nonatomic, strong) NSMutableArray<NSNumber*>* nativeOrder;
@property(nonatomic) NSUInteger nativeChunksRebuilt;
@property(nonatomic) NSUInteger nativeChunksReused;
@property(nonatomic) NSUInteger nativeChunksTransferred;
@property(nonatomic, strong) NSAlert* alert;
@property(nonatomic, strong) NSTextView* editor;
@property(nonatomic, strong) NSTextView* preview;
@property(nonatomic) NSInteger response;
@property(nonatomic) BOOL updating;
@property(nonatomic) BOOL direct;
@property(nonatomic) BOOL sourceFieldSynchronized;
@property(nonatomic) NSRange pendingRange;
@property(nonatomic) NSSelectionAffinity pendingSelectionAffinity;
@property(nonatomic) BOOL pendingSelectionEvent;
@property(nonatomic) NSRange pendingProjectionRange;
@property(nonatomic) NSUInteger pendingProjectionLength;
@property(nonatomic) BOOL pendingProjectionEdit;
@property(nonatomic) BOOL projectionBaselineKnown;
@property(nonatomic) BOOL projectionPatchesApplied;
@property(nonatomic) NSUInteger projectionFullComparisons;
@property(nonatomic) NSUInteger inputStorageEdits;
@property(nonatomic) NSRange inputStorageRange;
@property(nonatomic) NSRange inputInsertedRange;
@property(nonatomic) NSUInteger inputFullComparisons;
@property(nonatomic) NSUInteger inputRangeUpdates;
@property(nonatomic) NSRange selection;
@property(nonatomic) NSRange projectionRange;
@property(nonatomic) NSRange projectionRemovedRange;
@property(nonatomic) NSUInteger projectionCount;
@property(nonatomic) NSUInteger projectionMaximumLength;
@property(nonatomic) NSUInteger projectionPatchCount;
@property(nonatomic) NSUInteger projectionBeforeLength;
@property(nonatomic) NSUInteger projectionAfterLength;
@property(nonatomic) NSUInteger projectionBeforeFirst;
@property(nonatomic) NSUInteger projectionAfterFirst;
@property(nonatomic) BOOL measurePresentation;
@property(nonatomic) double presentationStarted;
@property(nonatomic) double sourceUpdateSeconds;
@property(nonatomic) double sourceLookupSeconds;
@property(nonatomic) double sourceCompareSeconds;
@property(nonatomic) double sourceCopySeconds;
@property(nonatomic) double sourceStorageSeconds;
@property(nonatomic) double sourceSelectionSeconds;
@property(nonatomic) double runBuildSeconds;
@property(nonatomic) double projectionSeconds;
@property(nonatomic) double chunkUpdateSeconds;
@property(nonatomic) double projectionComparisonSeconds;
@property(nonatomic) double projectionStorageSeconds;
@property(nonatomic, strong) NSMutableArray<NSArray<NSValue*>*>* projectionPatchRanges;
@property(nonatomic) double textConvertSeconds;
@property(nonatomic) double styledRunSeconds;
@property(nonatomic) double chunkCopySeconds;
@property(nonatomic) double sceneAssemblySeconds;
@property(nonatomic) NSUInteger presentationRunCount;
@property(nonatomic, copy) NSString* pendingText;
@end

// Compare UTF-16 in contiguous buffers. Calling characterAtIndex for every
// character adds native message work to each large-document edit.
static void live_paragraph_text_edges(NSString* before, NSString* after, NSUInteger limit,
  NSUInteger* prefixResult, NSUInteger* suffixResult) {
  NSUInteger oldLength = before.length, newLength = after.length;
  unichar* oldChars = malloc(oldLength * sizeof(unichar));
  unichar* newChars = malloc(newLength * sizeof(unichar));
  if ((oldLength && !oldChars) || (newLength && !newChars)) {
    free(oldChars); free(newChars);
    err_fail("LiveParagraph: text comparison allocation failed");
  }
  if (oldLength) [before getCharacters:oldChars range:NSMakeRange(0, oldLength)];
  if (newLength) [after getCharacters:newChars range:NSMakeRange(0, newLength)];
  NSUInteger prefix = 0, suffix = 0;
  NSUInteger maximum = MIN(limit, MIN(oldLength, newLength));
  while (prefix < maximum && oldChars[prefix] == newChars[prefix]) prefix++;
  while (suffix < oldLength - prefix && suffix < newLength - prefix &&
    oldChars[oldLength - 1 - suffix] == newChars[newLength - 1 - suffix]) suffix++;
  free(oldChars); free(newChars);
  *prefixResult = prefix;
  *suffixResult = suffix;
}

// Compare native text only. Markdown meaning stays in Bend. Expand the changed
// range to complete composed characters before sending it to the core.
static NSRange live_paragraph_difference(NSString* before, NSString* after,
  NSRange* inserted) {
  NSUInteger prefix, suffix;
  live_paragraph_text_edges(before, after, NSUIntegerMax, &prefix, &suffix);
  if (prefix < before.length) {
    prefix = MIN(prefix, [before rangeOfComposedCharacterSequenceAtIndex:prefix].location);
  }
  if (prefix < after.length) {
    prefix = MIN(prefix, [after rangeOfComposedCharacterSequenceAtIndex:prefix].location);
  }
  // A composed-character adjustment can move the prefix. Recheck the suffix
  // with that boundary so that both replacement ranges stay consistent.
  live_paragraph_text_edges(before, after, prefix, &prefix, &suffix);
  NSUInteger oldEnd = before.length - suffix, newEnd = after.length - suffix;
  NSUInteger expand = 0;
  if (oldEnd > 0 && oldEnd < before.length) {
    NSRange cluster = [before rangeOfComposedCharacterSequenceAtIndex:oldEnd];
    if (cluster.location < oldEnd) expand = NSMaxRange(cluster) - oldEnd;
  }
  if (newEnd > 0 && newEnd < after.length) {
    NSRange cluster = [after rangeOfComposedCharacterSequenceAtIndex:newEnd];
    if (cluster.location < newEnd) expand = MAX(expand, NSMaxRange(cluster) - newEnd);
  }
  oldEnd = MIN(before.length, oldEnd + expand);
  newEnd = MIN(after.length, newEnd + expand);
  *inserted = NSMakeRange(prefix, newEnd - prefix);
  return NSMakeRange(prefix, oldEnd - prefix);
}

// The storage reports an exact replacement. Expand only its boundaries to
// complete composed characters; the unchanged prefix and suffix need no scan.
static NSRange live_paragraph_input_range(NSString* before, NSString* after,
  NSRange removed, NSRange* inserted) {
  NSUInteger start = removed.location;
  if (start < before.length)
    start = MIN(start, [before rangeOfComposedCharacterSequenceAtIndex:start].location);
  if (start < after.length)
    start = MIN(start, [after rangeOfComposedCharacterSequenceAtIndex:start].location);
  NSUInteger oldEnd = NSMaxRange(removed), newEnd = NSMaxRange(*inserted);
  for (;;) {
    NSUInteger priorStart = start;
    if (oldEnd > start) {
      NSRange cluster = [before rangeOfComposedCharacterSequencesForRange:NSMakeRange(start, oldEnd - start)];
      start = MIN(start, cluster.location);
    }
    if (newEnd > start) {
      NSRange cluster = [after rangeOfComposedCharacterSequencesForRange:NSMakeRange(start, newEnd - start)];
      start = MIN(start, cluster.location);
    }
    NSUInteger expand = 0;
    if (oldEnd > start) {
      NSRange cluster = [before rangeOfComposedCharacterSequencesForRange:NSMakeRange(start, oldEnd - start)];
      expand = NSMaxRange(cluster) - oldEnd;
    }
    if (newEnd > start) {
      NSRange cluster = [after rangeOfComposedCharacterSequencesForRange:NSMakeRange(start, newEnd - start)];
      expand = MAX(expand, NSMaxRange(cluster) - newEnd);
    }
    if (oldEnd > 0 && oldEnd < before.length) {
      NSRange cluster = [before rangeOfComposedCharacterSequenceAtIndex:oldEnd];
      if (cluster.location < oldEnd) expand = MAX(expand, NSMaxRange(cluster) - oldEnd);
    }
    if (newEnd > 0 && newEnd < after.length) {
      NSRange cluster = [after rangeOfComposedCharacterSequenceAtIndex:newEnd];
      if (cluster.location < newEnd) expand = MAX(expand, NSMaxRange(cluster) - newEnd);
    }
    if (!expand && priorStart == start) break;
    oldEnd = MIN(before.length, oldEnd + expand);
    newEnd = MIN(after.length, newEnd + expand);
  }
  *inserted = NSMakeRange(start, newEnd - start);
  return NSMakeRange(start, oldEnd - start);
}

// Native projection updates compare text and attributes. Only the changed
// interval invalidates layout; the host does not interpret Markdown.
static BOOL live_paragraph_same_attributes(NSDictionary* before, NSDictionary* after) {
  if (before == after || [before isEqual:after]) return YES;
  // TextKit can replace NSFont with a script or emoji fallback. Keep the
  // requested font as an intent attribute so that this does not dirty a run.
  NSFont* oldFont = before[@"MarkBendRequestedFont"];
  NSFont* newFont = after[@"MarkBendRequestedFont"];
  if (oldFont && newFont && [oldFont isEqual:newFont]) {
    NSMutableDictionary* oldAttributes = [before mutableCopy];
    NSMutableDictionary* newAttributes = [after mutableCopy];
    [oldAttributes removeObjectForKey:NSFontAttributeName];
    [newAttributes removeObjectForKey:NSFontAttributeName];
    return [oldAttributes isEqual:newAttributes];
  }
  return [before isEqual:after];
}

// Retain only edges whose text and attributes match inside this scene patch.
// Coordinates belong to the current preview, after all preceding patches.
static NSRange live_paragraph_patch_middle(NSAttributedString* before,
  NSAttributedString* after, NSRange* inserted) {
  NSUInteger prefix, suffix;
  live_paragraph_text_edges(before.string, after.string, NSUIntegerMax, &prefix, &suffix);
  NSUInteger at = 0;
  while (at < prefix) {
    NSRange a, b;
    if (!live_paragraph_same_attributes([before attributesAtIndex:at effectiveRange:&a],
        [after attributesAtIndex:at effectiveRange:&b])) break;
    at = MIN(prefix, MIN(NSMaxRange(a), NSMaxRange(b)));
  }
  prefix = at;
  live_paragraph_text_edges(before.string, after.string, prefix, &prefix, &suffix);
  NSUInteger matched = 0;
  while (matched < suffix) {
    NSUInteger oldAt = before.length - 1 - matched, newAt = after.length - 1 - matched;
    NSRange a, b;
    if (!live_paragraph_same_attributes([before attributesAtIndex:oldAt effectiveRange:&a],
        [after attributesAtIndex:newAt effectiveRange:&b])) break;
    matched += MIN(suffix - matched, MIN(oldAt - a.location + 1, newAt - b.location + 1));
  }
  suffix = matched;
  // Do not split a UTF-16 surrogate pair at either retained edge.
  if (prefix && ((prefix < before.length && CFStringIsSurrogateLowCharacter([before.string characterAtIndex:prefix])) ||
      (prefix < after.length && CFStringIsSurrogateLowCharacter([after.string characterAtIndex:prefix])))) prefix--;
  NSUInteger oldEnd = before.length - suffix, newEnd = after.length - suffix;
  if (suffix && ((oldEnd && oldEnd < before.length && CFStringIsSurrogateLowCharacter([before.string characterAtIndex:oldEnd])) ||
      (newEnd && newEnd < after.length && CFStringIsSurrogateLowCharacter([after.string characterAtIndex:newEnd])))) {
    suffix--; oldEnd++; newEnd++;
  }
  *inserted = NSMakeRange(prefix, newEnd - prefix);
  return NSMakeRange(prefix, oldEnd - prefix);
}

// Search a bounded pair of leading windows for a common text section. Verify
// every retained character and attribute before using it as a patch boundary.
static BOOL live_paragraph_middle(NSAttributedString* before, NSAttributedString* after,
  NSRange oldRange, NSRange newRange, NSRange* oldMiddle, NSRange* newMiddle) {
  const NSUInteger seed = 32, window = 64;
  if (oldRange.length < seed || newRange.length < seed) return NO;
  unichar* oldChars = malloc(oldRange.length * sizeof(unichar));
  unichar* newChars = malloc(newRange.length * sizeof(unichar));
  if (!oldChars || !newChars) {
    free(oldChars); free(newChars);
    return NO;
  }
  [before.string getCharacters:oldChars range:oldRange];
  [after.string getCharacters:newChars range:newRange];
  NSUInteger oldSkip = NSNotFound, newSkip = NSNotFound;
  for (NSUInteger cost = 0; cost <= 2 * window && oldSkip == NSNotFound; cost++) {
    for (NSUInteger a = 0; a <= MIN(window, cost); a++) {
      NSUInteger b = cost - a;
      if (b > window || a + seed > oldRange.length || b + seed > newRange.length) continue;
      if (memcmp(oldChars + a, newChars + b, seed * sizeof(unichar)) == 0) {
        oldSkip = a; newSkip = b; break;
      }
    }
  }
  NSUInteger length = 0;
  if (oldSkip != NSNotFound) {
    while (oldSkip + length < oldRange.length && newSkip + length < newRange.length &&
      oldChars[oldSkip + length] == newChars[newSkip + length]) length++;
    NSUInteger verified = 0;
    while (verified < length) {
      NSRange a, b;
      NSUInteger oldAt = oldRange.location + oldSkip + verified;
      NSUInteger newAt = newRange.location + newSkip + verified;
      if (!live_paragraph_same_attributes(
        [before attributesAtIndex:oldAt effectiveRange:&a],
        [after attributesAtIndex:newAt effectiveRange:&b])) break;
      verified += MIN(length - verified, MIN(NSMaxRange(a) - oldAt, NSMaxRange(b) - newAt));
    }
    length = verified;
  }
  free(oldChars); free(newChars);
  if (length < seed) return NO;
  *oldMiddle = NSMakeRange(oldRange.location + oldSkip, length);
  *newMiddle = NSMakeRange(newRange.location + newSkip, length);
  return YES;
}

static NSRange live_paragraph_update_storage_details(NSTextStorage* storage,
  NSAttributedString* next, NSUInteger* patchCount, NSUInteger* maximumLength) {
  NSUInteger prefix, suffix;
  live_paragraph_text_edges(storage.string, next.string, NSUIntegerMax, &prefix, &suffix);
  NSUInteger at = 0;
  while (at < prefix) {
    NSRange oldRange, newRange;
    NSDictionary* oldAttributes = [storage attributesAtIndex:at effectiveRange:&oldRange];
    NSDictionary* newAttributes = [next attributesAtIndex:at effectiveRange:&newRange];
    if (!live_paragraph_same_attributes(oldAttributes, newAttributes)) break;
    at = MIN(prefix, MIN(NSMaxRange(oldRange), NSMaxRange(newRange)));
  }
  prefix = at;
  live_paragraph_text_edges(storage.string, next.string, prefix, &prefix, &suffix);
  NSUInteger matched = 0;
  while (matched < suffix) {
    NSUInteger oldIndex = storage.length - 1 - matched;
    NSUInteger newIndex = next.length - 1 - matched;
    NSRange oldRange, newRange;
    NSDictionary* oldAttributes = [storage attributesAtIndex:oldIndex effectiveRange:&oldRange];
    NSDictionary* newAttributes = [next attributesAtIndex:newIndex effectiveRange:&newRange];
    if (!live_paragraph_same_attributes(oldAttributes, newAttributes)) break;
    matched += MIN(suffix - matched,
      MIN(oldIndex - oldRange.location + 1, newIndex - newRange.location + 1));
  }
  suffix = matched;
  NSRange oldRange = NSMakeRange(prefix, storage.length - prefix - suffix);
  NSRange newRange = NSMakeRange(prefix, next.length - prefix - suffix);
  NSUInteger count = 0, maximum = 0;
  if (oldRange.length || newRange.length) {
    NSRange oldMiddle, newMiddle;
    if (live_paragraph_middle(storage, next, oldRange, newRange, &oldMiddle, &newMiddle)) {
      // Apply the tail first so that the leading patch keeps its old position.
      NSRange oldTail = NSMakeRange(NSMaxRange(oldMiddle), NSMaxRange(oldRange) - NSMaxRange(oldMiddle));
      NSRange newTail = NSMakeRange(NSMaxRange(newMiddle), NSMaxRange(newRange) - NSMaxRange(newMiddle));
      NSRange oldHead = NSMakeRange(prefix, oldMiddle.location - prefix);
      NSRange newHead = NSMakeRange(prefix, newMiddle.location - prefix);
      if (oldTail.length || newTail.length) {
        [storage replaceCharactersInRange:oldTail
          withAttributedString:[next attributedSubstringFromRange:newTail]];
        count++; maximum = MAX(oldTail.length, newTail.length);
      }
      if (oldHead.length || newHead.length) {
        [storage replaceCharactersInRange:oldHead
          withAttributedString:[next attributedSubstringFromRange:newHead]];
        count++; maximum = MAX(maximum, MAX(oldHead.length, newHead.length));
      }
    } else {
      [storage replaceCharactersInRange:oldRange
        withAttributedString:[next attributedSubstringFromRange:newRange]];
      count = 1; maximum = MAX(oldRange.length, newRange.length);
    }
  }
  if (patchCount) *patchCount = count;
  if (maximumLength) *maximumLength = maximum;
  return oldRange;
}

static NSRange live_paragraph_update_storage(NSTextStorage* storage, NSAttributedString* next) {
  return live_paragraph_update_storage_details(storage, next, NULL, NULL);
}

@implementation MarkBendEditor

- (void)insertNewline:(id)sender {
  if (self.session.direct && self.session.preview == self && !self.hasMarkedText) {
    self.session.pendingRange = self.selectedRange;
    self.session.pendingSelectionEvent = NO;
    self.session.response = NSAlertFirstButtonReturn + 9;
    [NSApp stopModal];
    return;
  }
  [super insertNewline:sender];
}

- (void)unmarkText {
  [super unmarkText];
  if (self.session.direct && self.session.preview == self) {
    [self.session textDidChange:[NSNotification
      notificationWithName:NSTextDidChangeNotification object:self]];
  }
}

- (BOOL)performKeyEquivalent:(NSEvent*)event {
  NSEventModifierFlags flags = event.modifierFlags;
  if ((flags & NSEventModifierFlagCommand) == 0 ||
      (flags & (NSEventModifierFlagControl | NSEventModifierFlagOption)) != 0) {
    return [super performKeyEquivalent:event];
  }
  NSString* key = event.charactersIgnoringModifiers.lowercaseString;
  if ([key isEqualToString:@"s"]) {
    if (!self.hasMarkedText) {
      self.session.response = NSAlertFirstButtonReturn + ((flags & NSEventModifierFlagShift) ? 7 : 6);
      [NSApp stopModal];
    }
    return YES;
  }
  if ([key isEqualToString:@"z"]) {
    if (self.hasMarkedText) {
      return YES;
    }
    self.session.response = (flags & NSEventModifierFlagShift) != 0
      ? NSAlertThirdButtonReturn : NSAlertSecondButtonReturn;
    [NSApp stopModal];
    return YES;
  }
  if ([key isEqualToString:@"a"]) {
    [self selectAll:nil];
    return YES;
  }
  if ([key isEqualToString:@"c"]) {
    [self copy:nil];
    return YES;
  }
  if ([key isEqualToString:@"v"]) {
    [self pasteAsPlainText:nil];
    return YES;
  }
  if ([key isEqualToString:@"x"]) {
    [self cut:nil];
    return YES;
  }
  return [super performKeyEquivalent:event];
}

@end

@implementation MarkBendLiveState

- (void)textStorage:(NSTextStorage*)storage didProcessEditing:(NSTextStorageEditActions)mask
  range:(NSRange)range changeInLength:(NSInteger)delta {
  if (storage == self.editor.textStorage && !self.updating &&
      (mask & NSTextStorageEditedCharacters)) {
    self.sourceFieldSynchronized = NO;
    return;
  }
  if (!self.direct || self.updating || storage != self.preview.textStorage ||
      !(mask & NSTextStorageEditedCharacters)) return;
  self.inputStorageEdits++;
  if (self.inputStorageEdits != 1) return;
  NSInteger removed = (NSInteger)range.length - delta;
  if (removed < 0 || range.location > self.rendered.length ||
      (NSUInteger)removed > self.rendered.length - range.location ||
      range.location > storage.length || range.length > storage.length - range.location ||
      storage.length != self.rendered.length - (NSUInteger)removed + range.length) {
    self.inputStorageEdits = 2;
    return;
  }
  self.inputStorageRange = NSMakeRange(range.location, (NSUInteger)removed);
  self.inputInsertedRange = range;
}

- (void)textDidChange:(NSNotification*)notification {
  if (self.direct && notification.object == self.preview) {
    if (self.updating || self.preview.hasMarkedText) return;
    NSRange inserted;
    if (self.inputStorageEdits == 1 && self.projectionBaselineKnown) {
      inserted = self.inputInsertedRange;
      NSRange removed = self.inputStorageRange;
      NSUInteger prefix, suffix;
      live_paragraph_text_edges([self.rendered.string substringWithRange:removed],
        [self.preview.string substringWithRange:inserted], NSUIntegerMax, &prefix, &suffix);
      removed = NSMakeRange(removed.location + prefix, removed.length - prefix - suffix);
      inserted = NSMakeRange(inserted.location + prefix, inserted.length - prefix - suffix);
      if (!removed.length && !inserted.length) return;
      self.pendingRange = live_paragraph_input_range(self.rendered.string,
        self.preview.string, removed, &inserted);
      self.inputRangeUpdates++;
    } else {
      if ([self.preview.string isEqualToString:self.rendered.string]) return;
      self.pendingRange = live_paragraph_difference(self.rendered.string,
        self.preview.string, &inserted);
      self.inputFullComparisons++;
    }
    self.pendingText = [self.preview.string substringWithRange:inserted];
    self.pendingProjectionRange = self.pendingRange;
    self.pendingProjectionLength = inserted.length;
    self.pendingProjectionEdit = YES;
    self.pendingSelectionEvent = NO;
    self.response = NSAlertFirstButtonReturn + 5;
    [NSApp stopModal];
    return;
  }
  if (!self.updating && !self.editor.hasMarkedText) {
    self.response = NSAlertFirstButtonReturn;
    [NSApp stopModal];
  }
}

- (void)textViewDidChangeSelection:(NSNotification*)notification {
  if (!self.direct || self.updating || notification.object != self.preview ||
    self.preview.hasMarkedText || self.inputStorageEdits != 0 ||
    ![self.preview.string isEqualToString:self.rendered.string]) return;
  self.pendingRange = self.preview.selectedRange;
  self.pendingSelectionAffinity = self.preview.selectionAffinity;
  self.pendingSelectionEvent = YES;
  self.pendingProjectionEdit = NO;
  self.response = NSAlertFirstButtonReturn + 4;
  [NSApp stopModal];
}

- (void)checkpointAction:(NSButton*)button {
  if (self.editor.hasMarkedText || self.preview.hasMarkedText) {
    return;
  }
  self.response = button.tag;
  [NSApp stopModal];
}

- (BOOL)windowShouldClose:(NSWindow*)window {
  self.response = NSAlertFirstButtonReturn + 3;
  [NSApp stopModal];
  return NO;
}

@end

static void live_paragraph_activate(void) {
  NSApplication* application = [NSApplication sharedApplication];
  [application setActivationPolicy:NSApplicationActivationPolicyRegular];
  [application finishLaunching];
  if (@available(macOS 14.0, *)) {
    [application activate];
  } else {
    [application activateIgnoringOtherApps:YES];
  }
}

static NSString* live_paragraph_utf8(const char* input, u64 input_length) {
  // Foundation treats a leading BOM as an encoding marker. In this editor it
  // is source content. A temporary ASCII prefix prevents that special case,
  // including multiple BOMs and BOM-only text; remove only the added prefix.
  BOOL bom = input_length >= 3 && !memcmp(input, "\xEF\xBB\xBF", 3);
  if (bom) {
    char* prefixed = malloc(input_length + 1);
    if (!prefixed) err_fail("LiveParagraph: allocation failed");
    prefixed[0] = 'x'; memcpy(prefixed + 1, input, input_length);
    NSString* decoded = [[NSString alloc] initWithBytes:prefixed
      length:input_length + 1 encoding:NSUTF8StringEncoding];
    free(prefixed);
    return decoded == nil ? @"" : [decoded substringFromIndex:1];
  }
  NSString* text = [[NSString alloc]
    initWithBytes:input
    length:input_length
    encoding:NSUTF8StringEncoding];
  return text == nil ? @"" : text;
}

static NSString* live_paragraph_string(Term value, Env e) {
  u64 input_length = 0;
  char* input = io_cstr(e, value, &input_length);
  NSString* text = live_paragraph_utf8(input, input_length);
  free(input);
  return text;
}

Term live_paragraph_open_run(Env e, Term* f, IoWork* w) {
  MarkBendLiveState* state = [MarkBendLiveState new];
  state.text = live_paragraph_string(f[0], e);
  state.rendered = [NSMutableAttributedString new];
  state.attributes = [NSMutableDictionary new];
  return io_hand((intptr_t)CFBridgingRetain(state));
}

Term live_paragraph_next_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (__bridge MarkBendLiveState*)(void*)handle;
  Term event;

  @autoreleasepool {
    if (state.alert == nil) {
    live_paragraph_activate();
    NSAlert* alert = [NSAlert new];
    NSView* accessory = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 620, 300)];
    NSRect editor_frame = NSMakeRect(0, 0, 620, 80);
    NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:editor_frame];
    MarkBendEditor* editor = [[MarkBendEditor alloc] initWithFrame:editor_frame];
    editor.session = state;
    NSScrollView* preview_scroll = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(0, 100, 620, 200)];
    MarkBendEditor* preview = [[MarkBendEditor alloc]
      initWithFrame:NSMakeRect(0, 0, 620, 200)];
    preview.session = state;
    alert.messageText = @"MarkBend paragraph editor";
    alert.informativeText =
      @"Edit the formatted text below. Active Markdown marks stay visible. Undo and Redo use Bend history.";
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;
    scroll.documentView = editor;
    editor.editable = YES;
    editor.selectable = YES;
    editor.richText = NO;
    editor.allowsUndo = NO;
    editor.automaticQuoteSubstitutionEnabled = NO;
    editor.automaticDashSubstitutionEnabled = NO;
    editor.automaticTextReplacementEnabled = NO;
    editor.automaticSpellingCorrectionEnabled = NO;
    editor.font = [NSFont systemFontOfSize:18];
    editor.string = state.text;
    editor.minSize = NSMakeSize(0, editor_frame.size.height);
    editor.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    editor.verticallyResizable = YES;
    editor.horizontallyResizable = NO;
    editor.autoresizingMask = NSViewWidthSizable;
    editor.textContainer.containerSize =
      NSMakeSize(editor_frame.size.width, CGFLOAT_MAX);
    editor.textContainer.widthTracksTextView = YES;
    editor.layoutManager.allowsNonContiguousLayout = YES;
    preview_scroll.borderType = NSBezelBorder;
    preview_scroll.backgroundColor = NSColor.textBackgroundColor;
    preview_scroll.documentView = preview;
    preview.editable = state.direct;
    preview.selectable = YES;
    preview.allowsUndo = NO;
    preview.richText = NO;
    preview.automaticQuoteSubstitutionEnabled = NO;
    preview.automaticDashSubstitutionEnabled = NO;
    preview.automaticTextReplacementEnabled = NO;
    preview.automaticSpellingCorrectionEnabled = NO;
    preview.verticallyResizable = YES;
    preview.horizontallyResizable = NO;
    preview.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    preview.textContainer.containerSize = NSMakeSize(620, CGFLOAT_MAX);
    preview.textContainer.widthTracksTextView = YES;
    preview.layoutManager.allowsNonContiguousLayout = YES;
    preview_scroll.hasVerticalScroller = YES;
    preview.drawsBackground = YES;
    preview.backgroundColor = NSColor.textBackgroundColor;
    preview.textColor = NSColor.textColor;
    [preview.textStorage setAttributedString:state.rendered];
    state.projectionBaselineKnown = YES;
    [accessory addSubview:scroll];
    [accessory addSubview:preview_scroll];
    alert.accessoryView = accessory;
    [alert addButtonWithTitle:@"Apply"];
    [alert addButtonWithTitle:@"Undo"];
    [alert addButtonWithTitle:@"Redo"];
    [alert addButtonWithTitle:@"Close"];
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Save As"];
    [alert addButtonWithTitle:@"Recheck Save As"];
    for (NSUInteger i = 0; i < alert.buttons.count; i++) {
      NSButton* button = alert.buttons[i];
      button.tag = NSAlertFirstButtonReturn + (i >= 4 ? i + 2 : i);
      button.target = state;
      button.action = @selector(checkpointAction:);
    }
    state.alert = alert;
    state.editor = editor;
    state.preview = preview;
    preview.delegate = state;
    preview.textStorage.delegate = state;
    editor.delegate = state;
    editor.textStorage.delegate = state;
    state.sourceFieldSynchronized = YES;
    alert.window.delegate = state;
    [alert layout];
    state.updating = YES;
    [alert.window makeFirstResponder:state.direct ? preview : editor];
    if (state.direct) preview.selectedRange = state.selection;
    state.updating = NO;
    [alert.window center];
    }

    state.response = NSAlertFirstButtonReturn + 3;
    [state.alert.window makeKeyAndOrderFront:nil];
    [NSApp runModalForWindow:state.alert.window];
    NSModalResponse response = state.response;
    if (response == NSAlertFirstButtonReturn + 9) {
      event = io_node(e, CID(ParagraphReturn), (Term)state.pendingRange.location,
        (Term)NSMaxRange(state.pendingRange));
    } else if (response == NSAlertFirstButtonReturn + 8) {
      event = term_pak(CID(ParagraphRecheckSaveAs), 0);
    } else if (response == NSAlertFirstButtonReturn + 7) {
      event = term_pak(CID(ParagraphChooseSaveAs), 0);
    } else if (response == NSAlertFirstButtonReturn + 6) {
      event = term_pak(CID(ParagraphSave), 0);
    } else if (response == NSAlertFirstButtonReturn + 4 ||
        response == NSAlertFirstButtonReturn + 5) {
      if (response == NSAlertFirstButtonReturn + 4) {
        event = io_node(e, CID(ParagraphSelected), (Term)state.pendingRange.location,
          (Term)NSMaxRange(state.pendingRange));
      } else {
        NSData* bytes = [state.pendingText dataUsingEncoding:NSUTF8StringEncoding];
        u64 at = heap_alloc(e, 2);
        e.mem[at] = (Term)state.pendingRange.location;
        e.mem[at + 1] = (Term)NSMaxRange(state.pendingRange);
        e.mem[at + 2] = io_seal(e, io_str(e, bytes.bytes, bytes.length), CID(ParagraphEdit));
        event = term_ctr(CID(ParagraphEdit), at);
      }
    } else if (response == NSAlertFirstButtonReturn) {
      state.text = state.editor.string;
      state.sourceFieldSynchronized = YES;
      NSData* bytes = [state.text dataUsingEncoding:NSUTF8StringEncoding];
      event = io_box(e, CID(ParagraphChanged),
        io_str(e, bytes.bytes, bytes.length));
    } else if (response == NSAlertSecondButtonReturn) {
      event = term_pak(CID(ParagraphUndo), 0);
    } else if (response == NSAlertThirdButtonReturn) {
      event = term_pak(CID(ParagraphRedo), 0);
    } else {
      event = term_pak(CID(ParagraphClosed), 0);
    }
  }

  return io_tup(e, io_hand(handle), event);
}

static void live_paragraph_begin_presentation(MarkBendLiveState* state) {
  state.presentationStarted = state.measurePresentation ? live_paragraph_now() : 0;
  state.runBuildSeconds = 0;
  state.presentationRunCount = 0;
  state.nativeChunksRebuilt = 0;
  state.nativeChunksReused = 0;
  state.nativeChunksTransferred = 0;
  state.chunkUpdateSeconds = 0;
  state.projectionComparisonSeconds = state.projectionStorageSeconds = 0;
  state.projectionPatchRanges = state.measurePresentation ? [NSMutableArray new] : nil;
  state.textConvertSeconds = state.styledRunSeconds = state.chunkCopySeconds = state.sceneAssemblySeconds = 0;
  state.sourceLookupSeconds = state.sourceCompareSeconds = state.sourceCopySeconds = 0;
  state.sourceStorageSeconds = state.sourceSelectionSeconds = 0;
  state.projectionPatchesApplied = NO;
  state.projectionFullComparisons = 0;
  state.projectionPatchCount = 0;
  state.projectionMaximumLength = 0;
  state.projectionRange = state.projectionRemovedRange = NSMakeRange(0, 0);
  state.rendered = [NSMutableAttributedString new];
}

Term live_paragraph_set_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (__bridge MarkBendLiveState*)(void*)handle;
  live_paragraph_begin_presentation(state);
  state.retainedScene = nil;
  state.nativeOrder = nil;
  state.projectionBaselineKnown = NO;
  state.pendingProjectionEdit = NO;
  state.inputStorageEdits = 0;
  state.text = live_paragraph_string(f[1], e);
  state.sourceIndex = live_source_build(state.text);
  state.indexedSource = state.text;
  if (state.editor != nil && ![state.editor.string isEqualToString:state.text]) {
    NSRange selection = state.editor.selectedRange;
    state.updating = YES;
    NSRange inserted;
    NSRange changed = live_paragraph_difference(state.editor.string, state.text, &inserted);
    [state.editor.textStorage replaceCharactersInRange:changed
      withString:[state.text substringWithRange:inserted]];
    selection.location = MIN(selection.location, state.text.length);
    selection.length = MIN(selection.length, state.text.length - selection.location);
    state.editor.selectedRange = selection;
    state.updating = NO;
  }
  if (!state.direct) [state.preview.textStorage setAttributedString:state.rendered];
  state.sourceFieldSynchronized = state.editor != nil;
  if (state.measurePresentation)
    state.sourceUpdateSeconds = live_paragraph_now() - state.presentationStarted;
  return io_hand(handle);
}

static NSRange live_paragraph_scalar_range(NSString* text, u64 start, u64 end) {
  u64 lo = MIN(start, end), hi = MAX(start, end), scalar = 0;
  if (hi == 0) return NSMakeRange(0, 0);
  NSUInteger size = text.length, at = 0, first = 0;
  unichar* chars = malloc(size * sizeof(unichar));
  if (size && !chars) err_fail("LiveParagraph: scalar range allocation failed");
  if (size) [text getCharacters:chars range:NSMakeRange(0, size)];
  while (at < size && scalar < hi) {
    if (scalar == lo) first = at;
    unichar c = chars[at++];
    if (c >= 0xD800 && c <= 0xDBFF && at < size &&
      chars[at] >= 0xDC00 && chars[at] <= 0xDFFF) at++;
    scalar++;
  }
  if (lo >= scalar) first = at;
  free(chars);
  return NSMakeRange(first, at - first);
}

Term live_paragraph_replace_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (__bridge MarkBendLiveState*)(void*)handle;
  state.retainedScene = state.rendered;
  live_paragraph_begin_presentation(state);
  NSString* inserted = live_paragraph_string(f[3], e);
  double phase = state.measurePresentation ? live_paragraph_now() : 0;
  if (state.indexedSource != state.text) {
    state.sourceIndex = live_source_build(state.text);
    state.indexedSource = state.text;
  }
  NSUInteger lo = MIN(MIN(f[1], f[2]), state.sourceIndex.scalars);
  NSUInteger hi = MIN(MAX(f[1], f[2]), state.sourceIndex.scalars);
  NSUInteger start = live_source_native(state.sourceIndex, lo);
  NSRange range = NSMakeRange(start, live_source_native(state.sourceIndex, hi) - start);
  if (state.measurePresentation) {
    state.sourceLookupSeconds = live_paragraph_now() - phase;
    phase = live_paragraph_now();
  }
  BOOL synchronized = state.sourceFieldSynchronized && state.editor.string.length == state.text.length;
  if (state.measurePresentation) {
    state.sourceCompareSeconds = live_paragraph_now() - phase;
    phase = live_paragraph_now();
  }
  BOOL changed = range.length != 0 || inserted.length != 0;
  if (changed) {
    state.sourceIndex = live_source_replace(state.sourceIndex, lo, hi, inserted);
    state.text = [state.text stringByReplacingCharactersInRange:range withString:inserted];
    state.indexedSource = state.text;
  }
  if (state.measurePresentation) {
    state.sourceCopySeconds = live_paragraph_now() - phase;
    phase = live_paragraph_now();
  }
  if (changed && state.editor != nil) {
    NSRange selection = state.editor.selectedRange;
    state.updating = YES;
    if (synchronized) {
      [state.editor.textStorage replaceCharactersInRange:range withString:inserted];
    } else {
      [state.editor.textStorage replaceCharactersInRange:NSMakeRange(0, state.editor.string.length)
        withString:state.text];
    }
    if (state.measurePresentation) {
      state.sourceStorageSeconds = live_paragraph_now() - phase;
      phase = live_paragraph_now();
    }
    selection.location = MIN(selection.location, state.text.length);
    selection.length = MIN(selection.length, state.text.length - selection.location);
    state.editor.selectedRange = selection;
    if (state.measurePresentation) state.sourceSelectionSeconds = live_paragraph_now() - phase;
    state.updating = NO;
    state.sourceFieldSynchronized = YES;
  }
  if (!state.direct) [state.preview.textStorage setAttributedString:state.rendered];
  if (state.measurePresentation)
    state.sourceUpdateSeconds = live_paragraph_now() - state.presentationStarted;
  return io_hand(handle);
}

static NSDictionary* live_paragraph_attributes(MarkBendLiveState* state, u32 style) {
  NSDictionary* cached = state.attributes[@(style)];
  if (cached) return cached;
  NSFont* font = [NSFont systemFontOfSize:20];
  if (style == 1) {
    font = [NSFont boldSystemFontOfSize:20];
  } else if (style == 2) {
    font = [[NSFontManager sharedFontManager] convertFont:font
      toHaveTrait:NSItalicFontMask];
  } else if (style == 3) {
    font = [NSFont monospacedSystemFontOfSize:20 weight:NSFontWeightRegular];
  } else if (style >= 4 && style <= 9) {
    const CGFloat sizes[] = {32, 28, 25, 22, 20, 18};
    font = [NSFont boldSystemFontOfSize:sizes[style - 4]];
  } else if (style == 10) {
    font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSItalicFontMask];
  }
  NSMutableParagraphStyle* paragraph = [NSMutableParagraphStyle new];
  if (style == 10) paragraph.headIndent = paragraph.firstLineHeadIndent = 18;
  if (style == 11) paragraph.headIndent = 22;
  NSDictionary* attributes = @{
      NSFontAttributeName: font,
      @"MarkBendRequestedFont": font,
      NSForegroundColorAttributeName: NSColor.textColor,
      NSParagraphStyleAttributeName: paragraph
    };
  state.attributes[@(style)] = attributes;
  return attributes;
}

Term live_paragraph_append_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (__bridge MarkBendLiveState*)(void*)handle;
  double started = state.measurePresentation ? live_paragraph_now() : 0;
  NSString* text = live_paragraph_string(f[1], e);
  double converted = state.measurePresentation ? live_paragraph_now() : 0;
  NSRange appended = NSMakeRange(state.rendered.length, text.length);
  [state.rendered.mutableString appendString:text];
  if (appended.length) [state.rendered setAttributes:live_paragraph_attributes(state, (u32)f[2]) range:appended];
  if (!state.direct) [state.preview.textStorage setAttributedString:state.rendered];
  if (state.measurePresentation) {
    state.textConvertSeconds += converted - started;
    state.styledRunSeconds += live_paragraph_now() - converted;
    state.runBuildSeconds += live_paragraph_now() - started;
    state.presentationRunCount++;
  }
  return io_hand(handle);
}

Term live_paragraph_project_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (__bridge MarkBendLiveState*)(void*)handle;
  double started = state.measurePresentation ? live_paragraph_now() : 0;
  state.direct = YES;
  state.updating = YES;
  if (!state.projectionPatchesApplied) {
    state.projectionBeforeLength = state.preview.string.length;
    state.projectionBeforeFirst = state.preview.string.length ? [state.preview.string characterAtIndex:0] : 0;
  }
  state.projectionAfterLength = state.rendered.length;
  state.projectionAfterFirst = state.rendered.length ? [state.rendered.string characterAtIndex:0] : 0;
  if (state.preview != nil && !state.projectionPatchesApplied) {
    NSUInteger patches, maximum;
    state.projectionRemovedRange =
      live_paragraph_update_storage_details(state.preview.textStorage, state.rendered, &patches, &maximum);
    state.projectionFullComparisons++;
    state.projectionPatchCount += patches;
    state.projectionMaximumLength = MAX(state.projectionMaximumLength, maximum);
    state.projectionRange = NSMakeRange(state.projectionRemovedRange.location,
      state.projectionAfterLength -
        (state.projectionBeforeLength - state.projectionRemovedRange.length));
  }
  state.projectionCount++;
  NSUInteger start = MIN((NSUInteger)f[1], state.rendered.length);
  NSUInteger end = MIN((NSUInteger)f[2], state.rendered.length);
  state.selection = NSMakeRange(MIN(start, end), MAX(start, end) - MIN(start, end));
  if (state.pendingSelectionEvent && NSEqualRanges(state.pendingRange, state.selection)) {
    [state.preview setSelectedRange:state.selection affinity:state.pendingSelectionAffinity stillSelecting:NO];
  } else if (!NSEqualRanges(state.preview.selectedRange, state.selection)) {
    state.preview.selectedRange = state.selection;
  }
  state.pendingSelectionEvent = NO;
  [state.preview scrollRangeToVisible:state.selection];
  state.preview.editable = YES;
  state.projectionBaselineKnown = state.preview != nil;
  state.pendingProjectionEdit = NO;
  state.inputStorageEdits = 0;
  state.updating = NO;
  if (state.measurePresentation)
    state.projectionSeconds = live_paragraph_now() - started;
  return io_hand(handle);
}

Term live_paragraph_close_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = CFBridgingRelease((void*)handle);
  state.editor.delegate = nil;
  state.editor.textStorage.delegate = nil;
  state.preview.delegate = nil;
  state.preview.textStorage.delegate = nil;
  state.alert.window.delegate = nil;
  [state.alert.window orderOut:nil];
  state.alert = nil;
  state.editor = nil;
  state.preview = nil;
  state.text = nil;
  state.rendered = nil;
  state.retainedScene = nil;
  state.attributes = nil;
  state.nativeChunks = nil;
  state.nativeOrder = nil;
  return term_pak(CID(Unit), 0);
}

#else

typedef struct {
  u64 id;
  char* preview;
  u64 length;
  u64 native_length;
} MarkBendTerminalChunk;

typedef struct {
  char* text;
  u64 length;
  char* input_draft;
  u64 input_draft_length;
  char* preview;
  u64 preview_length;
  u64 preview_native_length;
  u32 selection_start;
  u32 selection_end;
  MarkBendTerminalChunk* chunks;
  u64 chunk_count;
  int chunk_baseline;
  char* retained_preview;
  u64 retained_preview_length;
  u64 retained_preview_native;
} MarkBendLiveState;

static void live_paragraph_terminal_clear_chunks(MarkBendLiveState* state) {
  for (u64 i = 0; i < state->chunk_count; i++) free(state->chunks[i].preview);
  free(state->chunks);
  state->chunks = NULL;
  state->chunk_count = 0;
  state->chunk_baseline = 0;
}

static void live_paragraph_store(
  MarkBendLiveState* state, const char* text, u64 length
) {
  char* copy = malloc(length + 1);
  if (copy == NULL) {
    err_fail("LiveParagraph: allocation failed");
  }
  memcpy(copy, text, length);
  copy[length] = 0;
  free(state->text);
  state->text = copy;
  state->length = length;
}

Term live_paragraph_open_run(Env e, Term* f, IoWork* w) {
  u64 input_length = 0;
  char* input = io_cstr(e, f[0], &input_length);
  MarkBendLiveState* state = calloc(1, sizeof(MarkBendLiveState));
  if (state == NULL) {
    free(input);
    err_fail("LiveParagraph: allocation failed");
  }
  live_paragraph_store(state, input, input_length);
  state->preview = malloc(input_length + 1);
  if (state->preview == NULL) {
    free(input);
    free(state->text);
    free(state);
    err_fail("LiveParagraph: allocation failed");
  }
  memcpy(state->preview, input, input_length + 1);
  state->preview_length = input_length;
  free(input);
  return io_hand((intptr_t)state);
}

Term live_paragraph_next_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (MarkBendLiveState*)(void*)handle;
  char* line = NULL;
  size_t line_capacity = 0;
  char* draft = malloc(1);
  u64 draft_length = 0;
  Term event = term_pak(CID(ParagraphInputEnded), 0);

  if (draft == NULL) {
    err_fail("LiveParagraph: allocation failed");
  }
  draft[0] = 0;
  fputs("\n--- MarkBend multiline checkpoint ---\nPreview: ", stderr);
  fwrite(state->preview, 1, state->preview_length, stderr);
  fputs("\nSource: ", stderr);
  fwrite(state->text, 1, state->length, stderr);
  fputs("\n"
    "Enter replacement text, then .apply on its own line.\n"
    "Commands: .undo .redo .return .save .saveas PATH .recheck .close\n> ", stderr);
  fflush(stderr);

  ssize_t line_size;
  while ((line_size = getline(&line, &line_capacity, stdin)) >= 0) {
    if (line_size == 8 && !memcmp(line, ".return\n", 8) && draft_length == 0) {
      event = io_node(e, CID(ParagraphReturn), state->selection_start, state->selection_end);
      break;
    }
    if (line_size == 9 && !memcmp(line, ".recheck\n", 9) && draft_length == 0) {
      event = term_pak(CID(ParagraphRecheckSaveAs), 0); break;
    }
    if (draft_length == 0 && ((line_size == 8 && !memcmp(line, ".saveas\n", 8)) ||
        (line_size >= 9 && !memcmp(line, ".saveas ", 8)))) {
      u64 path_size = line_size == 8 ? 0 : (u64)line_size - 9;
      event = io_box(e, CID(ParagraphSaveAs), io_str(e, line + 8, path_size));
      break;
    }
    if (line_size == 6 && !memcmp(line, ".save\n", 6) && draft_length == 0) {
      event = term_pak(CID(ParagraphSave), 0);
      break;
    }
    if (line_size == 6 && !memcmp(line, ".undo\n", 6) && draft_length == 0) {
      event = term_pak(CID(ParagraphUndo), 0);
      break;
    }
    if (line_size == 6 && !memcmp(line, ".redo\n", 6) && draft_length == 0) {
      event = term_pak(CID(ParagraphRedo), 0);
      break;
    }
    if (line_size == 7 && !memcmp(line, ".close\n", 7) && draft_length == 0) {
      event = term_pak(CID(ParagraphClosed), 0);
      break;
    }
    if (line_size == 7 && !memcmp(line, ".apply\n", 7)) {
      live_paragraph_store(state, draft, draft_length);
      event = io_box(e, CID(ParagraphChanged),
        io_str(e, state->text, state->length));
      break;
    }

    u64 line_length = (u64)line_size;
    char* grown = realloc(draft, draft_length + line_length + 1);
    if (grown == NULL) {
      free(draft);
      free(line);
      err_fail("LiveParagraph: allocation failed");
    }
    draft = grown;
    memcpy(draft + draft_length, line, line_length + 1);
    draft_length += line_length;
  }

  if (line_size < 0 && draft_length) {
    free(state->input_draft);
    state->input_draft = draft;
    state->input_draft_length = draft_length;
    draft = NULL;
    event = term_pak(CID(ParagraphDraftEnded), 0);
  }
  free(draft);
  free(line);
  return io_tup(e, io_hand(handle), event);
}

Term live_paragraph_set_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (MarkBendLiveState*)(void*)handle;
  u64 input_length = 0;
  char* input = io_cstr(e, f[1], &input_length);
  live_paragraph_store(state, input, input_length);
  free(input);
  state->preview_length = 0;
  state->preview_native_length = 0;
  state->preview[0] = 0;
  live_paragraph_terminal_clear_chunks(state);
  free(state->retained_preview);
  state->retained_preview = NULL;
  return io_hand(handle);
}

static u64 live_paragraph_scalar_byte(const char* text, u64 length, u64 position) {
  u64 at = 0, scalar = 0;
  while (at < length && scalar < position) {
    at++;
    while (at < length && ((unsigned char)text[at] & 0xC0) == 0x80) at++;
    scalar++;
  }
  return at;
}

Term live_paragraph_replace_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (MarkBendLiveState*)(void*)handle;
  u64 insertedLength;
  char* inserted = io_cstr(e, f[3], &insertedLength);
  u64 start = live_paragraph_scalar_byte(state->text, state->length, f[1] < f[2] ? f[1] : f[2]);
  u64 end = live_paragraph_scalar_byte(state->text, state->length, f[1] > f[2] ? f[1] : f[2]);
  u64 length = start + insertedLength + state->length - end;
  char* text = malloc(length + 1);
  if (!text) err_fail("LiveParagraph: source replacement allocation failed");
  memcpy(text, state->text, start);
  memcpy(text + start, inserted, insertedLength);
  memcpy(text + start + insertedLength, state->text + end, state->length - end);
  text[length] = 0;
  free(inserted); free(state->text);
  state->text = text;
  state->length = length;
  free(state->retained_preview);
  state->retained_preview = state->preview;
  state->retained_preview_length = state->preview_length;
  state->retained_preview_native = state->preview_native_length;
  state->preview = calloc(1, 1);
  if (!state->preview) err_fail("LiveParagraph: preview allocation failed");
  state->preview_length = 0;
  state->preview_native_length = 0;
  state->preview[0] = 0;
  return io_hand(handle);
}

Term live_paragraph_append_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (MarkBendLiveState*)(void*)handle;
  u64 length = 0;
  char* text = io_cstr(e, f[1], &length);
  for (u64 i = 0; i < length; i++) {
    unsigned char c = (unsigned char)text[i];
    if ((c & 0xC0) != 0x80) state->preview_native_length += c >= 0xF0 ? 2 : 1;
  }
  u32 style = (u32)f[2];
  int styled = style == 1 || style == 2 || style == 3 || (style >= 4 && style <= 10);
  u64 preview_length = state->preview_length + length + (styled ? 8 : 0);
  char* preview_copy = realloc(state->preview, preview_length + 1);
  if (preview_copy == NULL) {
    free(text);
    err_fail("LiveParagraph: allocation failed");
  }
  state->preview = preview_copy;
  u64 at = state->preview_length;
  if (styled) {
    memcpy(state->preview + at,
      style == 1 || (style >= 4 && style <= 9) ? "\033[1m" :
        style == 2 || style == 10 ? "\033[3m" : "\033[7m", 4);
    at += 4;
  }
  memcpy(state->preview + at, text, length);
  at += length;
  if (styled) {
    memcpy(state->preview + at, "\033[0m", 4);
    at += 4;
  }
  state->preview[at] = 0;
  state->preview_length = at;
  free(text);
  return io_hand(handle);
}

Term live_paragraph_close_run(Env e, Term* f, IoWork* w) {
  intptr_t handle = (intptr_t)io_hand_v(f[0]);
  MarkBendLiveState* state = (MarkBendLiveState*)(void*)handle;
  free(state->text);
  free(state->preview);
  free(state->retained_preview);
  free(state->input_draft);
  live_paragraph_terminal_clear_chunks(state);
  free(state);
  return term_pak(CID(Unit), 0);
}

// The terminal checkpoint has no native pointer selection. Keep the same effect
// contract; formatted text is already in its ANSI preview buffer.
Term live_paragraph_project_run(Env e, Term* f, IoWork* w) {
  MarkBendLiveState* state = (MarkBendLiveState*)(void*)(intptr_t)io_hand_v(f[0]);
  state->selection_start = f[1];
  state->selection_end = f[2];
  return f[0];
}

#endif

// The list and each Run own two fields. Consume through the runtime helpers so
// shared cached scenes remain valid. io_cstr consumes the owned text field.
Term live_paragraph_append_scene_run(Env e, Term* f, IoWork* w) {
  Term runs = f[1];
  while (term_aux(runs) == CID(Con)) {
    Term listFields[2], runFields[2];
    spare_free(e, cls_fit(2), ctr_take(e, runs, 2, listFields));
    spare_free(e, cls_fit(2), ctr_take(e, listFields[0], 2, runFields));
    Term args[3] = {f[0], runFields[0], runFields[1]};
    live_paragraph_append_run(e, args, w);
    runs = listFields[1];
  }
  return f[0];
}

#if defined(__APPLE__)
// Translate one scene patch to the field that already contains the native edit.
// A covering patch consumes that edit. Disjoint patches move its position or
// their own position. Partial overlap uses the complete comparison path.
static BOOL live_paragraph_projection_range(NSRange patch, NSUInteger replacement,
  BOOL* pending, NSRange* edit, NSUInteger inserted, NSRange* actual) {
  *actual = patch;
  if (!*pending) return YES;
  if (patch.location <= edit->location && NSMaxRange(patch) >= NSMaxRange(*edit)) {
    actual->length = patch.length - edit->length + inserted;
    *pending = NO;
    return YES;
  }
  if (NSMaxRange(patch) <= edit->location) {
    edit->location = edit->location - patch.length + replacement;
    return YES;
  }
  if (patch.location >= NSMaxRange(*edit)) {
    actual->location = patch.location - edit->length + inserted;
    return YES;
  }
  return NO;
}

static NSAttributedString* live_paragraph_native_chunk(Env e, Term handle, Term* fields, IoWork* w) {
  MarkBendLiveState* state = (__bridge MarkBendLiveState*)(void*)(intptr_t)io_hand_v(handle);
  NSNumber* key = @((unsigned long long)fields[0]);
  NSAttributedString* cached = state.nativeChunks[key];
  // Bool record fields are unboxed; direct Bool effect arguments are constructors.
  if (!cached || fields[1] != 0) {
    typedef struct { NSRange range; u32 style; } NativeRunRange;
    NativeRunRange stack[8], *ranges = stack;
    NSUInteger count = 0, capacity = 8;
    NSMutableString* text = [NSMutableString new];
    Term runs = fields[2];
    double runStarted = state.measurePresentation ? live_paragraph_now() : 0;
    while (term_aux(runs) == CID(Con)) {
      Term list[2], run[2];
      spare_free(e, cls_fit(2), ctr_take(e, runs, 2, list));
      spare_free(e, cls_fit(2), ctr_take(e, list[0], 2, run));
      double convertStarted = state.measurePresentation ? live_paragraph_now() : 0;
      NSString* part = live_paragraph_string(run[0], e);
      if (state.measurePresentation) state.textConvertSeconds += live_paragraph_now() - convertStarted;
      if (count == capacity) {
        capacity *= 2;
        NativeRunRange* grown = malloc(capacity * sizeof(*grown));
        if (!grown) err_fail("LiveParagraph: native run range allocation failed");
        memcpy(grown, ranges, count * sizeof(*grown));
        if (ranges != stack) free(ranges);
        ranges = grown;
      }
      ranges[count++] = (NativeRunRange){NSMakeRange(text.length, part.length), (u32)run[1]};
      [text appendString:part];
      runs = list[1];
    }
    double styleStarted = state.measurePresentation ? live_paragraph_now() : 0;
    NSMutableAttributedString* built = [[NSMutableAttributedString alloc] initWithString:text];
    for (NSUInteger i = 0; i < count; i++) if (ranges[i].range.length)
      [built setAttributes:live_paragraph_attributes(state, ranges[i].style) range:ranges[i].range];
    if (ranges != stack) free(ranges);
    if (state.measurePresentation) {
      state.styledRunSeconds += live_paragraph_now() - styleStarted;
      state.runBuildSeconds += live_paragraph_now() - runStarted;
      state.presentationRunCount += count;
    }
    double copyStarted = state.measurePresentation ? live_paragraph_now() : 0;
    cached = built.copy;
    if (state.measurePresentation) state.chunkCopySeconds += live_paragraph_now() - copyStarted;
    state.nativeChunksRebuilt++;
  } else {
    term_sink(e, fields[2]);
    state.nativeChunksReused++;
  }
  return cached;
}
#else
static MarkBendTerminalChunk live_paragraph_terminal_chunk(Env e, Term handle, Term* fields, IoWork* w) {
  MarkBendLiveState* state = (void*)(intptr_t)io_hand_v(handle);
  char* previous = state->preview;
  u64 length = state->preview_length, native = state->preview_native_length;
  state->preview = calloc(1, 1);
  if (!state->preview) err_fail("LiveParagraph: chunk allocation failed");
  state->preview_length = state->preview_native_length = 0;
  Term args[2] = {handle, fields[2]};
  live_paragraph_append_scene_run(e, args, w);
  MarkBendTerminalChunk chunk = {fields[0], state->preview,
    state->preview_length, state->preview_native_length};
  state->preview = previous;
  state->preview_length = length;
  state->preview_native_length = native;
  return chunk;
}

static void live_paragraph_terminal_assemble(MarkBendLiveState* state) {
  u64 length = 0, native = 0;
  for (u64 i = 0; i < state->chunk_count; i++) {
    length += state->chunks[i].length;
    native += state->chunks[i].native_length;
  }
  char* preview = malloc(length + 1);
  if (!preview) err_fail("LiveParagraph: preview allocation failed");
  u64 at = 0;
  for (u64 i = 0; i < state->chunk_count; i++) {
    memcpy(preview + at, state->chunks[i].preview, state->chunks[i].length);
    at += state->chunks[i].length;
  }
  preview[length] = 0;
  free(state->preview);
  state->preview = preview;
  state->preview_length = length;
  state->preview_native_length = native;
}
#endif

Term live_paragraph_append_chunks_run(Env e, Term* f, IoWork* w) {
  Term chunks = f[1];
#if defined(__APPLE__)
  MarkBendLiveState* state = (__bridge MarkBendLiveState*)(void*)(intptr_t)io_hand_v(f[0]);
  BOOL cacheable = term_aux(f[2]) == CID(True);
  double started = state.measurePresentation ? live_paragraph_now() : 0;
  NSMutableDictionary* nextCache = [NSMutableDictionary new];
  NSMutableArray* nextOrder = [NSMutableArray new];
  NSMutableAttributedString* assembled = state.rendered;
  state.retainedScene = nil;
  state.projectionBaselineKnown = NO;
  state.projectionPatchesApplied = NO;
#else
  MarkBendLiveState* state = (void*)(intptr_t)io_hand_v(f[0]);
  int cacheable = term_aux(f[2]) == CID(True);
  MarkBendTerminalChunk* nextChunks = NULL;
  u64 nextCount = 0, nextCapacity = 0;
#endif
  while (term_aux(chunks) == CID(Con)) {
    Term listFields[2], chunkFields[3];
    spare_free(e, cls_fit(2), ctr_take(e, chunks, 2, listFields));
    spare_free(e, cls_fit(3), ctr_take(e, listFields[0], 3, chunkFields));
#if defined(__APPLE__)
    state.nativeChunksTransferred++;
    // Native Nat values are exact 48-bit integers in Bend 2.0.34.
    NSNumber* key = @((unsigned long long)chunkFields[0]);
    if (!cacheable) chunkFields[1] = 1;
    NSAttributedString* cached = live_paragraph_native_chunk(e, f[0], chunkFields, w);
    double assemblyStarted = state.measurePresentation ? live_paragraph_now() : 0;
    [assembled appendAttributedString:cached];
    if (cacheable) { nextCache[key] = cached; [nextOrder addObject:key]; }
    if (state.measurePresentation) state.sceneAssemblySeconds += live_paragraph_now() - assemblyStarted;
#else
    if (cacheable) {
      if (nextCount == nextCapacity) {
        nextCapacity = nextCapacity ? 2 * nextCapacity : 8;
        MarkBendTerminalChunk* grown = realloc(nextChunks, nextCapacity * sizeof(*grown));
        if (!grown) err_fail("LiveParagraph: chunk list allocation failed");
        nextChunks = grown;
      }
      nextChunks[nextCount++] = live_paragraph_terminal_chunk(e, f[0], chunkFields, w);
    } else {
      Term args[2] = {f[0], chunkFields[2]};
      live_paragraph_append_scene_run(e, args, w);
    }
#endif
    chunks = listFields[1];
  }
#if defined(__APPLE__)
  // Keep only this presentation's blocks. Legacy single scenes clear the cache.
  state.nativeChunks = cacheable ? nextCache : nil;
  state.nativeOrder = cacheable ? nextOrder : nil;
  if (!state.direct && state.preview) {
    BOOL wasUpdating = state.updating;
    state.updating = YES;
    [state.preview.textStorage setAttributedString:assembled];
    state.updating = wasUpdating;
  }
  if (state.measurePresentation) state.chunkUpdateSeconds = live_paragraph_now() - started;
#else
  live_paragraph_terminal_clear_chunks(state);
  free(state->retained_preview);
  state->retained_preview = NULL;
  if (cacheable) {
    state->chunks = nextChunks;
    state->chunk_count = nextCount;
    state->chunk_baseline = 1;
    live_paragraph_terminal_assemble(state);
  }
#endif
  return f[0];
}

Term live_paragraph_patch_chunks_run(Env e, Term* f, IoWork* w) {
  Term patches = f[1];
#if defined(__APPLE__)
  MarkBendLiveState* state = (__bridge MarkBendLiveState*)(void*)(intptr_t)io_hand_v(f[0]);
  double started = state.measurePresentation ? live_paragraph_now() : 0;
  if (state.retainedScene) state.rendered = state.retainedScene;
  state.retainedScene = nil;
  BOOL projecting = state.projectionBaselineKnown && state.preview != nil && !state.preview.hasMarkedText;
  BOOL pending = state.pendingProjectionEdit;
  NSRange edit = state.pendingProjectionRange;
  NSUInteger nativeInserted = state.pendingProjectionLength;
  if (projecting && pending) {
    if (edit.location > state.rendered.length || edit.length > state.rendered.length - edit.location ||
        state.preview.string.length != state.rendered.length - edit.length + nativeInserted) projecting = NO;
  } else if (projecting && state.preview.string.length != state.rendered.length) {
    projecting = NO;
  }
  state.projectionBeforeLength = state.preview.string.length;
  state.projectionBeforeFirst = state.preview.string.length ? [state.preview.string characterAtIndex:0] : 0;
  BOOL wasUpdating = state.updating;
  state.updating = YES;
#else
  MarkBendLiveState* state = (void*)(intptr_t)io_hand_v(f[0]);
  if (term_aux(patches) == CID(Con) && !state->chunk_baseline)
    err_fail("LiveParagraph: scene patch needs a complete baseline");
#endif
  while (term_aux(patches) == CID(Con)) {
    Term list[2], patch[5];
    spare_free(e, cls_fit(2), ctr_take(e, patches, 2, list));
    spare_free(e, cls_fit(5), ctr_take(e, list[0], 5, patch));
    u64 first = patch[0], removed = patch[1], start = patch[2], length = patch[3];
    Term chunks = patch[4];
#if defined(__APPLE__)
    if (!state.nativeOrder || first > state.nativeOrder.count || removed > state.nativeOrder.count - first ||
        start > state.rendered.length || length > state.rendered.length - start)
      err_fail("LiveParagraph: scene patch range failed");
    NSArray* discarded = [state.nativeOrder subarrayWithRange:NSMakeRange(first, removed)];
    NSMutableArray* inserted = [NSMutableArray new];
    NSMutableAttributedString* replacement = [NSMutableAttributedString new];
#else
    if (first > state->chunk_count || removed > state->chunk_count - first)
      err_fail("LiveParagraph: scene patch block range failed");
    u64 expectedStart = 0, expectedLength = 0;
    for (u64 i = 0; i < first; i++) expectedStart += state->chunks[i].native_length;
    for (u64 i = first; i < first + removed; i++) expectedLength += state->chunks[i].native_length;
    if (start != expectedStart || length != expectedLength)
      err_fail("LiveParagraph: scene patch native range failed");
    MarkBendTerminalChunk* inserted = NULL;
    u64 insertedCount = 0, capacity = 0;
#endif
    while (term_aux(chunks) == CID(Con)) {
      Term chunkList[2], chunk[3];
      spare_free(e, cls_fit(2), ctr_take(e, chunks, 2, chunkList));
      spare_free(e, cls_fit(3), ctr_take(e, chunkList[0], 3, chunk));
#if defined(__APPLE__)
      NSNumber* key = @((unsigned long long)chunk[0]);
      state.nativeChunksTransferred++;
      NSAttributedString* value = live_paragraph_native_chunk(e, f[0], chunk, w);
      [replacement appendAttributedString:value];
      state.nativeChunks[key] = value;
      [inserted addObject:key];
#else
      if (insertedCount == capacity) {
        capacity = capacity ? 2 * capacity : 8;
        MarkBendTerminalChunk* grown = realloc(inserted, capacity * sizeof(*grown));
        if (!grown) err_fail("LiveParagraph: scene patch allocation failed");
        inserted = grown;
      }
      inserted[insertedCount++] = live_paragraph_terminal_chunk(e, f[0], chunk, w);
#endif
      chunks = chunkList[1];
    }
#if defined(__APPLE__)
    if (projecting) {
      NSRange actual;
      if (!live_paragraph_projection_range(NSMakeRange(start, length), replacement.length,
          &pending, &edit, nativeInserted, &actual) || actual.location > state.preview.string.length ||
          actual.length > state.preview.string.length - actual.location) {
        projecting = NO;
      } else if (actual.length || replacement.length) {
        NSAttributedString* projected = replacement;
        if (!state.pendingProjectionEdit) {
          double comparison = state.measurePresentation ? live_paragraph_now() : 0;
          NSAttributedString* before = [state.preview.textStorage attributedSubstringFromRange:actual];
          NSRange insertedRange;
          NSRange middle = live_paragraph_patch_middle(before, replacement, &insertedRange);
          actual = NSMakeRange(actual.location + middle.location, middle.length);
          projected = [replacement attributedSubstringFromRange:insertedRange];
          if (state.measurePresentation) state.projectionComparisonSeconds += live_paragraph_now() - comparison;
        }
        double storage = state.measurePresentation ? live_paragraph_now() : 0;
        if (actual.length || projected.length)
          [state.preview.textStorage replaceCharactersInRange:actual withAttributedString:projected];
        if (state.measurePresentation) state.projectionStorageSeconds += live_paragraph_now() - storage;
        if (state.measurePresentation && (actual.length || projected.length))
          [state.projectionPatchRanges addObject:@[[NSValue valueWithRange:actual],
            [NSValue valueWithRange:NSMakeRange(actual.location, projected.length)]]];
        state.projectionRemovedRange = actual;
        state.projectionRange = NSMakeRange(actual.location, projected.length);
        state.projectionMaximumLength = MAX(state.projectionMaximumLength, MAX(actual.length, projected.length));
        if (actual.length || projected.length) state.projectionPatchCount++;
      }
    }
    [state.rendered replaceCharactersInRange:NSMakeRange(start, length) withAttributedString:replacement];
    [state.nativeOrder replaceObjectsInRange:NSMakeRange(first, removed) withObjectsFromArray:inserted];
    NSSet* retained = [NSSet setWithArray:inserted];
    for (NSNumber* key in discarded) if (![retained containsObject:key]) [state.nativeChunks removeObjectForKey:key];
#else
    u64 count = state->chunk_count - removed + insertedCount;
    MarkBendTerminalChunk* next = count ? malloc(count * sizeof(*next)) : NULL;
    if (count && !next) err_fail("LiveParagraph: scene patch list allocation failed");
    if (first) memcpy(next, state->chunks, first * sizeof(*next));
    if (insertedCount) memcpy(next + first, inserted, insertedCount * sizeof(*next));
    u64 suffix = state->chunk_count - first - removed;
    if (suffix) memcpy(next + first + insertedCount, state->chunks + first + removed, suffix * sizeof(*next));
    for (u64 i = first; i < first + removed; i++) free(state->chunks[i].preview);
    free(inserted); free(state->chunks);
    state->chunks = next;
    state->chunk_count = count;
#endif
    patches = list[1];
  }
#if defined(__APPLE__)
  state.projectionPatchesApplied = projecting && !pending;
  state.updating = wasUpdating;
  state.nativeChunksReused = state.nativeChunks.count - MIN(state.nativeChunksRebuilt, state.nativeChunks.count);
  if (state.measurePresentation) state.chunkUpdateSeconds = live_paragraph_now() - started;
#else
  // The terminal keeps the same patch contract but assembles its ANSI view in full.
  if (state->chunk_baseline) {
    live_paragraph_terminal_assemble(state);
  } else if (state->retained_preview) {
    free(state->preview);
    state->preview = state->retained_preview;
    state->preview_length = state->retained_preview_length;
    state->preview_native_length = state->retained_preview_native;
    state->retained_preview = NULL;
  }
  free(state->retained_preview);
  state->retained_preview = NULL;
#endif
  return f[0];
}

Term live_paragraph_status_run(Env e, Term* f, IoWork* w) {
#if defined(__APPLE__)
  MarkBendLiveState* state = (__bridge MarkBendLiveState*)(void*)(intptr_t)io_hand_v(f[0]);
  state.alert.informativeText = live_paragraph_string(f[1], e);
#else
  u64 length = 0;
  char* message = io_cstr(e, f[1], &length);
  fwrite(message, 1, length, stderr); fputc('\n', stderr); free(message);
#endif
  return f[0];
}

#ifdef MARKBEND_HOST_ALL_EFFECTS
#define MARKBEND_PICK_SAVE_AS_EFFECT 1
#else
#ifdef CID(LiveParagraph.pick_save_as)
#define MARKBEND_PICK_SAVE_AS_EFFECT 1
#endif
#endif
#ifdef MARKBEND_PICK_SAVE_AS_EFFECT
Term live_paragraph_pick_save_as_run(Env e, Term* f, IoWork* w) {
  Term choice = term_pak(CID(SaveAsPickerUnavailable), 0);
#if defined(__APPLE__)
  @autoreleasepool {
    choice = term_pak(CID(SaveAsCancelled), 0);
    NSSavePanel* panel = [NSSavePanel savePanel];
    panel.title = @"Save As";
    panel.nameFieldStringValue = @"Untitled.md";
    panel.canCreateDirectories = YES;
#ifdef MARKBEND_SAVE_AS_PREPARE
    MARKBEND_SAVE_AS_PREPARE(panel);
#endif
    if ([panel runModal] == NSModalResponseOK) {
      NSData* path = [panel.URL.path dataUsingEncoding:NSUTF8StringEncoding];
#ifdef MARKBEND_SAVE_AS_SELECTED
      if (path) MARKBEND_SAVE_AS_SELECTED(path.bytes, path.length);
#endif
      if (path) choice = io_box(e, CID(SaveAsSelected), io_str(e, path.bytes, path.length));
      else choice = term_pak(CID(SaveAsPickerUnavailable), 0);
    }
  }
#endif
  return io_tup(e, f[0], choice);
}
#endif

Term live_paragraph_close_choice_run(Env e, Term* f, IoWork* w) {
  u32 choice = 0;
#if defined(__APPLE__)
  @autoreleasepool {
    NSAlert* alert = [NSAlert new];
    alert.messageText = @"Save changes before closing?";
    alert.informativeText = @"Cancel keeps this document open. Discard closes without saving.";
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Discard"];
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) choice = 1;
    if (response == NSAlertThirdButtonReturn) choice = 2;
  }
#else
  char* line = NULL;
  size_t capacity = 0;
  fputs("Unsaved changes. Enter .save, .discard, or .cancel:\n", stderr);
  fflush(stderr);
  ssize_t size = getline(&line, &capacity, stdin);
  if (size < 0) choice = 3;
  if (size >= 0) {
    if (size == 6 && !memcmp(line, ".save\n", 6)) choice = 1;
    if (size == 9 && !memcmp(line, ".discard\n", 9)) choice = 2;
  }
  free(line);
#endif
  return io_tup(e, f[0], (Term)choice);
}

static void __attribute__((constructor)) live_paragraph_use(void) {
#ifdef MARKBEND_HOST_ALL_EFFECTS
  io_eff(CID(LiveParagraph.pick_save_as), live_paragraph_pick_save_as_run, 0);
  io_eff(CID(LiveParagraph.open), live_paragraph_open_run, 0);
  io_eff(CID(LiveParagraph.next), live_paragraph_next_run, 0);
  io_eff(CID(LiveParagraph.set), live_paragraph_set_run, 0);
  io_eff(CID(LiveParagraph.replace), live_paragraph_replace_run, 0);
  io_eff(CID(LiveParagraph.append_chunks), live_paragraph_append_chunks_run, 0);
  io_eff(CID(LiveParagraph.patch_chunks), live_paragraph_patch_chunks_run, 0);
  io_eff(CID(LiveParagraph.close), live_paragraph_close_run, 0);
  io_eff(CID(LiveParagraph.project), live_paragraph_project_run, 0);
  io_eff(CID(LiveParagraph.close_choice), live_paragraph_close_choice_run, 0);
  io_eff(CID(LiveParagraph.status), live_paragraph_status_run, 0);
#else
#ifdef CID(LiveParagraph.pick_save_as)
  io_eff(CID(LiveParagraph.pick_save_as), live_paragraph_pick_save_as_run, 0);
#endif
#ifdef CID(LiveParagraph.open)
  io_eff(CID(LiveParagraph.open), live_paragraph_open_run, 0);
#endif
#ifdef CID(LiveParagraph.next)
  io_eff(CID(LiveParagraph.next), live_paragraph_next_run, 0);
#endif
#ifdef CID(LiveParagraph.set)
  io_eff(CID(LiveParagraph.set), live_paragraph_set_run, 0);
#endif
#ifdef CID(LiveParagraph.replace)
  io_eff(CID(LiveParagraph.replace), live_paragraph_replace_run, 0);
#endif
#ifdef CID(LiveParagraph.append_chunks)
  io_eff(CID(LiveParagraph.append_chunks), live_paragraph_append_chunks_run, 0);
#endif
#ifdef CID(LiveParagraph.patch_chunks)
  io_eff(CID(LiveParagraph.patch_chunks), live_paragraph_patch_chunks_run, 0);
#endif
#ifdef CID(LiveParagraph.close)
  io_eff(CID(LiveParagraph.close), live_paragraph_close_run, 0);
#endif
#ifdef CID(LiveParagraph.project)
  io_eff(CID(LiveParagraph.project), live_paragraph_project_run, 0);
#endif
#ifdef CID(LiveParagraph.close_choice)
  io_eff(CID(LiveParagraph.close_choice), live_paragraph_close_choice_run, 0);
#endif
#ifdef CID(LiveParagraph.status)
  io_eff(CID(LiveParagraph.status), live_paragraph_status_run, 0);
#endif
#endif
}
