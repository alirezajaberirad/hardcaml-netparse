#!/usr/bin/env bash
# Build and run the test suite only (no Verilog regeneration).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"
. syn/_env.sh

dune build 2>&1
dune test --force 2>&1
