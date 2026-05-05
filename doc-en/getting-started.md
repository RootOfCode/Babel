# Getting Started

## Requirements

* SBCL 2.0 or newer
* Quicklisp
* SDL2 development files
* OpenGL support from the host system

On Debian/Ubuntu-style systems:

```bash
sudo apt update
sudo apt install sbcl libsdl2-dev
```

Quicklisp is required because the ASDF system depends on libraries such as `sdl2`, `cl-opengl`, `cl-glu`, `alexandria`, `bordeaux-threads`, and `cffi`.

## First-Time Setup

From the project root:

```bash
chmod +x install.sh run.sh
./install.sh
```

The install script prepares dependencies, cleans stale build caches where needed, loads the system, initializes BABEL, and launches the GUI.

## Normal Launch

After the first successful setup:

```bash
./run.sh
```

This is the simplest way to open the in-window workflow.

## Quicklisp / REPL Launch

If you already have Quicklisp and SBCL available:

```lisp
(pushnew #P"/path/to/Babel/" asdf:*central-registry* :test #'equal)
(ql:quickload :babel-world)
(babel:initialize)
(babel:run-threaded)
```

Then evaluate a live world:

```lisp
(babel:babel-eval
  (plane 0.0 0.0 200.0 200.0 0.0)
  (fortress 0.0 0.0 50.0))
```

Use `run-threaded` for REPL work. Calling `(babel:run)` directly blocks the current thread because SDL owns the event loop.

## Minimal World

```lisp
(babel:babel-eval
  (plane 0.0 0.0 120.0 120.0 0.0)
  (box 0.0 5.0 0.0 10.0 10.0 10.0)
  (arch 0.0 0.0 -12.0 12.0 8.0 2.0 :gothic))
```

This clears the current scene, emits a ground plane, adds a box, then adds a gothic arch.

## First GUI Actions

When the window opens:

* use the left panel to select built-in scenes
* use `FIT`, `ISO`, `TOP`, and `FRONT` to control the view
* use `EDITOR` or `F3` to open the structure-code editor
* edit the source and press `APPLY` or `F5`
* use `SAVE`, `.world`, OBJ, SVG, screenshot, or export-all actions from the GUI

## Common Startup Notes

* If the REPL freezes, you probably called `(babel:run)` directly. Use `(babel:run-threaded)` instead.
* If SDL2 fails to load, install the system SDL2 development package.
* If Quicklisp cannot find the system, push the project root into `asdf:*central-registry*` or place the project in `~/quicklisp/local-projects/`.
* If a live code edit fails, the previous scene remains active and the editor reports the read/evaluation error.
