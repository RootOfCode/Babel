# How BABEL Works

This document explains BABEL as a live language-and-renderer pipeline, not only as a list of functions.

## The Short Version

A typical session works like this:

1. SBCL loads the `:babel-world` ASDF system.
2. `babel:initialize` prepares the output directory and bootstraps the vocabulary.
3. `babel:run-threaded` opens the SDL2/OpenGL window without blocking the REPL.
4. A scene is selected, imported, edited, or evaluated from the REPL.
5. The scene function clears the geometry buffers and emits vertices and edges.
6. The renderer draws the wireframe scene and overlays the GUI/editor.
7. Save/export commands write worlds, vocabularies, screenshots, or geometry files.

## Source File Model

The project is organized around focused source files:

```text
src/package.lisp      exported public interface
src/main.lisp         startup, initialize, run-threaded, babel-eval
src/worlds.lisp       built-in scenes and the world macro
src/geometry.lisp     low-level vertex/edge emitters
src/layer0.lisp       primitive public geometry functions
src/registry.lisp     babel-macro structure and registry
src/inventor.lisp     vocabulary bootstrap and invention
src/evolution.lisp    mutation and crossover
src/scoring.lisp      macro fitness scoring
src/renderer.lisp     SDL2/OpenGL renderer
src/ui.lisp           GUI overlay and code editor
src/persistence.lisp  .world, .voc, session, undo
src/export.lisp       OBJ, SVG, EDN exporters
```

## Initialization

`initialize` is the normal entry point after loading the system.

It prepares the output directory, registers the primitive and hand-crafted vocabulary layers, prints the startup banner, and optionally validates built-in scenes.

```lisp
(babel:initialize)
```

If you call it manually from a REPL, call it before evaluating worlds or opening the GUI.

## World Evaluation Pipeline

`babel-eval` is the main live-programming interface.

```lisp
(babel:babel-eval
  (plane 0.0 0.0 180.0 180.0 0.0)
  (fortress 0.0 0.0 45.0))
```

Internally it:

1. stores the original source forms in `*current-world-source*`
2. rewrites unqualified BABEL names into the `:babel` package
3. builds a thunk that runs the forms
4. hands the thunk to `run-world`
5. marks geometry dirty so the renderer rebuilds the cached arrays

## The `world` Macro

Built-in scenes usually use `world`:

```lisp
(world (:seed 42)
  (plane 0.0 0.0 200.0 200.0 0.0)
  (fortress 0.0 0.0 40.0))
```

`world` binds the random seed, clears geometry, and evaluates its body. This makes repeatable procedural scenes easy to write.

## Geometry Emission

Low-level emitters create vertices and edges. Public primitives call those emitters.

For example:

* `box` emits the eight vertices and twelve edges of an axis-aligned box
* `sphere` calls `emit-sphere-edges`
* `arch` calls `emit-arch-edges`
* `terrain` calls `emit-terrain-edges`

The renderer does not need to know which macro produced which edge. It receives flat vertex/edge buffers.

## Registry and Macro Installation

The registry maps macro names to `babel-macro` records. A record includes the macro body, parameters, dependencies, layer, score, and documentation.

`register-macro!` is the key operation. It records metadata and defines a callable Lisp function so the macro can be used immediately in worlds.

The initial bootstrap installs:

1. Layer-0 primitives
2. hand-crafted layers 1–5
3. terrain and plateau entries

## AI Invention Pipeline

The inventor works by constructing candidate macro bodies from templates and existing vocabulary.

A candidate is accepted only if it passes practical checks such as:

* no circular dependencies
* likely termination
* actual geometry emission
* no duplicate body
* edge-count safety limit

Accepted candidates are scored and registered, which makes them available to later generations.

## Evolution Pipeline

The evolution system can modify existing macro bodies by:

* substituting one macro call for another compatible call
* adding repetition
* offsetting arguments
* crossing over bodies from two macros

Successful variants are registered as new vocabulary entries.

## GUI Apply Pipeline

When the Structure Code editor applies source:

1. the editor buffer is read as Lisp forms
2. common scene shapes such as `(cons "Name" (lambda ...))` are normalized
3. the resulting forms are evaluated as a world body
4. if evaluation succeeds, the current scene changes
5. if evaluation fails, the previous scene remains active and the error is displayed

## Export Pipeline

Export functions read the current vertex/edge buffers and write the requested format. They do not re-run the scene unless the renderer or caller has already rebuilt geometry.

Use `export-all!` when you want a complete bundle of OBJ, SVG, quad SVG, and EDN files.
