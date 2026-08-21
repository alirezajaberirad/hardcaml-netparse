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
