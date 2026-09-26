#if defined(__APPLE__)

#import <Cocoa/Cocoa.h>

Term native_paragraph_edit_run(Env e, Term* f, IoWork* w) {
  u64 input_length = 0;
  char* input = io_cstr(e, f[0], &input_length);
  Term result;

  @autoreleasepool {
    NSApplication* application = [NSApplication sharedApplication];
    [application setActivationPolicy:NSApplicationActivationPolicyRegular];
    [application finishLaunching];
    if (@available(macOS 14.0, *)) {
      [application activate];
    } else {
      [application activateIgnoringOtherApps:YES];
    }

    NSString* initial = [[NSString alloc]
      initWithBytes:input
      length:input_length
      encoding:NSUTF8StringEncoding];
    NSAlert* alert = [[NSAlert alloc] init];
    NSTextField* field = [[NSTextField alloc]
      initWithFrame:NSMakeRect(0, 0, 560, 28)];

    alert.messageText = @"MarkBend native paragraph experiment";
    alert.informativeText =
      @"Enter one Unicode paragraph. Apply commits the exact text to Bend.";
    field.stringValue = initial == nil ? @"" : initial;
    alert.accessoryView = field;
    [alert addButtonWithTitle:@"Apply"];
    [alert addButtonWithTitle:@"Cancel"];

    NSModalResponse response = [alert runModal];
    NSString* output = response == NSAlertFirstButtonReturn
      ? field.stringValue
      : (initial == nil ? @"" : initial);
    NSData* bytes = [output dataUsingEncoding:NSUTF8StringEncoding];
    result = io_str(e, bytes.bytes, bytes.length);
  }

  free(input);
  return result;
}

#else

Term native_paragraph_edit_run(Env e, Term* f, IoWork* w) {
  u64 input_length = 0;
  char* input = io_cstr(e, f[0], &input_length);
  Term result = io_str(e, input, input_length);
  free(input);
  return result;
}

#endif

static void __attribute__((constructor)) native_paragraph_edit_use(void) {
  io_eff(CID(NativeParagraph.edit), native_paragraph_edit_run, 0);
}
