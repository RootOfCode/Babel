# BABEL
## The Lisp Macro World Compiler

> *"In the beginning was the Word. Then the Word wrote more Words."*

BABEL is a 3D wireframe world generator in **SBCL Common Lisp** where the AI's creative output is new **Lisp functions**. It does not draw fixed worlds — it grows a vocabulary. Every function it invents becomes a new primitive in the language of space. Worlds are programs written in that language. As the vocabulary deepens, the complexity achievable in a single world-expression grows exponentially — because each new function can call all the ones before it.

---

## Quick Start

```bash
chmod +x install.sh
./install.sh
```

The window opens in a background thread. Your REPL is free immediately:

```lisp
(babel:babel-eval
  (fortress 0.0 0.0 50.0)
  (dome 0.0 0.0 0.0 12.0 10))
```

> **Never call `(babel:run)` directly** — it blocks the REPL thread. Always use `run-threaded` or `install.sh`.

---

## Starting with Quicklisp

If you already have Quicklisp and SBCL set up, you can load and run BABEL without `install.sh`:

```lisp
;; 1. Register the system (only needed once per session if not in local-projects)
(pushnew "/path/to/Babel/" asdf:*central-registry* :test #'equal)

;; 2. Load it
(ql:quickload :babel-world)

;; 3. Bootstrap the vocabulary
(babel:initialize)

;; 4. Open the window in a background thread — keeps the REPL free
(babel:run-threaded)

;; 5. Evaluate worlds live
(babel:babel-eval
  (fortress 0.0 0.0 50.0)
  (plane 0.0 0.0 200.0 200.0 0.0))
```

If you cloned Babel into `~/quicklisp/local-projects/babel-world/`, Quicklisp will find it automatically and step 1 can be skipped.

> **Never call `(babel:run)` instead of `(babel:run-threaded)`** — `run` hands the calling thread to SDL2 permanently, freezing the REPL.

---

## Prerequisites

| Requirement | Install |
|---|---|
| SBCL >= 2.0 | `sudo apt install sbcl` |
| SDL2 | `sudo apt install libsdl2-dev` |
| Quicklisp | https://www.quicklisp.org/beta/ |

Quicklisp auto-installs: `sdl2`, `cl-opengl`, `cl-glu`, `alexandria`, `bordeaux-threads`.

---

## Architecture

```
Babel/
├── babel-world.asd      ← ASDF system (:babel-world, avoids clash with cl:babel)
├── docs/
│   ├── ai-system.md     ← Inventor engine, scoring, evolution
│   ├── persistence.md   ← Saving/loading worlds, vocabularies, output directory
│   ├── primitives.md    ← Full Layer-0 primitive reference with signatures
│   ├── vocabulary.md    ← Vocabulary layers, hand-crafted macros, custom macros
│   └── worlds.md        ← Writing world programs, babel-eval, examples
├── install.sh           ← Dependency installer, cache cleaner, and launcher
├── load.lisp            ← Flat loader (no ASDF needed)
├── README.md
├── repl-tour.lisp       ← Step-by-step guided REPL session
├── src/
│   ├── camera.lisp      ← Orbital camera (yaw/pitch/distance/pan)
│   ├── colour.lisp      ← 7 wireframe colour modes
│   ├── evolution.lisp   ← Mutation + crossover operators
│   ├── export.lisp      ← OBJ / SVG / EDN geometry exporters
│   ├── geometry.lisp    ← EMIT-EDGES + 14 low-level shape emitters
│   ├── gizmo.lisp       ← Screen-corner XYZ axis + ground reference rings
│   ├── inspector.lisp   ← ANSI terminal macro profiler
│   ├── inventor.lisp    ← Template-based AI invention engine + hand-crafted layers
│   ├── layer0.lisp      ← 15 Layer-0 primitive functions
│   ├── main.lisp        ← Entry point, babel-eval, output directory, banner
│   ├── package.lisp     ← Package :babel, 80+ exported symbols
│   ├── persistence.lisp ← .world/.voc formats, session save/load, undo journal
│   ├── registry.lisp    ← babel-macro struct, *babel-registry*, export-library
│   ├── renderer.lisp    ← SDL2 event loop + OpenGL 2.1 wireframe renderer
│   ├── scoring.lisp     ← 6-dimensional fitness scoring
│   ├── terrain.lisp     ← Diamond-square heightmap + plateau emitter
│   └── worlds.lisp      ← 11 demo scenes + WORLD macro
└── worlds/
    ├── The_Basilica_Of_Broken_Skies.world
    ├── The_Cathedral_of_Spires.world
    ├── The_Great_Aqueduct.world
    ├── The_Necropolis_of_Ahk-Meren.world
    └── The_Obsidian_Monastery.world
```

