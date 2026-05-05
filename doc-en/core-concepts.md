# Core Concepts

## File Types

### `.lisp`

Normal Common Lisp source files. BABEL is an ASDF system named `:babel-world` and a package named `:babel`.

Important files:

* `src/main.lisp` — entry points, initialization, `babel-eval`, REPL helpers
* `src/worlds.lisp` — built-in demo scenes and the `world` macro
* `src/layer0.lisp` — primitive geometry functions
* `src/registry.lisp` — BABEL macro metadata and registration
* `src/inventor.lisp` — hand-crafted layers and AI macro invention
* `src/ui.lisp` — GUI overlay and live code editor
* `src/renderer.lisp` — SDL2/OpenGL event loop and drawing

### `.world`

A saved world source file. It stores a label and the Lisp forms needed to rebuild a world.

### `.voc`

A saved vocabulary. It preserves registered BABEL macro definitions so a later session can reuse or merge them.

### Export formats

BABEL can export the current geometry as:

* `.obj` — general 3D geometry interchange
* `.svg` — projected wireframe drawing
* quad-view `.svg` — four projection views in one file
* `.edn` — data-oriented representation of vertices and edges

## World Model

A BABEL world is a Lisp program that emits wireframe geometry.

The runtime buffers are:

* `*vertex-buffer*` — accumulated vertices
* `*edge-buffer*` — accumulated edge index pairs

A world does not usually return a mesh object. It runs functions such as `box`, `sphere`, `fortress`, or `terrain`; those functions append vertices and edges to the buffers. The renderer reads those buffers and draws the current scene.

## Vocabulary Model

BABEL treats reusable geometry functions as vocabulary entries.

A registered entry stores:

* name
* layer
* parameter list
* Lisp body
* dependencies
* score
* complexity
* usage count
* documentation string
* generation marker

Layering is important. A higher-level macro should depend only on primitives or macros from lower layers. This keeps generated vocabulary mostly acyclic and easier to inspect.

## Layer Model

The initial hand-crafted vocabulary is:

* Layer 0 — low-level wireframe emitters such as `box`, `sphere`, `plane`, `arch`, `wall-segment`, `spire`
* Layer 1 — simple compound forms such as `tower`, `dome`, `colonnade`, `terrain`, `plateau`
* Layer 2 — architectural pieces such as `battlement` and `keep`
* Layer 3 — complete structures such as `fortress`
* Layer 4 — larger arrangements such as `walled-city`
* Layer 5 — high-level compositions such as `citadel`, `twin-cities`, and `monastery`

The inventor can then propose new macro bodies that call existing vocabulary.

## Build-Time Versus World-Time

BABEL source mixes two modes:

### Load / build time

These happen while SBCL loads the project or while you call system functions:

* ASDF system loading
* package setup
* `initialize`
* `bootstrap-vocabulary!`
* macro registration
* save/load/export function calls

### World evaluation time

These happen when a scene is rebuilt:

* `babel-eval`
* `run-world`
* `world`
* geometry function calls
* loops and `let` forms inside a world
* emitted vertices and edges

A form inside `babel-eval` is real Common Lisp. It can use loops, conditionals, math, local bindings, and BABEL geometry functions.

## Renderer Model

The SDL2/OpenGL window owns an event loop. The renderer:

1. handles input
2. rebuilds geometry when marked dirty
3. updates camera state
4. draws the wireframe scene
5. draws the grid, gizmo, GUI, editor, and stats overlays

For interactive REPL work, run the window on a background thread with `run-threaded`.

## Editor Model

The in-window Structure Code editor stores source text, not only geometry. Pressing `APPLY` reads the editor buffer as Lisp forms, normalizes common scene formats, evaluates the world, and keeps the old scene alive if the new source errors.

The editor can also import a source file through the OS file picker and hot-reload that imported file while BABEL is running.
