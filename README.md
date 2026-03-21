# BABEL
## The Lisp Macro World Compiler

> *"In the beginning was the Word. Then the Word wrote more Words."*

BABEL is a 3D wireframe world generator in **SBCL Common Lisp** where the
AI's creative output is new **Lisp functions**. It does not draw fixed worlds —
it grows a vocabulary. Every function it invents becomes a new primitive in the
language of space. Worlds are programs written in that language. As the
vocabulary deepens, the complexity achievable in a single world-expression
grows exponentially — because each new function can call all the ones before it.

The name comes from the Tower of Babel: a structure that grows until it reaches
a new stratum of expression. BABEL builds towers of abstraction instead.

---

## Architecture

```
babel/
├── babel-world.asd     ← ASDF system (named :babel-world to avoid clash
│                          with the cl:babel encoding library)
├── install.sh          ← One-shot dependency installer & launcher
├── load.lisp           ← Flat loader (no ASDF needed)
├── repl-tour.lisp      ← Step-by-step guided REPL session
├── README.md
└── src/
    ├── package.lisp    ← Package :babel, 70+ exported symbols
    ├── geometry.lisp   ← EMIT-EDGES + sphere/cone/torus/plane/arch emitters
    ├── registry.lisp   ← babel-macro struct, *babel-registry*, export-library
    ├── layer0.lisp     ← Layer-0 primitive functions (box sphere plane …)
    ├── inventor.lisp   ← Template-based AI invention engine
    ├── scoring.lisp    ← 5-dimensional fitness scoring
    ├── evolution.lisp  ← Mutation + crossover operators
    ├── camera.lisp     ← Orbital camera (yaw/pitch/distance/pan)
    ├── gizmo.lisp      ← Screen-corner XYZ axis + ground reference rings
    ├── colour.lisp     ← 7 wireframe colour modes
    ├── terrain.lisp    ← Diamond-square heightmap terrain
    ├── renderer.lisp   ← SDL2 event loop + OpenGL 2.1 wireframe renderer
    ├── persistence.lisp← Save/load worlds + undo journal
    ├── worlds.lisp     ← 11 demo scenes + WORLD macro
    ├── export.lisp     ← OBJ / SVG / EDN geometry exporters
    ├── inspector.lisp  ← ANSI terminal macro profiler
    └── main.lisp       ← Entry point, REPL helpers, banner
```

---

## Prerequisites

| Requirement | Install |
|---|---|
| SBCL ≥ 2.0 | `sudo apt install sbcl` |
| SDL2 | `sudo apt install libsdl2-dev` |
| Quicklisp | https://www.quicklisp.org/beta/ |

Quicklisp auto-installs: `sdl2`, `cl-opengl`, `cl-glu`, `alexandria`, `bordeaux-threads`.

---

## Quick Start

```bash
chmod +x install.sh
./install.sh
```

Or from a SBCL REPL after loading Quicklisp:

```lisp
(ql:quickload :babel-world)
(babel:initialize)
(babel:run)
```

`install.sh` automatically clears stale ASDF fasl caches so you always run
the latest compiled code after an update.

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
| `R` | Reset camera to default position |
| `I` `K` | Pan camera forward / back |
| `J` `L` | Pan camera left / right |
| `←` `→` | Previous / next scene |
| `1`–`9` | Jump to scenes 0–8 directly |
| `0` | Jump to scene 9 |
| `F1` | Jump to scene 10 |
| `C` | Cycle wireframe colour mode |
| `X` | Toggle XYZ axis gizmo |
| `O` | Toggle ground reference rings |
| `G` | Grow next AI layer (background thread) |
| `E` | Evolve: mutate + crossover top macros |
| `Z` | Undo last world change |
| `S` | Save macro library → `/tmp/babel-library.lisp` |
| `W` | Export scene → `/tmp/babel-world.obj` (Blender-ready) |
| `V` | Export 4-view SVG → `/tmp/babel-quad.svg` |
| `F12` | Screenshot → `/tmp/babel-TIMESTAMP.ppm` |
| `H` | Print HUD to terminal |
| `ESC` | Quit |