---

## Controls

### Mouse
| Input | Action |
|---|---|
| Left-drag | Orbit camera |
| Right-drag | Pan camera |
| Scroll | Zoom in / out |

### Keyboard
| Key | Action |
|---|---|
| `R` | Reset camera |
| `I` `K` | Pan forward / back |
| `J` `L` | Pan left / right |
| `<-` `->` | Previous / next scene |
| `1`-`9` | Jump to scenes 0-8 |
| `0` | Scene 9 |
| `F1` | Scene 10 |
| `C` | Cycle colour mode |
| `X` | Toggle XYZ gizmo |
| `O` | Toggle ground rings |
| `G` | Grow next AI layer |
| `E` | Evolve top macros |
| `Z` | Undo last world change |
| `S` | Save macro library |
| `P` | Save world as .world file |
| `W` | Export OBJ (Blender) |
| `V` | Export 4-view SVG |
| `F12` | Screenshot |
| `H` | Print HUD |
| `ESC` | Quit |

All output goes to `output/` next to `babel-world.asd`.

---

## Layer-0 Primitives (quick reference)

```lisp
(box          x y z  w h d)
(sphere       x y z  r steps)
(half-dome    x y z  r steps)          ; hemisphere, flat base at y
(cylinder     x y z  r h steps)
(cone         x y z  r h steps)
(pyramid      x y z  base-w base-d height)
(torus        x y z  r tube steps)
(arch         x y z  span rise width style)   ; :roman or :gothic
(vault        x y z  span length steps)        ; barrel vault along +Z
(spire        x y z  height base-r sides)
(staircase    x y z  width n-steps step-h step-d)  ; rises along +Z
(wall-segment x0 z0  x1 z1  y-base height thickness)
(flying-buttress  wx wy wz  px py pz  thickness)
(plane        cx cz  w d  y)
(babel-line   x0 y0 z0  x1 y1 z1)
```

See [docs/primitives.md](docs/primitives.md) for full parameter descriptions.

---

## Vocabulary Layers

```
Layer 0:  box sphere half-dome cylinder pyramid cone torus arch vault
          spire staircase wall-segment flying-buttress plane babel-line
Layer 1:  tower dome colonnade terrain plateau
Layer 2:  battlement keep
Layer 3:  fortress
Layer 4:  walled-city
Layer 5:  citadel twin-cities monastery
Layer 6+: AI-invented
```

See [docs/vocabulary.md](docs/vocabulary.md) for signatures and patterns.

---

## Further Reading

| Document | Contents |
|---|---|
| [docs/primitives.md](docs/primitives.md) | Every Layer-0 function with full parameter docs |
| [docs/vocabulary.md](docs/vocabulary.md) | How to read, write, and extend the vocabulary |
| [docs/ai-system.md](docs/ai-system.md) | Invention engine, scoring formula, evolution |
| [docs/worlds.md](docs/worlds.md) | Writing world programs, patterns, examples |
| [docs/persistence.md](docs/persistence.md) | Saving/loading, export formats, output dir |
| [repl-tour.lisp](repl-tour.lisp) | Interactive step-by-step REPL walkthrough |

---

## License

MIT — Do whatever you like. Build vocabularies. Share them.
