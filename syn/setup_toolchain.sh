#!/usr/bin/env bash
# One-shot toolchain bootstrap for hardcaml-netparse (run as root inside WSL).
#
# Notes:
#  - ppx_hardcaml requires OCaml >= 5.1, so we build a 5.2.1 switch from source
#    rather than reusing Ubuntu's system 4.14 compiler.
#  - hardcaml_waveterm is deliberately NOT installed by default: it pulls in the
#    whole Async/notty stack (~97 packages) and nothing in this project needs it.
#    Set WITH_WAVETERM=1 if you want interactive waveform dumps.
set -euo pipefail

SWITCH=netparse5
COMPILER=5.2.1

# System packages need root; the opam switch does not and should not have it.
# Run this once as root to get the apt side, then again as your normal user to
# get a switch you own.
if [ "$(id -u)" -eq 0 ]; then
  echo "=== apt packages (running as root) ==="
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq \
    opam build-essential m4 pkg-config unzip curl git rsync ca-certificates \
    libgmp-dev zlib1g-dev \
    >/dev/null
else
  echo "=== not root: skipping apt, checking the system packages are present ==="
  missing=""
  for c in opam gcc m4 pkg-config curl git; do
    command -v "$c" >/dev/null 2>&1 || missing="$missing $c"
  done
  if [ -n "$missing" ]; then
    echo "error: missing system packages:$missing"
    echo "Run once as root first:"
    echo "  wsl -d Ubuntu-24.04 -u root -- bash $0"
    exit 1
  fi
fi

echo "opam: $(opam --version)   user: $(whoami)   OPAMROOT: ${OPAMROOT:-$HOME/.opam}"

echo "=== opam init (sandboxing off; bubblewrap is unreliable under WSL) ==="
if [ ! -d "$HOME/.opam" ]; then
  opam init --bare --disable-sandboxing --no-setup -y
fi

echo "=== switch $SWITCH (ocaml $COMPILER) ==="
if ! opam switch list --short | grep -qx "$SWITCH"; then
  opam switch create "$SWITCH" "ocaml-base-compiler.$COMPILER" -y
fi
eval "$(opam env --switch=$SWITCH --set-switch)"
echo "switch ocaml: $(ocaml -version)"

echo "=== hardcaml ecosystem ==="
PKGS="dune hardcaml ppx_hardcaml"
if [ "${WITH_WAVETERM:-0}" = "1" ]; then
  PKGS="$PKGS hardcaml_waveterm"
fi
opam install -y --assume-depexts $PKGS

echo "=== versions ==="
opam list --short --installed ocaml dune hardcaml ppx_hardcaml
echo "=== DONE ==="
