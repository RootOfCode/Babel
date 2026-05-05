# BABEL

BABEL is an SBCL/Common Lisp laboratory for building and evolving 3D wireframe worlds. It combines:

* a Lisp world-description DSL
* a layered vocabulary of reusable geometry functions
* an in-window SDL2/OpenGL renderer and GUI
* a live structure-code editor
* AI-assisted macro invention, scoring, and evolution
* `.world`, `.voc`, OBJ, SVG, and EDN persistence/export workflows

The project is not a fixed collection of scenes. It is a small language for growing scenes: every useful function can become part of the vocabulary used by later worlds.

This root `README.md` is the documentation hub.

## Documentation

* English: [doc-en/README.md](doc-en/README.md)
* English detailed reference: [doc-en/reference/primitives.md](doc-en/reference/primitives.md)
* Português (Brasil): [doc-ptbr/README.md](doc-ptbr/README.md)
* Referência detalhada em PT-BR: [doc-ptbr/referencia/primitivas.md](doc-ptbr/referencia/primitivas.md)

## Quick Links

* System definition: [babel-world.asd](babel-world.asd)
* First-time launcher: [install.sh](install.sh)
* Normal launcher: [run.sh](run.sh)
* Flat loader: [load.lisp](load.lisp)
* Guided REPL tour: [repl-tour.lisp](repl-tour.lisp)
* Import example: [examples/import-example.lisp](examples/import-example.lisp)
* Main entry point: [src/main.lisp](src/main.lisp)
* World scenes: [src/worlds.lisp](src/worlds.lisp)
* GUI/editor: [src/ui.lisp](src/ui.lisp)
* Renderer: [src/renderer.lisp](src/renderer.lisp)
* Registry: [src/registry.lisp](src/registry.lisp)
* AI inventor: [src/inventor.lisp](src/inventor.lisp)
* Persistence: [src/persistence.lisp](src/persistence.lisp)
* Exporters: [src/export.lisp](src/export.lisp)

## What BABEL Targets Today

BABEL currently focuses on live procedural wireframe world building:

* SBCL/Common Lisp development
* SDL2 window management
* OpenGL 2.1-style immediate wireframe rendering
* architectural and abstract 3D forms
* live REPL-driven world evaluation
* in-window code editing, import, apply, and hot reload
* vocabulary growth through generated Lisp functions
* scene, vocabulary, and geometry export for experiments and study

It is appropriate for procedural-art experiments, Lisp DSL research, architecture-inspired sketching, AI-assisted macro invention, teaching, and interactive world-programming prototypes.

It is not currently a texture renderer, physics/game engine, production CAD tool, or sandboxed execution environment.

## Quick Start

First-time setup and launch:

```bash
chmod +x install.sh run.sh
./install.sh
```

After dependencies are already installed:

```bash
./run.sh
```

From a Common Lisp REPL:

```lisp
(pushnew #P"/path/to/Babel/" asdf:*central-registry* :test #'equal)
(ql:quickload :babel-world)
(babel:initialize)
(babel:run-threaded)

(babel:babel-eval
  (plane 0.0 0.0 200.0 200.0 0.0)
  (fortress 0.0 0.0 50.0))
```

Use `run-threaded` for interactive work. Calling `(babel:run)` directly gives the current thread to the SDL event loop and blocks the REPL.

## Current Documentation Layout

All documentation now lives inside the language folders:

* `doc-en/` — English guide and detailed reference
* `doc-ptbr/` — Portuguese guide and detailed reference

The previous detailed notes were migrated into `doc-en/reference/` and `doc-ptbr/referencia/`; there is no separate `docs/` directory.
