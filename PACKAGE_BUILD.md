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
