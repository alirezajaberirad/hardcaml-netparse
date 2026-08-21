# Shared preamble: activate the project's opam switch, or explain how to get it.
# Sourced by test.sh and build.sh; not meant to be run directly.

SWITCH=netparse5

if ! command -v opam >/dev/null 2>&1; then
  echo "error: opam is not installed for user $(whoami)."
  echo "Run once as root:"
  echo "  wsl -d Ubuntu-24.04 -u root -- bash syn/setup_toolchain.sh"
  exit 1
fi

if ! opam switch list --short 2>/dev/null | grep -qx "$SWITCH"; then
  echo "error: opam switch '$SWITCH' does not exist for user $(whoami)."
  echo "       (OPAMROOT is ${OPAMROOT:-$HOME/.opam})"
  echo
  echo "Each Linux user has their own opam root, so a switch built as root is"
  echo "not visible here. Build one you own:"
  echo "  bash syn/setup_toolchain.sh"
  exit 1
fi

eval "$(opam env --switch=$SWITCH --set-switch)"

# Build on the Linux filesystem, not on /mnt/c.
#
# Two reasons. First, dune chmods its build artifacts, and chmod on a DrvFs
# mount is not permitted for a normal user unless the mount has the "metadata"
# option -- so a _build/ under /mnt/c fails with "Operation not permitted".
# Second, DrvFs I/O is slow enough to dominate the build; moving it is a
# noticeable speedup regardless of permissions.
#
# The source still lives on /mnt/c so Vivado on the Windows side can read the
# generated Verilog directly.
export DUNE_BUILD_DIR="${DUNE_BUILD_DIR:-$HOME/.cache/dune/netparse}"
