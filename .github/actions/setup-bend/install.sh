#!/usr/bin/env bash
set -euo pipefail
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) bend_platform=darwin-arm64; bend_sha=a60c820c0ced758d8ace839507ff6c508a204ce4ef0f45e1089ed7bc73e8c267 ;;
  Darwin-x86_64) bend_platform=darwin-x64; bend_sha=066d4a07a1871a2946be8f42f926582bfda5f13ff728c234ffe79635bd240650 ;;
  Linux-aarch64) bend_platform=linux-arm64; bend_sha=416a17d282a9fd05ab9637a238b51d5ca508114d9773c37d1c11cad595440ed1 ;;
  Linux-x86_64) bend_platform=linux-x64; bend_sha=78106a97af242429dcc057258eb8d10f69cddebcd5e263022185a52d003e09bf ;;
  *) echo 'This compiler setup needs macOS or Linux.' >&2; exit 1 ;;
esac
bend_dir=$(mktemp -d "${RUNNER_TEMP:?}/markbend-compiler.XXXXXX")
curl --proto '=https' --tlsv1.2 -fsSL "https://github.com/bendlang/bend/releases/download/v2.0.34/bend-2.0.34-${bend_platform}.tar.gz" -o "$bend_dir/release.tar.gz"
bend_actual=$(shasum -a 256 "$bend_dir/release.tar.gz")
test "${bend_actual%% *}" = "$bend_sha"
tar -xzf "$bend_dir/release.tar.gz" -C "$bend_dir"
printf '%s\n' "$bend_dir/bend/bin" >> "${GITHUB_PATH:?}"
