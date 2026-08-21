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

echo "=== apt packages ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
  opam build-essential m4 pkg-config unzip curl git rsync ca-certificates \
  libgmp-dev zlib1g-dev \
  >/dev/null

echo "opam: $(opam --version)"

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
