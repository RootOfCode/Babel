#!/usr/bin/env bash
# run.sh — Launch BABEL without reinstalling system dependencies.
#
# First-time setup on Ubuntu/Debian:
#   sudo apt install sbcl libsdl2-dev
#   ./install.sh
#
# Normal launch:
#   ./run.sh

set -euo pipefail

BABEL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUICKLISP_INIT="${QUICKLISP_INIT:-$HOME/quicklisp/setup.lisp}"

print_header() {
    echo "══════════════════════════════════════════"
    echo "  BABEL — Lisp Macro World Compiler"
    echo "  GUI launcher"
    echo "══════════════════════════════════════════"
}

fail() {
    echo "[ERROR] $1" >&2
    exit 1
}

print_header

command -v sbcl >/dev/null 2>&1 || fail "SBCL not found. Install it with: sudo apt install sbcl"
[ -f "$QUICKLISP_INIT" ] || fail "Quicklisp not found at $QUICKLISP_INIT. Run ./install.sh after installing Quicklisp."
[ -f "$BABEL_DIR/babel-world.asd" ] || fail "babel-world.asd not found. Run this script from the extracted BABEL project folder."

mkdir -p "$BABEL_DIR/output"

# Avoid the old project name shadowing the real cl:babel encoding library that
# SDL2 dependencies may need.
if [ -f "$BABEL_DIR/babel.asd" ]; then
    rm "$BABEL_DIR/babel.asd"
    echo "[OK] Removed stale babel.asd."
fi

# Make the project visible to ASDF even when the folder is not symlinked into
# ~/quicklisp/local-projects.
echo "[OK] Project directory: $BABEL_DIR"
echo "[OK] Launching SDL GUI. Press F2 GUI, F3 Code, F4 Stats, F5 Apply, F10 Theme, F11 Fit, H Help."
echo ""

sbcl --noinform \
     --load "$QUICKLISP_INIT" \
     --eval "(pushnew #p\"$BABEL_DIR/\" asdf:*central-registry* :test #'equal)" \
     --eval "(ql:register-local-projects)" \
     --eval "(ql:quickload :babel-world :silent t)" \
     --eval "(babel:initialize :system-root #p\"$BABEL_DIR/\")" \
     --eval "(babel:run-threaded)" \
     --eval "(sb-impl::toplevel-repl nil)"
