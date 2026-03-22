# BABEL — Persistence Reference

BABEL has three levels of persistence: individual world programs (`.world`),
vocabulary snapshots (`.voc`), and full sessions. All output goes to the
`output/` directory next to `babel-world.asd`.

---

## Output Directory

All files are written relative to `*output-dir*`, which is set automatically
when `initialize` runs. Use `babel-out` to construct paths:

```lisp
(babel:babel-out "my-file.world")
;; → #P"/path/to/babel/output/my-file.world"
```

The directory is created automatically. You can override it:

```lisp
(setf babel:*output-dir* #p"/home/me/babel-saves/")
```

---

## .world Files

A `.world` file stores a world expression so it can be re-evaluated exactly
in any session. It is a plain s-expression (readable by `read`).

### Saving

```lisp
;; Quicksave: press P in the window
;; → output/babel-world.world

;; From the REPL with a custom name
(babel:save-world-file! (babel:babel-out "my-scene.world") "my-scene-label")

;; After calling babel-eval, *current-world-source* holds the last source
;; save-world-file! uses it automatically
```

### Loading

```lisp
(babel:load-world-file! (babel:babel-out "my-scene.world"))
```

If the file contains a world source expression, it is re-evaluated and
displayed live. If it only contains a built-in scene index, that scene is
activated.

### File format

```lisp
(:babel-world-format t
 :version        1
 :label          "my-scene-label"
 :timestamp      <universal-time>
 :scene-index    -1
 :world-source   ((fortress 0.0 0.0 50.0) (plane 0.0 0.0 200.0 200.0 0.0))
 :macro-count    20)
```

The `:world-source` field holds the unevaluated forms that were passed to
`babel-eval`. On load, these are compiled and run directly.

---

## .voc Files

A `.voc` file stores the full macro vocabulary with all metadata: layer,
score, usage-count, dependencies, and doc strings. Unlike `export-library`,
which writes plain `defun` source, `.voc` files can be fully restored
including AI-invented layers and scoring data.

### Saving

```lisp
(babel:save-vocabulary! (babel:babel-out "session-vocab.voc"))
```

Saves every macro currently in `*babel-registry*`.

### Loading

```lisp
;; Replace the current registry entirely
(babel:load-vocabulary! (babel:babel-out "session-vocab.voc"))

;; Merge on top of the current registry
(babel:load-vocabulary! (babel:babel-out "ai-layer6.voc") :merge t)
```

With `:merge t`, macros from the file are added without clearing existing
ones. If a name collision occurs, the loaded version overwrites.

### File format

```lisp
(:babel-voc-format t
 :version     1
 :timestamp   <universal-time>
 :macro-count 27
 :macros (
   (:name BOX :layer 0 :params (x y z w h d)
    :body (...) :dependencies () :complexity 3
    :score 1.0 :usage-count 0 :invented-at 0
    :doc "Axis-aligned wireframe box")
   ...))
```

---

## Session Save/Load

A session snapshot saves both the macro library and a scene index:

```lisp
(babel:save-session! (babel:babel-out "session/"))
(babel:load-session! (babel:babel-out "session/"))
```

`save-session!` writes two files into the directory:
- `babel-library.lisp` — standalone Common Lisp source (no runtime needed)
- `session-index.lisp` — documents which scenes exist and how to load them

This is a lighter format than `.voc` — it writes plain `defun` source
without metadata. Use `.voc` if you want to preserve scores and usage counts.

---

## Export Formats

These write geometry from the current scene:

| Function | Key | Output |
|---|---|---|
| `export-obj!` | `W` | Wavefront OBJ — vertices + line elements |
| `export-svg-quad!` | `V` | 4-view SVG (top/front/side/iso) |
| `export-svg!` | — | Single-view SVG |
| `export-edn!` | — | Clojure-compatible `{:vertices [...] :edges [...]}` |
| `export-all!` | — | OBJ + SVG + EDN to a directory |

```lisp
;; Named exports
(babel:export-obj! (babel:babel-out "cathedral.obj"))
(babel:export-svg-quad! (babel:babel-out "cathedral-views.svg"))
(babel:export-all! (babel:babel-out "cathedral-export/"))

;; Default paths (output/ directory)
(babel:export-obj!)
(babel:export-svg-quad!)
```

### OBJ in Blender

`File → Import → Wavefront (.obj)`. Edges are written as `l` (line)
elements. The mesh has no faces — it is a pure wireframe. In Blender,
switch to Wireframe display mode to see the structure as intended.

### SVG projections

The quad SVG has four views:
- **Top** — looking straight down (XZ plane)
- **Front** — looking south (XY plane)
- **Side** — looking west (ZY plane)
- **Isometric** — simplified 30° projection

---

## Macro Library Export

The library export writes standalone Common Lisp `defun` forms — no BABEL
runtime required to load it:

```lisp
(babel:export-library (babel:babel-out "babel-library.lisp"))
```

Output format:
```lisp
;;;; BABEL Macro Library — Generated at universal-time 123456789

(in-package #:cl-user)

;; Layer 3 | Score 0.92 | Uses 0
(defun FORTRESS (cx cz size)
  ...)

;; Layer 6 | Score 0.74 | Uses 0
(defun MACRO-6-5723 (p0 p1 p2)
  ...)
```

Load in any CL environment:
```lisp
(load "/path/to/babel-library.lisp")
(FORTRESS 0.0 0.0 50.0)   ; callable directly
```

---

## Undo Journal

Every call to `run-world` (including `babel-eval`) pushes the previous
world function onto the undo journal:

```lisp
(babel:world-undo!)   ; or press Z in the window
```

The journal holds up to 20 entries. There is no redo.

```lisp
babel:*world-journal*   ; list of (timestamp . world-fn) pairs
```
