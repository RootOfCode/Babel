#!/usr/bin/env bash
# install.sh — Install dependencies and launch BABEL
#
# Prerequisites (Ubuntu/Debian):
#   sudo apt install sbcl libsdl2-dev
#   (Quicklisp must already be installed in ~/quicklisp)
#
# Usage:
#   chmod +x install.sh
#   ./install.sh

set -e

echo "══════════════════════════════════════════"
echo "  BABEL — Lisp Macro World Compiler"
echo "  Dependency installer & launcher"
echo "══════════════════════════════════════════"

# ─── Check SBCL ───────────────────────────────────────────────────────────────
if ! command -v sbcl &>/dev/null; then
    echo "[ERROR] SBCL not found. Install with: sudo apt install sbcl"
    exit 1
fi
echo "[OK] SBCL: $(sbcl --version)"

# ─── Check SDL2 ───────────────────────────────────────────────────────────────
if ! ldconfig -p | grep -q libSDL2 2>/dev/null; then
    echo "[WARN] libSDL2 not detected via ldconfig. Trying pkg-config…"
    if ! pkg-config --exists sdl2 2>/dev/null; then
        echo "[ERROR] SDL2 not found. Install with: sudo apt install libsdl2-dev"
        exit 1
    fi
fi
echo "[OK] SDL2 detected."

# ─── Check Quicklisp ─────────────────────────────────────────────────────────
QUICKLISP_INIT="$HOME/quicklisp/setup.lisp"
if [ ! -f "$QUICKLISP_INIT" ]; then
    echo "[ERROR] Quicklisp not found at $QUICKLISP_INIT"
    echo "  Install Quicklisp: https://www.quicklisp.org/beta/"
    exit 1
fi
echo "[OK] Quicklisp found."

# ─── Guard: ensure babel-world.asd exists, not just babel.asd ────────────────
BABEL_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ ! -f "$BABEL_DIR/babel-world.asd" ]; then
    echo "[ERROR] babel-world.asd not found in $BABEL_DIR"
    echo "  Make sure you extracted the full archive."
    exit 1
fi
# If the old babel.asd exists alongside babel-world.asd, remove it to prevent
# ASDF from registering it as the 'babel' encoding library provider.
if [ -f "$BABEL_DIR/babel.asd" ]; then
    rm "$BABEL_DIR/babel.asd"
    echo "[OK] Removed stale babel.asd (would shadow cl:babel encoding lib)."
fi
echo "[OK] babel-world.asd present."

# ─── Quicklisp local-projects symlink ────────────────────────────────────────
LOCAL="$HOME/quicklisp/local-projects"
mkdir -p "$LOCAL"
# Remove any old 'babel' symlink pointing at our directory — it would shadow
# the real 'babel' encoding library that sdl2 depends on.
if [ -L "$LOCAL/babel" ]; then
    rm "$LOCAL/babel"
    echo "[OK] Removed old local-projects/babel symlink."
fi
# Remove stale babel-world symlink if it points somewhere wrong
if [ -L "$LOCAL/babel-world" ] && [ "$(readlink "$LOCAL/babel-world")" != "$BABEL_DIR" ]; then
    rm "$LOCAL/babel-world"
fi
if [ ! -L "$LOCAL/babel-world" ]; then
    ln -s "$BABEL_DIR" "$LOCAL/babel-world"
    echo "[OK] Linked $BABEL_DIR → $LOCAL/babel-world"
else
    echo "[OK] local-projects/babel-world already linked."
fi

# ─── Install Quicklisp libraries ─────────────────────────────────────────────
echo ""
echo "Installing CL libraries (sdl2, cl-opengl, cl-glu, alexandria, bordeaux-threads)…"
sbcl --noinform --load "$QUICKLISP_INIT" \
     --eval "(ql:register-local-projects)" \
     --eval "(ql:quickload '(:sdl2 :cl-opengl :cl-glu :alexandria :bordeaux-threads) :silent t)" \
     --eval "(format t \"[OK] Libraries installed.~%\")" \
     --quit

# ─── Clear stale ASDF fasl cache for babel-world ────────────────────────────
# ASDF caches compiled .fasl files in ~/.cache/common-lisp/.
# If the cache is stale (old timestamps from tar extraction), SBCL loads the
# old compiled code even when source files have changed. Clear it to force
# a clean recompile.
CACHE_DIR="$HOME/.cache/common-lisp"
if [ -d "$CACHE_DIR" ]; then
    DELETED=$(find "$CACHE_DIR" -name "*.fasl" -path "*/babel*" -delete -print 2>/dev/null | wc -l)
    if [ "$DELETED" -gt 0 ]; then
        echo "[OK] Cleared $DELETED stale babel fasl(s) from ASDF cache."
    fi
fi

echo ""
echo "══════════════════════════════════════════"
echo "  Launching BABEL window…"
echo "  (Press H in the window for controls)"
echo "══════════════════════════════════════════"
echo ""

# ─── Launch ───────────────────────────────────────────────────────────────────
sbcl --noinform \
     --load "$QUICKLISP_INIT" \
     --eval "(ql:register-local-projects)" \
     --eval "(ql:quickload :babel-world :silent t)" \
     --eval "(babel:initialize)" \
     --eval "(babel:run)"
