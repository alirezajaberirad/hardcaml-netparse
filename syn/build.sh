#!/usr/bin/env bash
# Build, test, and emit Verilog.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"
. syn/_env.sh

echo "=== dune build ==="
dune build 2>&1

echo
echo "=== dune test ==="
dune test --force 2>&1

echo
echo "=== generate Verilog ==="
dune exec bin/generate.exe -- rtl 2>&1

echo
echo "=== generated ==="
ls -la rtl/
