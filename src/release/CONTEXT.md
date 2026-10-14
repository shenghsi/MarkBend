# Beta package release

Only a pushed vVERSION-beta.N tag starts the release workflow. Its base version
must match npm, the npm lock, Cargo, and Tauri. HEAD and the tag's commit must
match the recorded checkout. All Bend, frontend, and native checks must succeed
before a draft prerelease can be created. A package build is not native input,
installation, Save, or recovery acceptance.

The release contains macOS ARM64 and X64 app ZIPs, Linux X64 DEB, and Windows X64
NSIS. macOS uses verified ad-hoc signing with no Developer ID or notarization.
Windows and Linux have no publisher certificate. Each package has a manifest
with checkout, architecture, signing status, size, and SHA-256. Collection rejects
missing, duplicate, changed, linked, unexpected, or wrong-checkout artifacts.

Release names include the tag and architecture. Only the last job can write
release data. An existing release is never replaced. Creation starts with an
incomplete draft notice; successful upload replaces it with the test notes.
Remote tag, draft/prerelease state, asset names, sizes, upload state, and available
digest values must agree before final notes replace the incomplete notice.
Failure leaves that draft unpublished. The workflow never publishes a release,
changes source record, baseline, or recovery, or installs an app.
