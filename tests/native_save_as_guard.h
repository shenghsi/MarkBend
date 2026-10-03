#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#import <Cocoa/Cocoa.h>
static void markbend_save_as_prepare(NSSavePanel* panel) {
  const char* target = getenv("MARKBEND_SAVE_AS_TARGET");
  if (!target) _Exit(91);
  NSString* path = [NSString stringWithUTF8String:target];
  panel.directoryURL = [NSURL fileURLWithPath:path.stringByDeletingLastPathComponent isDirectory:YES];
  panel.nameFieldStringValue = path.lastPathComponent;
}
#define MARKBEND_SAVE_AS_PREPARE(panel) markbend_save_as_prepare(panel)
static void markbend_save_as_selected(const void* bytes, size_t size) {
  const char* expected = getenv("MARKBEND_SAVE_AS_TARGET");
  if (!expected || strlen(expected) != size || memcmp(expected, bytes, size)) {
    fputs("Native Save As selected a path outside the private fixture; publication stopped\n", stderr);
    _Exit(91);
  }
}
#define MARKBEND_SAVE_AS_SELECTED(bytes, size) markbend_save_as_selected(bytes, size)
