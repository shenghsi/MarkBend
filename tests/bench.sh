#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
bench_dir=$(mktemp -d /tmp/markbend-bench.XXXXXX)
trap 'rm -rf "$bench_dir"' EXIT HUP INT TERM
bend tests/DocumentBench.bend -o "$bench_dir/document-bench"
"$bench_dir/document-bench"
bend tests/OpeningBench.bend -o "$bench_dir/opening-bench"
"$bench_dir/opening-bench"
"$bench_dir/opening-bench" large
bend tests/RecoveryRecordBench.bend -o "$bench_dir/recovery-record-bench"
"$bench_dir/recovery-record-bench"
bend tests/RecoveryEditorBench.bend -o "$bench_dir/recovery-editor-bench"
"$bench_dir/recovery-editor-bench" --threads 1
bend tests/StoredEditorBench.bend -o "$bench_dir/stored-editor-bench"
"$bench_dir/stored-editor-bench" --threads 1
bend tests/StoredTypingBench.bend -o "$bench_dir/stored-typing-bench"
"$bench_dir/stored-typing-bench" --threads 1
bend tests/SessionDisposeBench.bend -o "$bench_dir/session-dispose-bench"
"$bench_dir/session-dispose-bench" --threads 1
bend tests/SessionReleaseBench.bend -o "$bench_dir/session-release-bench"
"$bench_dir/session-release-bench" --threads 4
"$bench_dir/session-release-bench" --threads 1
bend tests/ByteReleaseBench.bend -o "$bench_dir/byte-release-bench"
"$bench_dir/byte-release-bench" --threads 1
bend tests/TextReleaseBench.bend -o "$bench_dir/text-release-bench"
"$bench_dir/text-release-bench" --threads 1
bend tests/HistoryReleaseBench.bend -o "$bench_dir/history-release-bench"
"$bench_dir/history-release-bench" --threads 1
bend tests/SceneReleaseBench.bend -o "$bench_dir/scene-release-bench"
"$bench_dir/scene-release-bench" --threads 1
bend tests/EditorReleaseBench.bend -o "$bench_dir/editor-release-bench"
"$bench_dir/editor-release-bench" --threads 1
bend tests/EditorReleaseHeartbeat.bend -o "$bench_dir/editor-release-heartbeat"
"$bench_dir/editor-release-heartbeat" --threads 4
"$bench_dir/editor-release-heartbeat" --threads 1
bend tests/EditorReleaseZeroHeartbeat.bend -o "$bench_dir/editor-release-zero-heartbeat"
"$bench_dir/editor-release-zero-heartbeat" --threads 1
"$bench_dir/editor-release-zero-heartbeat" --threads 4
bend tests/ByteBufferBench.bend -o "$bench_dir/byte-buffer-bench"
"$bench_dir/byte-buffer-bench" --threads 1
