#!/usr/bin/env bash
# Build and run the test suite only (no Verilog regeneration). Run inside WSL.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

eval "$(opam env --switch=netparse5 --set-switch)"

dune build 2>&1
dune test --force 2>&1
