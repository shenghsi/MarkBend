# Native test package evidence

The optional build_packages input in the portability workflow creates unsigned
test packages. Normal push and pull-request checks retain debug executables.
All native routes verify the same frontend checkout before Rust tests and builds.
The workflow has read-only repository permissions and no publication step.

macOS uses an app ZIP made with ditto, Linux uses DEB, and Windows uses NSIS.
package-artifact.mjs records checkout, OS, architecture, size, and SHA-256. Empty,
missing, or nonregular package files fail. The macOS archive retains executable
permissions; uploading the app directory directly would not provide that check.

On 2026-10-11, a local macOS 26.5.1 arm64 release build at application source commit
b0c34b697845dac4e610a090756b321b09f7d49c passed:

```sh
npm run desktop:build -- --bundles app --ci -- --locked
```

The frontend build and startup dependency check passed. The optimized native
build took 55.82 seconds. It produced a 12.13 MiB app at
src/desktop/target/release/bundle/macos/MarkBend.app. The ZIP in desktop-package
has 6,032,505 bytes and SHA-256
3c675264c2de0eaeb519636dbaff1e5c4873494355a37e7d22c43edb6eec599f.
The metadata command passed. Extracting the ZIP with ditto retained executable
permissions. Original and extracted executable SHA-256 values both equal
d2d4698a09366b995cda452b157b895fd1b060ab9889703315371b4d64e3395c.

The packaged app process started. The window-control tool returned
cgWindowNotFound, so this run establishes no native display or editing result.
Do not repeat the same window request without new evidence. Windows/Linux
package builds and installation remain unverified. Native IME, recovery,
Save, menu input, and platform runtime acceptance still need their own checks.
No repository remote is configured, so no remote workflow was dispatched.
The complete build output is in tests/package-macos-build.log. YAML parsing,
the three-format matrix, read-only permissions, metadata input rejection,
archive hash, Bend proof, and whitespace checks pass. Remote workflow syntax and
runner execution still require GitHub evidence.

## Fresh native instance check

On 2026-10-11, source commit 3c7fce1 also built a separate macOS test app.
A temporary config used product name MarkBendAcceptance, identifier
dev.markbend.acceptance, and no file associations. The frontend and startup
dependency checks passed in 5.00 seconds. The native release build passed in
17.24 seconds. It produced a 12.17 MiB MarkBendAcceptance.app. Its executable
SHA-256 is 03233df589167f1eb1ef6494ca3e5709b920a90d34786f3802a9d1c6e0343257.
The build output is in tests/native-acceptance-build.log.

One window-control request for the exact new app path returned cgWindowNotFound.
The new process, PID 49060, stayed running. Its separate app-data folder,
Library/Application Support/dev.markbend.acceptance, contained recovery session
lease files. The original app, PID 21109, stayed running. No user document was
opened or edited during this check. Both processes and recovery data were kept.

A one-second process sample of PID 21109 showed the main thread waiting in the
normal NSApplication event loop, with WebView threads active. This rules out an
obvious startup hang during that sample. It proves neither a visible window nor
native input. The new identity reproduced the window-control failure; it does
not establish a product window defect. Stop this test route until new window
evidence or working native control is available. Native acceptance stays open.