---

## Demo Scenes

| Key | Scene | Highlights |
|---|---|---|
| `1` | Layer-0 Sampler | box, sphere, cone, torus, arch, plane, line |
| `2` | Tower Row | procedural tapering towers + dome |
| `3` | Fortress | keep × 4, battlements, gate arch, outbuildings |
| `4` | Walled City | full fortress + interior keeps + colonnades |
| `5` | Towers of Babel | radial keep arrangement + 20-floor mega-tower |
| `6` | Orbital Ring Stations | three concentric rings, spokes, gothic arches |
| `7` | Cave / Strata | geological layers, stalactites, underground fortress |
| `8` | Terrain Landscape | diamond-square hills + fortress + outpost keeps |
| `9` | Grand Cathedral | nave, transepts, apse, towers, cloisters, buttresses |
| `0` | Amphitheatre | 5 tiered seating rings, stage, proscenium arch |
| `F1` | Procedural City Grid | block-variant city, road grid, plaza, city wall |

---

## Colour Modes

Press `C` to cycle through 7 modes:

| Mode | Effect |
|---|---|
| `:depth` | Dark teal at ground → bright cyan at height |
| `:normal` | Hue from XZ edge direction angle |
| `:layer` | Each macro layer gets its own colour |
| `:heat` | Cold blue at bottom → hot red at top |
| `:mono` | Flat dim white |
| `:pulse` | Sinusoidal brightness wave travelling upward |
| `:rainbow` | Animated full-spectrum hue sweep |

---

## The Vocabulary

### Layer 0 — Primitive Functions

```lisp
(box     x y z  w h d)            ; axis-aligned wireframe box
(sphere  x y z  r steps)          ; geodesic wireframe sphere
(babel-line x0 y0 z0  x1 y1 z1)  ; single edge
(plane   cx cz  w d  y)           ; horizontal wireframe grid
(cone    x y z  r h steps)        ; wireframe cone
(torus   x y z  r tube steps)     ; wireframe torus ring
(arch    x y z  span rise w style); structural arch (:roman or :gothic)
```

All Layer-0 functions call `emit-edges` — the single geometry accumulation
primitive that feeds the OpenGL renderer.

### Layers 1–5 — Hand-crafted Seed Vocabulary

```
Layer 1: TOWER  DOME  COLONNADE  TERRAIN  PLATEAU
Layer 2: BATTLEMENT  KEEP
Layer 3: FORTRESS
Layer 4: WALLED-CITY
Layer 5: CITADEL  TWIN-CITIES  MONASTERY
```

### Layer 6+ — AI-Invented

Press `G` in the window to trigger the invention engine. It picks a
composition template, fills its holes with existing vocabulary, compiles an
anonymous lambda to validate it, then registers the result as a real callable
function.

**Composition templates:**

| Template | Pattern |
|---|---|
| `repeat-pattern` | `(loop for i from 0 below N do CALL)` |
| `sequential` | `(progn CALL-1 CALL-2)` |
| `with-binding` | `(let ((v EXPR)) CALL)` |
| `radial-arrangement` | Calls evenly spaced around a circle |
| `vertical-stack` | Calls at increasing Y offsets |
| `grid-arrangement` | Calls on a 2D XZ grid |

**Arg generation** uses parameter name heuristics — params named `height`,
`radius`, `floors`, `density`, `x`, `z` etc. get plausible values for their
role, not just uniform random floats.

---

## How Invention Works

```
1. TEMPLATE SELECTION
   Pick one of 6 templates at random.

2. HOLE FILLING
   Each :hole is replaced with a compatible sub-expression:
   • :MACRO-CALL-HOLE → weighted-random function from layers ≤ current
   • :COUNT-EXPR      → integer 2–8
   • :RADIUS-EXPR     → float 1–12 (architecture-appropriate)
   • :STEP-VAR etc.   → fresh unique variable symbol

3. VALIDATION (compile nil, not eval-by-name)
   Compiles an anonymous lambda over the params and applies it with
   sample arguments. Checks:
   • No circular dependencies
   • Tree depth ≤ 20
   • Body is not a duplicate of an existing function
   • Produces at least one edge when called

4. SCORING
   score = 0.20×economy + 0.25×novelty + 0.30×visual
         + 0.15×reuse  + 0.10×compat

5. REGISTRATION
   Installs the body as a real named defun via eval, adds it to
   *babel-registry*, and it immediately becomes callable from world programs.
```

