#!/bin/sh
# Run the complete rendering batch from the repository root.
set -eu

cd "$(dirname "$0")/.."
check_dir=$(mktemp -d /tmp/markbend-check.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT HUP INT TERM

node tests/generate_width_proofs.mjs --check
bend PROOF.bend
for boundary_proof in ProjectionMappingProof SceneScanCountProof TextCompareOwnershipProof DocumentPrependOwnershipProof ListAppendProof HostPatchCompareProof IndexedLinesOwnershipProof BenchmarkAppendOwnershipProof; do
  bend "tests/$boundary_proof.bend"
done
bend tests/IndexedLinesOwnershipCheck.bend -o "$check_dir/indexed-lines-ownership"
bend tests/IndexedLinesOwnershipCheck.bend -o "$check_dir/indexed-lines-ownership.js"
for indexed_path in empty newline unicode crlf bom nul combining shared long; do
  "$check_dir/indexed-lines-ownership" --threads 4 "$indexed_path"
  for indexed_runtime in node bun; do
    if command -v "$indexed_runtime" >/dev/null 2>&1; then
      "$indexed_runtime" "$check_dir/indexed-lines-ownership.js" "$indexed_path"
    fi
  done
done
bend tests/TextCompareOwnershipCheck.bend -o "$check_dir/text-compare-ownership"
bend tests/TextCompareOwnershipCheck.bend -o "$check_dir/text-compare-ownership.js"
for compare_path in success first last left-short right-short empty-left empty-right false shared style text runs-left runs-right; do
  "$check_dir/text-compare-ownership" --threads 4 "$compare_path"
  for compare_runtime in node bun; do
    if command -v "$compare_runtime" >/dev/null 2>&1; then
      "$compare_runtime" "$check_dir/text-compare-ownership.js" "$compare_path"
    fi
  done
done
bend tests/DocumentSourceOwnershipCheck.bend -o "$check_dir/document-source-ownership"
bend tests/DocumentSourceOwnershipCheck.bend -o "$check_dir/document-source-ownership.js"
for source_path in empty single multiple blanks crlf bom nul combining long shared empty-prepend tail; do
  "$check_dir/document-source-ownership" --threads 4 "$source_path"
  for source_runtime in node bun; do
    if command -v "$source_runtime" >/dev/null 2>&1; then
      "$source_runtime" "$check_dir/document-source-ownership.js" "$source_path"
    fi
  done
done
node tests/watchdog_check.mjs
sh tests/input_wait.sh
sh tests/input_suspend.sh
sh tests/new_file_target.sh
sh tests/new_file_publish.sh
sh tests/new_file_observe.sh
sh tests/workspace.sh
sh tests/list_return.sh
bend tests/DocumentFileCheck.bend -o "$check_dir/document-file"
sh tests/document_file.sh "$check_dir/document-file"
bend tests/ResolvedFileCheck.bend -o "$check_dir/resolved-file"
sh tests/resolved_file.sh "$check_dir/resolved-file"
bend tests/InitialFileCheck.bend -o "$check_dir/initial-file"
sh tests/resolved_file.sh "$check_dir/initial-file"
bend tests/ResolvedLoopCheck.bend -o "$check_dir/resolved-loop"
sh tests/resolved_loop.sh "$check_dir/resolved-loop"
bend tests/DocumentFileCheck.bend -o "$check_dir/document-file.js"
bend tests/ResolvedFileCheck.bend -o "$check_dir/resolved-file.js"
bend tests/InitialFileCheck.bend -o "$check_dir/initial-file.js"
bend tests/ResolvedLoopCheck.bend -o "$check_dir/resolved-loop.js"
bend src/LiveParagraph.bend -o "$check_dir/resolved-app.js"
bend tests/RecoveryConfigCheck.bend -o "$check_dir/recovery-config"
sh tests/recovery_config.sh "$check_dir/recovery-config"
bend tests/DocumentSaveCheck.bend -o "$check_dir/document-save"
sh tests/document_save.sh "$check_dir/document-save"
bend tests/DocumentSaveCheck.bend -o "$check_dir/document-save.js"
clang -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined tests/document_save_engine.c -o "$check_dir/document-save-engine"
"$check_dir/document-save-engine"
bend tests/RecoveryConfigCheck.bend -o "$check_dir/recovery-config.js"
for file_runtime in bun node; do
  if command -v "$file_runtime" >/dev/null 2>&1; then
    sh tests/document_file.sh "$check_dir/document-file.js" "$file_runtime"
    sh tests/resolved_file.sh "$check_dir/resolved-file.js" "$file_runtime"
    sh tests/resolved_file.sh "$check_dir/initial-file.js" "$file_runtime"
    sh tests/resolved_loop.sh "$check_dir/resolved-loop.js" "$file_runtime"
    "$file_runtime" tests/document_file_host.mjs
    sh tests/app_open.sh "$check_dir/resolved-app.js" "$file_runtime"
    sh tests/recovery_config.sh "$check_dir/recovery-config.js" "$file_runtime"
    "$file_runtime" tests/recovery_config_host.mjs
    sh tests/document_save.sh "$check_dir/document-save.js" "$file_runtime"
    "$file_runtime" tests/app_save_js.mjs "$check_dir/resolved-app.js"
    "$file_runtime" tests/app_save_js.mjs "$check_dir/resolved-app.js" untitled
  fi
done
clang -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined tests/document_file_worker.c -o "$check_dir/document-file-worker"
"$check_dir/document-file-worker"
for scalar_check in ScalarTextCheck CursorConsumeCheck CursorDispatchCheck ProjectionPartCheck LongParagraphProbe LongLiteralCheck LongFenceCheck ResolvedOpenCheck AppRecoveryCheck RecoverySettingsCheck AppSaveCheck AppPumpCheck AppInputCheck AppSaveAsCheck; do
  bend "tests/$scalar_check.bend" -o "$check_dir/$scalar_check"
  "$check_dir/$scalar_check" --threads 4
  bend "tests/$scalar_check.bend" -o "$check_dir/$scalar_check.js"
  if command -v bun >/dev/null 2>&1; then bun "$check_dir/$scalar_check.js"; fi
  if command -v node >/dev/null 2>&1; then node "$check_dir/$scalar_check.js"; fi
done
bend tests/SceneReleaseLongCheck.bend -o "$check_dir/long-paragraph-release.js"
if command -v bun >/dev/null 2>&1; then bun "$check_dir/long-paragraph-release.js"; fi
if command -v node >/dev/null 2>&1; then node "$check_dir/long-paragraph-release.js"; fi
bend tests/OpenConfigCheck.bend -o "$check_dir/open-config"
sh tests/open_config.sh "$check_dir/open-config"
bend tests/OpenConfigCheck.bend -o "$check_dir/open-config.js"
if command -v bun >/dev/null 2>&1; then
  sh tests/open_config.sh "$check_dir/open-config.js" bun
fi
if command -v node >/dev/null 2>&1; then
  sh tests/open_config.sh "$check_dir/open-config.js" node
  node tests/open_config_host.mjs
fi
bend tests/DocumentOpenCheck.bend -o "$check_dir/document-open"
MARKBEND_OPEN_CHECK_PATH="$check_dir/open-fixture" "$check_dir/document-open"
bend tests/DocumentOpenCheck.bend -o "$check_dir/document-open.js"
bend tests/DocumentOpenLimitCheck.bend -o "$check_dir/document-open-limit"
sh tests/document_open_limit.sh "$check_dir/document-open-limit"
bend tests/DocumentOpenLimitCheck.bend -o "$check_dir/document-open-limit.js"
bend tests/DocumentOpenReadCheck.bend -o "$check_dir/document-open-read"
"$check_dir/document-open-read"
bend tests/DocumentOpenReadCheck.bend -o "$check_dir/document-open-read.js"
bend tests/DocumentOpenLargeCheck.bend -o "$check_dir/document-open-large"
MARKBEND_OPEN_LARGE_PATH="$check_dir/open-large-fixture" "$check_dir/document-open-large" --threads 4
bend tests/DocumentOpenLargeViewCheck.bend -o "$check_dir/document-open-large-view"
MARKBEND_OPEN_LARGE_PATH="$check_dir/open-large-view-fixture" "$check_dir/document-open-large-view" --threads 4
bend tests/DocumentOpenLargeCheck.bend -o "$check_dir/document-open-large.js"
bend tests/DocumentOpenLargeViewCheck.bend -o "$check_dir/document-open-large-view.js"
bend tests/FixtureGenerationCheck.bend -o "$check_dir/fixture-generation"
"$check_dir/fixture-generation" --threads 4
bend tests/FixtureGenerationCheck.bend -o "$check_dir/fixture-generation.js"
bend tests/LargeLoadProbe.bend -o "$check_dir/large-load"
"$check_dir/large-load" --threads 4
bend tests/LargeLoadProbe.bend -o "$check_dir/large-load.js"
bend tests/ByteBufferCheck.bend -o "$check_dir/byte-buffer"
"$check_dir/byte-buffer"
"$check_dir/byte-buffer" --threads 4
bend tests/ByteBufferCheck.bend -o "$check_dir/byte-buffer.js"
bend tests/ByteReleaseCheck.bend -o "$check_dir/byte-release"
"$check_dir/byte-release" --threads 4
bend tests/ByteReleaseCheck.bend -o "$check_dir/byte-release.js"
bend tests/TextReleaseCheck.bend -o "$check_dir/text-release"
"$check_dir/text-release" --threads 4
bend tests/TextReleaseCheck.bend -o "$check_dir/text-release.js"
bend tests/HistoryReleaseCheck.bend -o "$check_dir/history-release"
"$check_dir/history-release" --threads 4
bend tests/HistoryReleaseCheck.bend -o "$check_dir/history-release.js"
bend tests/SceneReleaseCheck.bend -o "$check_dir/scene-release"
"$check_dir/scene-release" --threads 4
bend tests/SceneReleaseCheck.bend -o "$check_dir/scene-release.js"
bend tests/EditorReleaseCheck.bend -o "$check_dir/editor-release"
"$check_dir/editor-release" --threads 4
bend tests/EditorReleaseCheck.bend -o "$check_dir/editor-release.js"
bend tests/SceneReleaseLongCheck.bend -o "$check_dir/scene-release-long"
"$check_dir/scene-release-long"
bend tests/TextByteMapCheck.bend -o "$check_dir/text-byte-map"
"$check_dir/text-byte-map"
"$check_dir/text-byte-map" --threads 4
bend tests/TextByteMapCheck.bend -o "$check_dir/text-byte-map.js"
bend tests/TextStorageCheck.bend -o "$check_dir/text-storage"
"$check_dir/text-storage"
"$check_dir/text-storage" --threads 4
bend tests/TextStorageCheck.bend -o "$check_dir/text-storage.js"
bend tests/PersistentSaveCheck.bend -o "$check_dir/persistent-save"
"$check_dir/persistent-save"
"$check_dir/persistent-save" --threads 4
bend tests/PersistentSaveCheck.bend -o "$check_dir/persistent-save.js"
bend tests/StorageHistoryCheck.bend -o "$check_dir/storage-history"
"$check_dir/storage-history"
"$check_dir/storage-history" --threads 4
bend tests/StorageHistoryCheck.bend -o "$check_dir/storage-history.js"
bend tests/StoredEditorCheck.bend -o "$check_dir/stored-editor"
"$check_dir/stored-editor"
"$check_dir/stored-editor" --threads 4
bend tests/StoredEditorCheck.bend -o "$check_dir/stored-editor.js"
bend tests/StoredRecoveryCheck.bend -o "$check_dir/stored-recovery"
"$check_dir/stored-recovery"
"$check_dir/stored-recovery" --threads 4
bend tests/StoredRecoveryCheck.bend -o "$check_dir/stored-recovery.js"
bend tests/SessionReleaseCheck.bend -o "$check_dir/session-release"
"$check_dir/session-release" --threads 4
bend tests/SessionReleaseCheck.bend -o "$check_dir/session-release.js"
bend tests/Utf8Check.bend -o "$check_dir/utf8"
"$check_dir/utf8"
bend tests/Utf8NativeCheck.bend -o "$check_dir/utf8-native"
"$check_dir/utf8-native"
bend tests/Utf8Check.bend -o "$check_dir/utf8.js"
bend tests/RecoveryEditorCheck.bend -o "$check_dir/recovery-editor"
"$check_dir/recovery-editor"
"$check_dir/recovery-editor" --threads 4
bend tests/RecoveryEditorCheck.bend -o "$check_dir/recovery-editor.js"
bend tests/RecoveryLookupCheck.bend -o "$check_dir/recovery-lookup"
"$check_dir/recovery-lookup"
"$check_dir/recovery-lookup" --threads 4
bend tests/RecoveryLookupCheck.bend -o "$check_dir/recovery-lookup.js"
bend tests/RecoveryEntryCheck.bend -o "$check_dir/recovery-entry"
"$check_dir/recovery-entry"
"$check_dir/recovery-entry" --threads 4
bend tests/RecoveryEntryCheck.bend -o "$check_dir/recovery-entry.js"
bend tests/RecoveryRecordCheck.bend -o "$check_dir/recovery-record"
"$check_dir/recovery-record"
"$check_dir/recovery-record" --threads 4
bend tests/RecoveryRecordCheck.bend -o "$check_dir/recovery-record.js"
bend tests/RecoveryRecordBench.bend -o "$check_dir/recovery-record-large.js"
bend tests/RecoveryStateCheck.bend -o "$check_dir/recovery-state"
"$check_dir/recovery-state"
"$check_dir/recovery-state" --threads 4
bend tests/RecoveryStateCheck.bend -o "$check_dir/recovery-state.js"
bend tests/SaveStateCheck.bend -o "$check_dir/save-state"
"$check_dir/save-state"
"$check_dir/save-state" --threads 4
bend tests/SaveStateCheck.bend -o "$check_dir/save-state.js"
clang -std=c11 -Wall -Wextra -Werror tests/atomic_replace.c -o "$check_dir/atomic-replace"
clang -std=c11 -Wall -Wextra -Werror tests/document_identity.c -o "$check_dir/document-identity"
clang -std=c11 -Wall -Wextra -Werror tests/recovery_directory.c -o "$check_dir/recovery-directory"
bend tests/AppRecoveryRestartCheck.bend -o "$check_dir/app-recovery-restart"
bend tests/AppRecoveryRestartCheck.bend -o "$check_dir/app-recovery-restart.js"
sh tests/app_recovery_restart.sh "$check_dir/app-recovery-restart" "$check_dir/atomic-replace" "$check_dir/recovery-directory"
for startup_runtime in bun node; do
  if command -v "$startup_runtime" >/dev/null 2>&1; then
    sh tests/app_recovery_open.sh "$check_dir/resolved-app.js" "$check_dir/app-recovery-restart" "$check_dir/atomic-replace" "$check_dir/recovery-directory" "$startup_runtime"
  fi
done
if command -v bun >/dev/null 2>&1; then
  sh tests/app_recovery_restart.sh "$check_dir/app-recovery-restart.js" "$check_dir/atomic-replace" "$check_dir/recovery-directory" bun
fi
clang -std=c11 -Wall -Wextra -Werror tests/recovery_directory_limit.c -o "$check_dir/recovery-directory-limit"
sh tests/recovery_directory.sh "$check_dir/recovery-directory" "$check_dir/recovery-directory-files"
bend tests/RecoveryScanCheck.bend -o "$check_dir/recovery-scan"
bend tests/RecoveryScanCheck.bend -o "$check_dir/recovery-scan.js"
sh tests/recovery_scan.sh native "$check_dir/recovery-scan" "$check_dir/recovery-directory" "$check_dir/atomic-replace" "$check_dir/scan-native"
sh tests/recovery_directory_limit.sh "$check_dir/recovery-directory" "$check_dir/recovery-directory-limit" native "$check_dir/recovery-scan" "$check_dir/scan-limit-native"
sh tests/document_identity.sh "$check_dir/document-identity" "$check_dir/atomic-replace" "$check_dir/path-identity"
bend tests/RecoveryEntryRestartCheck.bend -o "$check_dir/recovery-entry-restart"
bend tests/RecoveryEntryRestartCheck.bend -o "$check_dir/recovery-entry-restart.js"
bend tests/RecoveryPlanRestartCheck.bend -o "$check_dir/recovery-plan-restart"
bend tests/RecoveryPlanRestartCheck.bend -o "$check_dir/recovery-plan-restart.js"
sh tests/recovery_plan_restart.sh native "$check_dir/recovery-plan-restart" "$check_dir/atomic-replace" "$check_dir/document-identity" "$check_dir/recovery-directory" "$check_dir/plan-restart-native"
sh tests/recovery_entry_restart.sh native "$check_dir/recovery-entry-restart" "$check_dir/atomic-replace" "$check_dir/entry-restart-native" "$check_dir/document-identity"
mkdir "$check_dir/atomic-files"
"$check_dir/atomic-replace" "$check_dir/atomic-files"
sh tests/atomic_input_limit.sh "$check_dir/atomic-replace" "$check_dir/atomic-input-limit"
bend tests/RecoveryRestartCheck.bend -o "$check_dir/recovery-restart"
bend tests/RecoveryRestartCheck.bend -o "$check_dir/recovery-restart.js"
sh tests/recovery_restart.sh native "$check_dir/recovery-restart" "$check_dir/atomic-replace" "$check_dir/restart-native"
bend tests/RecoveryLargeRestartCheck.bend -o "$check_dir/recovery-large-restart"
bend tests/RecoveryLargeRestartCheck.bend -o "$check_dir/recovery-large-restart.js"
sh tests/recovery_restart.sh native "$check_dir/recovery-large-restart" "$check_dir/atomic-replace" "$check_dir/restart-large-native"
bend tests/RecoveryConflictRestartCheck.bend -o "$check_dir/recovery-conflict-restart"
bend tests/RecoveryConflictRestartCheck.bend -o "$check_dir/recovery-conflict-restart.js"
sh tests/recovery_conflict_restart.sh "$check_dir/recovery-conflict-restart" "$check_dir/atomic-replace" "$check_dir/restart-conflict-native"
bend tests/JournalInterruptedCheck.bend -o "$check_dir/journal-interrupted"
bend tests/JournalInterruptedCheck.bend -o "$check_dir/journal-interrupted.js"
sh tests/journal_interruption.sh native "$check_dir/recovery-restart" "$check_dir/journal-interrupted" "$check_dir/atomic-replace" "$check_dir/journal-native"
bend tests/JournalLargeInterruptedCheck.bend -o "$check_dir/journal-large-interrupted"
bend tests/JournalLargeInterruptedCheck.bend -o "$check_dir/journal-large-interrupted.js"
sh tests/journal_interruption.sh native "$check_dir/recovery-large-restart" "$check_dir/journal-large-interrupted" "$check_dir/atomic-replace" "$check_dir/journal-large-native"
bend tests/SaveHostCheck.bend -o "$check_dir/save-host"
bend tests/SaveHostCheck.bend -o "$check_dir/save-host.js"
mkdir "$check_dir/save-host-files"
MARKBEND_ATOMIC_HOST="$check_dir/atomic-replace" MARKBEND_SAVE_DIRECTORY="$check_dir/save-host-files" "$check_dir/save-host"
bend tests/SaveInterruptedHostCheck.bend -o "$check_dir/interrupted-save"
bend tests/SaveInterruptedHostCheck.bend -o "$check_dir/interrupted-save.js"
mkdir "$check_dir/interrupted-native" "$check_dir/interrupted-js"
for stop in 0 1 2 3 4; do
  mkdir "$check_dir/interrupted-native/$stop" "$check_dir/interrupted-js/$stop"
done
MARKBEND_ATOMIC_HOST="$check_dir/atomic-replace" MARKBEND_SAVE_DIRECTORY="$check_dir/interrupted-native" "$check_dir/interrupted-save"
bend tests/FileBytesCheck.bend -o "$check_dir/file-bytes"
MARKBEND_FILE_CHECK_PATH="$check_dir/native-bytes.bin" "$check_dir/file-bytes"
bend tests/FileBytesCheck.bend -o "$check_dir/file-bytes.js"
bend src/Experiment.bend -o "$check_dir/experiment"
"$check_dir/experiment"
bend tests/CursorCheck.bend -o "$check_dir/cursor-check"
"$check_dir/cursor-check" > "$check_dir/cursor-output.txt"
diff -u tests/cursor_expected.txt "$check_dir/cursor-output.txt"
bend tests/PositionCheck.bend -o "$check_dir/position-check"
"$check_dir/position-check"
bend tests/DirectCheck.bend -o "$check_dir/direct-check"
"$check_dir/direct-check"
bend tests/SessionViewCheck.bend -o "$check_dir/session-view-check"
"$check_dir/session-view-check"
"$check_dir/session-view-check" --threads 4
bend tests/SceneCacheCheck.bend -o "$check_dir/scene-cache-check"
"$check_dir/scene-cache-check"
"$check_dir/scene-cache-check" --threads 4
bend tests/OpeningScanCheck.bend -o "$check_dir/opening-scan-check"
"$check_dir/opening-scan-check"
"$check_dir/opening-scan-check" --threads 4
bend tests/SceneRangeCheck.bend -o "$check_dir/scene-range-check"
"$check_dir/scene-range-check"
"$check_dir/scene-range-check" --threads 4
bend tests/SceneRangeCheck.bend -o "$check_dir/scene-range-check.js"
for range_runtime in node bun; do
  if command -v "$range_runtime" >/dev/null 2>&1; then
    "$range_runtime" "$check_dir/scene-range-check.js"
  fi
done
bend tests/HostPatchCompareCheck.bend -o "$check_dir/host-patch-compare"
"$check_dir/host-patch-compare" --threads 4
bend tests/HostPatchCompareCheck.bend -o "$check_dir/host-patch-compare.js"
for patch_runtime in node bun; do
  if command -v "$patch_runtime" >/dev/null 2>&1; then
    "$patch_runtime" "$check_dir/host-patch-compare.js"
  fi
done
bend tests/SceneIndexCheck.bend -o "$check_dir/scene-index-check"
"$check_dir/scene-index-check"
"$check_dir/scene-index-check" --threads 4
bend tests/SceneSpliceCheck.bend -o "$check_dir/scene-splice-check"
"$check_dir/scene-splice-check"
"$check_dir/scene-splice-check" --threads 4
bend tests/BlockSceneCheck.bend -o "$check_dir/block-scene-check"
"$check_dir/block-scene-check"
"$check_dir/block-scene-check" --threads 4
bend tests/DocumentCheck.bend -o "$check_dir/document-check"
"$check_dir/document-check"
"$check_dir/document-check" --threads 4
bend tests/ChangeRangeBench.bend -o "$check_dir/change-ranges"
"$check_dir/change-ranges"
"$check_dir/change-ranges" --threads 4
bend tests/IndexCheck.bend -o "$check_dir/index-check"
"$check_dir/index-check"
"$check_dir/index-check" --threads 4
sh tests/memory.sh
sh tests/session_memory.sh
bend src/LiveParagraph.bend -o "$check_dir/live-paragraph"
bend src/LiveParagraph.bend -o "$check_dir/live-paragraph.js"

clang -std=gnu11 -U__APPLE__ -D__linux__ tests/host_roundtrip.c -o "$check_dir/posix-host"
"$check_dir/posix-host"
if [ "$(uname -s)" = Linux ]; then
  sh tests/app_open.sh "$check_dir/live-paragraph" native
  sh tests/app_recovery_open.sh "$check_dir/live-paragraph" "$check_dir/app-recovery-restart" "$check_dir/atomic-replace" "$check_dir/recovery-directory" native
  sh tests/app_save_terminal.sh "$check_dir/live-paragraph"
  sh tests/app_save_as_terminal.sh
  node tests/terminal_checkpoint_check.mjs
  node tests/app_save_terminal_failure.mjs "$check_dir/live-paragraph"
  bend tests/StoredLoopCheck.bend -o "$check_dir/stored-loop"
  printf '**中文** xyz\n.apply\n.undo\n.redo\n' | "$check_dir/stored-loop"
fi
if [ "$(uname -s)" = Darwin ]; then
  sh tests/native_workspace_recheck.sh
  bend tests/NativeAppSaveCheck.bend -o "$check_dir/native-app-save"
  sh tests/app_save_native.sh "$check_dir/native-app-save"
  bend tests/NativeAppSaveCheck.bend -o "$check_dir/native-app-save.c"
  clang -O2 -x objective-c -fobjc-arc -framework Cocoa -pthread '-DMARKBEND_SAVE_BEFORE_REPLACE(parent,leaf,temporary)=1' "$check_dir/native-app-save.c" -o "$check_dir/native-save-before"
  sh tests/app_save_native.sh "$check_dir/native-save-before" before
  clang -O2 -x objective-c -fobjc-arc -framework Cocoa -pthread '-DMARKBEND_SAVE_AFTER_REPLACE(parent,leaf)=1' "$check_dir/native-app-save.c" -o "$check_dir/native-save-uncertain"
  sh tests/app_save_native.sh "$check_dir/native-save-uncertain" uncertain
  bend tests/NativeAppOpenCheck.bend -o "$check_dir/native-app-open"
  sh tests/app_open.sh "$check_dir/native-app-open" native guard
  sh tests/app_recovery_open.sh "$check_dir/native-app-open" "$check_dir/app-recovery-restart" "$check_dir/atomic-replace" "$check_dir/recovery-directory" native
  bend tests/NativeStoredCheck.bend -o "$check_dir/native-stored"
  "$check_dir/native-stored"
  bend tests/NativeReleaseCheck.bend -o "$check_dir/native-release"
  "$check_dir/native-release" --threads 1
  "$check_dir/native-release" --threads 4
  bend tests/NativeReleaseZeroCheck.bend -o "$check_dir/native-release-zero"
  "$check_dir/native-release-zero" --threads 1
  "$check_dir/native-release-zero" --threads 4
  bend tests/NativeRepeatedWindowCheck.bend -o "$check_dir/native-repeated-window"
  "$check_dir/native-repeated-window" --threads 1
  "$check_dir/native-repeated-window" --threads 4
  clang -x objective-c -fobjc-arc -framework Cocoa tests/host_roundtrip.c -o "$check_dir/mac-host"
  "$check_dir/mac-host"
  bend tests/NativeDirectCheck.bend -o "$check_dir/native-direct"
  "$check_dir/native-direct" > "$check_dir/native-direct-output.txt"
  test "$(cat "$check_dir/native-direct-output.txt")" = 'Native direct event loop passed'
  bend tests/NativeRecoveryCheck.bend -o "$check_dir/native-recovery"
  "$check_dir/native-recovery" > "$check_dir/native-recovery-output.txt"
  test "$(cat "$check_dir/native-recovery-output.txt")" = 'Native recovery, input, composition, history, and save snapshots check passed'
  bend tests/NativeRecoveryRestartCheck.bend -o "$check_dir/native-recovery-restart"
  sh tests/native_recovery_restart.sh "$check_dir/native-recovery-restart" "$check_dir/atomic-replace" "$check_dir/document-identity" "$check_dir/recovery-directory" "$check_dir/native-recovery-restart-files"
  bend tests/NativeStoredRestartCheck.bend -o "$check_dir/native-stored-restart"
  sh tests/native_recovery_restart.sh "$check_dir/native-stored-restart" "$check_dir/atomic-replace" "$check_dir/document-identity" "$check_dir/recovery-directory" "$check_dir/native-stored-restart-files"
  bend tests/NativeBlockCheck.bend -o "$check_dir/native-block"
  "$check_dir/native-block" > "$check_dir/native-block-output.txt"
  test "$(cat "$check_dir/native-block-output.txt")" = 'Native block event loop passed'
  bend tests/NativeNavigationCheck.bend -o "$check_dir/native-navigation"
  "$check_dir/native-navigation" > "$check_dir/native-navigation-output.txt"
  test "$(cat "$check_dir/native-navigation-output.txt")" = 'Native navigation and resize batch passed'
  bend tests/NativeDocumentBench.bend -o "$check_dir/native-document"
  "$check_dir/native-document" > "$check_dir/native-document-output.txt"
  test "$(tail -n 1 "$check_dir/native-document-output.txt")" = 'Native document benchmark passed'
  test "$(awk '/^native_edit_frame_ms=/ {count++} END {print count}' "$check_dir/native-document-output.txt")" -eq 20
  "$check_dir/native-document" cold > "$check_dir/native-document-cold-output.txt"
  test "$(tail -n 1 "$check_dir/native-document-cold-output.txt")" = 'Native document benchmark passed'
  test "$(awk '/^native_edit_frame_ms=/ {count++} END {print count}' "$check_dir/native-document-cold-output.txt")" -eq 20
  test "$(awk '/^native_initial_scroll_skipped=1$/ {count++} END {print count}' "$check_dir/native-document-cold-output.txt")" -eq 1
fi
if command -v bun >/dev/null 2>&1; then
  bun "$check_dir/byte-buffer.js"
  MARKBEND_OPEN_CHECK_PATH="$check_dir/open-js-fixture" bun "$check_dir/document-open.js"
  sh tests/document_open_limit.sh "$check_dir/document-open-limit.js" bun
  bun "$check_dir/document-open-read.js"
  MARKBEND_OPEN_LARGE_PATH="$check_dir/open-large-js-fixture" bun "$check_dir/document-open-large.js"
  MARKBEND_OPEN_LARGE_PATH="$check_dir/open-large-view-js-fixture" bun "$check_dir/document-open-large-view.js"
  bun "$check_dir/fixture-generation.js"
  bun "$check_dir/large-load.js"
  bun "$check_dir/text-byte-map.js"
  bun "$check_dir/text-storage.js"
  bun "$check_dir/persistent-save.js"
  bun "$check_dir/byte-release.js"
  bun "$check_dir/text-release.js"
  bun "$check_dir/history-release.js"
  bun "$check_dir/scene-release.js"
  bun "$check_dir/editor-release.js"
  bun "$check_dir/storage-history.js"
  bun "$check_dir/stored-editor.js"
  bun "$check_dir/stored-recovery.js"
  bun "$check_dir/session-release.js"
  bun "$check_dir/utf8.js"
  bun "$check_dir/recovery-editor.js"
  sh tests/recovery_scan.sh bun "$check_dir/recovery-scan.js" "$check_dir/recovery-directory" "$check_dir/atomic-replace" "$check_dir/scan-js"
  sh tests/recovery_directory_limit.sh "$check_dir/recovery-directory" "$check_dir/recovery-directory-limit" bun "$check_dir/recovery-scan.js" "$check_dir/scan-limit-js"
  bun "$check_dir/recovery-lookup.js"
  bun "$check_dir/recovery-entry.js"
  sh tests/recovery_entry_restart.sh bun "$check_dir/recovery-entry-restart.js" "$check_dir/atomic-replace" "$check_dir/entry-restart-js" "$check_dir/document-identity"
  sh tests/recovery_plan_restart.sh bun "$check_dir/recovery-plan-restart.js" "$check_dir/atomic-replace" "$check_dir/document-identity" "$check_dir/recovery-directory" "$check_dir/plan-restart-js"
  sh tests/recovery_restart.sh bun "$check_dir/recovery-large-restart.js" "$check_dir/atomic-replace" "$check_dir/restart-large-js"
  sh tests/journal_interruption.sh bun "$check_dir/recovery-large-restart.js" "$check_dir/journal-large-interrupted.js" "$check_dir/atomic-replace" "$check_dir/journal-large-js"
  sh tests/recovery_conflict_restart.sh "$check_dir/recovery-conflict-restart.js" "$check_dir/atomic-replace" "$check_dir/restart-conflict-js" bun
  sh tests/recovery_restart.sh bun "$check_dir/recovery-restart.js" "$check_dir/atomic-replace" "$check_dir/restart-js"
  sh tests/journal_interruption.sh bun "$check_dir/recovery-restart.js" "$check_dir/journal-interrupted.js" "$check_dir/atomic-replace" "$check_dir/journal-js"
  bun "$check_dir/recovery-record.js"
  bun "$check_dir/recovery-record-large.js"
  bun "$check_dir/recovery-state.js"
  bun "$check_dir/save-state.js"
  MARKBEND_ATOMIC_HOST="$check_dir/atomic-replace" MARKBEND_SAVE_DIRECTORY="$check_dir/save-host-files" bun "$check_dir/save-host.js"
  MARKBEND_ATOMIC_HOST="$check_dir/atomic-replace" MARKBEND_SAVE_DIRECTORY="$check_dir/interrupted-js" bun "$check_dir/interrupted-save.js"
  MARKBEND_FILE_CHECK_PATH="$check_dir/js-bytes.bin" bun "$check_dir/file-bytes.js"
  cmp "$check_dir/native-bytes.bin" "$check_dir/js-bytes.bin"
  bun tests/host_roundtrip.mjs
  bun "$check_dir/live-paragraph.js" </dev/null >/dev/null
else
  node "$check_dir/byte-buffer.js"
  node "$check_dir/document-open-read.js"
  node "$check_dir/fixture-generation.js"
  node "$check_dir/large-load.js"
  node "$check_dir/text-byte-map.js"
  node "$check_dir/text-storage.js"
  node "$check_dir/persistent-save.js"
  node "$check_dir/byte-release.js"
  node "$check_dir/text-release.js"
  node "$check_dir/history-release.js"
  node "$check_dir/scene-release.js"
  node "$check_dir/editor-release.js"
  node "$check_dir/storage-history.js"
  node "$check_dir/stored-editor.js"
  node "$check_dir/stored-recovery.js"
  node "$check_dir/session-release.js"
  node "$check_dir/utf8.js"
  node "$check_dir/recovery-editor.js"
  node "$check_dir/recovery-lookup.js"
  node "$check_dir/recovery-entry.js"
  node "$check_dir/recovery-record.js"
  node "$check_dir/recovery-record-large.js"
  node "$check_dir/recovery-state.js"
  node "$check_dir/save-state.js"
  echo 'JavaScript file-byte runtime check requires Bun in Bend 2.0.34; native check passed.'
  node tests/host_roundtrip.mjs
  node "$check_dir/live-paragraph.js" </dev/null >/dev/null
fi
git diff --check
echo 'Rendering, direct editing, and document batch passed.'
