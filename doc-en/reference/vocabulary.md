# BABEL — Vocabulary Reference

The vocabulary is a layered lattice of functions. Each layer can only call
functions from layers below it. This rule ensures the dependency graph is
always a DAG with no cycles.

---

## The Layer Model

```
Layer 0  ──  primitive geometry (box, arch, wall-segment, ...)
Layer 1  ──  architectural components (tower, dome, colonnade, ...)
Layer 2  ──  compound elements (battlement, keep)
Layer 3  ──  compositions (fortress)
Layer 4  ──  settlements (walled-city)
Layer 5  ──  mega-structures (citadel, twin-cities, monastery)
Layer 6+ ──  AI-invented (grows when you press G or call invent-layer!)
```

A function at layer N can call any function at layer 0 through N-1.

---

## Layer 1 — Architectural Components

### tower

```lisp
(tower x z  floors radius taper)
```

Tapering tower of stacked box floors. Note: **no Y parameter** — the tower
always starts at y=0.

| Param | Meaning |
|---|---|
| `x z` | Base centre (XZ, not XYZ) |
| `floors` | Number of floors |
| `radius` | Base half-width |
| `taper` | Reduction per floor (0.0 = no taper, 0.1 = 10% reduction/floor) |

```lisp
(tower 0.0 -55.0  14  3.0  0.05)   ; 14-floor tower, gentle taper
```

### dome

```lisp
(dome x y z  radius steps)
```

Full sphere resting on a flat plane. Draws both the sphere and a grid
plane at Y. For an actual dome shape use `half-dome` instead.

### colonnade

```lisp
(colonnade x z  length n-pillars pillar-r pillar-h)
```

Row of box pillars along **X** only. The colonnade cannot be rotated.
For a colonnade running along Z, use a loop of `box` calls.

| Param | Meaning |
|---|---|
| `x z` | Start of the row |
| `length` | Total length along X |
| `n-pillars` | Number of pillars |
| `pillar-r` | Pillar half-width |
| `pillar-h` | Pillar height |

### terrain

```lisp
(terrain cx cz  width depth  seed  amplitude)
```

Diamond-square heightmap terrain centred at (CX CZ).

### plateau

```lisp
(plateau cx cz  width depth  y-base  wall-height)
```

Flat raised platform. The top surface is at Y-BASE. Vertical walls drop
DOWN by WALL-HEIGHT to Y-BASE - WALL-HEIGHT.

```lisp
;; Platform: top at y=10, base at y=0
(plateau 0.0 0.0  88.0 100.0  10.0 10.0)
```

---

## Layer 2 — Compound Elements

### battlement

```lisp
(battlement x y z  wall-len wall-w wall-h crenels)
```

Solid wall with merlons (crenellated parapet). Runs along **X only**.
For east/west walls use `wall-segment` instead.

| Param | Meaning |
|---|---|
| `x y z` | Centre of the wall base |
| `wall-len` | Wall length along X |
| `wall-w` | Wall thickness |
| `wall-h` | Total height including merlons |
| `crenels` | Number of merlons |

The wall body is 72% of `wall-h`; merlons occupy the top 28%.

### keep

```lisp
(keep x z  base-r floors)
```

Castle keep: a tapered tower with battlements on top. No Y parameter —
always starts at ground level.

| Param | Meaning |
|---|---|
| `x z` | Base centre (XZ) |
| `base-r` | Base half-width |
| `floors` | Number of tower floors |

---

## Layer 3

### fortress

```lisp
(fortress cx cz  size)
```

Four corner keeps connected by full-height walls. North/south walls use
`battlement`; east/west walls use `wall-segment`. Includes a gothic gate
arch in the south wall.

| Param | Meaning |
|---|---|
| `cx cz` | Centre of the fortress |
| `size` | Half-extent (fortress spans cx±size, cz±size) |

```lisp
(fortress 0.0 0.0  50.0)   ; 100×100 unit fortress
```

---

## Layer 4

### walled-city

```lisp
(walled-city cx cz  size density)
```

A fortress perimeter with randomly placed interior keeps.

| Param | Meaning |
|---|---|
| `cx cz` | Centre |
| `size` | Fortress half-extent |
| `density` | Interior keep density (0.1 sparse … 0.4 dense) |

---

## Layer 5

### citadel

```lisp
(citadel cx cz  size  platform-h)
```

Fortress raised on a stone plateau.

### twin-cities

```lisp
(twin-cities cx cz  city-size  spacing)
```

Two walled cities flanking a central fortress, connected by colonnades.

### monastery

```lisp
(monastery cx cz  size)
```

Four colonnades forming a cloister courtyard, bell tower, and dome chapel.

---

## Writing Custom Macros

The simplest way to add a macro is from the REPL using `make-babel-macro`
and `register-macro!`:

```lisp
(in-package :babel)

(let* ((body '(loop for i from 0 below count
                    for a = (* 2.0 pi (/ i count))
                    for r = radius
                    do (keep (* r (cos a)) (* r (sin a)) base-r floors)))
       (m (make-babel-macro
           :name        'ring-of-keeps
           :layer       3              ; above keep (layer 2)
           :params      '(radius count base-r floors)
           :body        body
           :dependencies '(keep)
           :complexity  (tree-depth body)
           :score       0.85
           :usage-count 0
           :invented-at *generation*
           :doc         "Circular arrangement of keeps.")))
  (register-macro! m))

;; Use it immediately
(babel:babel-eval (ring-of-keeps 40.0 8 1.5 5))
```

### Rules for custom macros

1. **Layer** must be strictly higher than every function you call.
2. **`:dependencies`** must list every BABEL function your body calls by symbol.
3. **`:body`** is a quoted s-expression. It is compiled as `(lambda params body)`.
4. **`:params`** is a plain list of symbols — no `&optional`, no destructuring.

### Saving your vocabulary

```lisp
;; Save to output/ directory
(babel:save-vocabulary! (babel:babel-out "my-vocab.voc"))

;; Restore in a new session
(babel:load-vocabulary! (babel:babel-out "my-vocab.voc"))

;; Merge two vocabularies
(babel:load-vocabulary! (babel:babel-out "base.voc"))
(babel:load-vocabulary! (babel:babel-out "extra.voc") :merge t)
```

### Inspecting the vocabulary

```lisp
(babel:list-macros-by-layer)          ; all macros grouped by layer
(babel:print-macro-tree 'babel:fortress)  ; full dependency tree
(babel:? 'babel:keep)                 ; detailed profile of one macro
(babel:print-top-macros 10)           ; top 10 by fitness score
```

---

## The babel-macro Struct

Every registered macro is a `babel-macro` struct:

| Field | Type | Meaning |
|---|---|---|
| `name` | symbol | Interned in `:babel` package |
| `layer` | integer | Dependency layer |
| `params` | list | Parameter symbols |
| `body` | s-expr | Quoted function body |
| `dependencies` | list | Symbols of called babel functions |
| `complexity` | integer | Tree depth of body |
| `score` | float | Composite fitness score 0.0–1.0 |
| `usage-count` | integer | Times called during scoring/evolution |
| `invented-at` | integer | Generation counter at registration |
| `doc` | string | Description |

Access fields with `babel-macro-NAME` accessors, e.g. `(babel-macro-score m)`.
