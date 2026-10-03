#!/bin/sh
# Run against a writable container copy. Keep the actual repository read-only.
set -eu
cd "$(dirname "$0")/.."
project_dir=$(pwd -P)
docker build -f tests/linux.Dockerfile -t markbend-linux-check:2.0.34 tests
docker run --rm --mount "type=bind,src=$project_dir,dst=/work,readonly" markbend-linux-check:2.0.34