---

## Evolution

Press `E` to run a mutation + crossover round on the top-scoring macros.

**Operators:**
- `mutate-substitute-call!` — replace a random sub-call with another function
- `mutate-add-repetition!` — wrap the body in a `loop … below N`
- `mutate-offset-args!` — perturb numeric literals by ±20%
- `crossover!` — splice a call from one function's body into another's

Variants only register if they score ≥ 75% of the parent's score.

---

## REPL Interaction

With the window open, interact live from a SBCL REPL:

```lisp
;; Evaluate a custom world expression live
(babel:babel-eval
  (babel:fortress 0.0 0.0 50.0)
  (babel:dome 0.0 0.0 0.0 12.0 10))

;; Preview a single function
(babel:show-macro babel:walled-city 0.0 0.0 60.0 0.3)

;; Inspect a macro in depth
(babel:? 'babel:fortress)

;; Print the full dependency tree
(babel:print-macro-tree 'babel:fortress)

;; Show all macros grouped by layer
(babel:list-macros-by-layer)

;; Print the top 10 by fitness score
(babel:print-top-macros 10)

;; Trigger AI invention of layer 6
(babel:invent-layer! 6 20 4)

;; Run evolution
(babel:evolve! 5)

;; Export geometry
(babel:export-obj! "/tmp/my-world.obj")
(babel:export-svg-quad! "/tmp/my-world.svg")
(babel:export-all! "/tmp/babel-export/")

;; Save / restore sessions
(babel:save-session! "/tmp/babel-session/")
(babel:load-session! "/tmp/babel-session/")

;; Save the vocabulary as standalone Lisp source
(babel:export-library "/tmp/babel-library.lisp")
```

---

## Export Formats

| Format | Function | Output |
|---|---|---|
| Wavefront OBJ | `export-obj!` | Vertices + line elements, loadable in Blender |
| SVG (4-view) | `export-svg-quad!` | Top / front / side / isometric projections |
| SVG (single) | `export-svg!` | Single projection, configurable mode |
| EDN | `export-edn!` | Clojure-compatible `{:vertices […] :edges […]}` |
| All | `export-all!` | Writes OBJ + SVG + EDN to a directory |

---

## The Library as Shared Artifact

The exported library is valid standalone Common Lisp — loadable anywhere:

```lisp
;;;; BABEL Macro Library — Generated …
;; Layer 3 | Score 0.90 | Uses 7
(defun FORTRESS (cx cz size) …)

;; Layer 6 | Score 0.74 | Uses 0
(defun ARENA (P0 P1 P2) …)
```

Load it in any CL environment with no BABEL runtime required. Anyone who
loads it can write world programs using the AI's invented vocabulary.

---

## Rendering

OpenGL 2.1 fixed-function pipeline via `cl-opengl` + SDL2:

- All geometry is wireframe — `gl:begin :lines` per frame
- Depth-tinted colour by default; 7 modes available via `C`
- Ground grid: faint dark lines every 10 units, ±200 range
- Ground reference rings at r=50, 100, 150 (toggle with `O`)
- Screen-corner XYZ axis gizmo rotates with camera (toggle with `X`)
- Anti-aliased lines via `gl:enable :line-smooth`
- FPS counter in window title bar

---

## ASDF System Name

The system is named **`:babel-world`** (not `:babel`) to avoid shadowing the
`babel` character-encoding library that `cffi`/`sdl2` depend on. The Lisp
**package** is still `#:babel`, so all user-facing names remain `(babel:run)`,
`(babel:fortress ...)`, etc.

---

## License

MIT — Do whatever you like. Build vocabularies. Share them.
