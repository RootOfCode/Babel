# World DSL Reference

This is a practical reference to the public BABEL world-programming interface. It focuses on meaning and usage, not a formal grammar.

## Reading the DSL Correctly

Inside `babel-eval` or `world`, forms are ordinary Common Lisp that usually call geometry functions. A form can:

* emit vertices and edges
* run loops or conditional logic
* call registered vocabulary entries
* call hand-written helpers
* save source information for later `.world` persistence

## Top-Level Entry Forms

### `initialize`

```lisp
(babel:initialize)
```

Bootstraps the vocabulary, prepares the output directory, prints the banner, and optionally validates scenes.

### `run-threaded`

```lisp
(babel:run-threaded)
```

Starts the SDL2/OpenGL window in a background thread. This is the recommended REPL mode.

### `run`

```lisp
(babel:run)
```

Starts the renderer on the current thread. This is useful for launch scripts, but it blocks an interactive REPL.

### `babel-eval`

```lisp
(babel:babel-eval
  (plane 0.0 0.0 200.0 200.0 0.0)
  (fortress 0.0 0.0 50.0))
```

Evaluates a world body and makes it the live scene. Unqualified BABEL function names are resolved automatically.

### `show-macro`

```lisp
(babel:show-macro keep 0.0 0.0 2.5 6)
```

Displays one macro call as the current scene.

### `world`

```lisp
(world (:seed 42)
  (plane 0.0 0.0 120.0 120.0 0.0)
  (tower 0.0 0.0 8 3.0 0.1))
```

Clears geometry, binds the random seed, and runs the body.

## Layer-0 Primitives

### `box`

```lisp
(box x y z w h d)
```

Axis-aligned wireframe box centered at `(x y z)`.

### `sphere`

```lisp
(sphere x y z r steps)
```

Wireframe sphere.

### `babel-line`

```lisp
(babel-line x0 y0 z0 x1 y1 z1)
```

Single wireframe edge.

### `plane`

```lisp
(plane cx cz w d y)
```

Horizontal grid plane centered at `(cx, y, cz)`.

### `cone`

```lisp
(cone x y z r h steps)
```

Wireframe cone. Negative height can be used for downward cone forms.

### `torus`

```lisp
(torus x y z r tube steps)
```

Wireframe torus.

### `arch`

```lisp
(arch x y z span rise width style)
```

Wireframe arch. Common styles are `:roman` and `:gothic`.

### `wall-segment`

```lisp
(wall-segment x0 z0 x1 z1 y-base height thickness)
```

Wall running between two XZ endpoints.

### `half-dome`

```lisp
(half-dome x y z r steps)
```

Hemisphere-like dome wireframe.

### `cylinder`

```lisp
(cylinder x y z r h steps)
```

Wireframe cylinder.

### `pyramid`

```lisp
(pyramid x y z base-w base-d height)
```

Wireframe pyramid.

### `vault`

```lisp
(vault x y z span length steps)
```

Arched vault form.

### `staircase`

```lisp
(staircase x y z width n-steps step-h step-d)
```

Wireframe staircase starting from a base point.

### `spire`

```lisp
(spire x y z height base-r sides)
```

Tall pointed tower cap.

### `flying-buttress`

```lisp
(flying-buttress wall-x wall-y wall-z pier-x pier-y pier-z thickness)
```

Architectural support arch between a wall point and a pier point.

## Terrain Forms

### `terrain`

```lisp
(terrain cx cz width depth resolution amplitude)
```

Diamond-square procedural terrain centered at `(cx, 0, cz)`.

### `plateau`

```lisp
(plateau cx cz width depth y-base wall-height)
```

Raised flat platform with vertical walls.

## Hand-Crafted Vocabulary

### Layer 1

```lisp
(tower x z floors radius taper)
(dome x y z radius steps)
(colonnade x z length n-pillars pillar-r pillar-h)
```

Layer 1 builds small compound elements from primitives.

### Layer 2

```lisp
(battlement x y z wall-len wall-w wall-h crenels)
(keep x z base-r floors)
```

Layer 2 builds architectural pieces.

### Layer 3

```lisp
(fortress cx cz size)
```

A four-corner keep layout with walls and a gate arch.

### Layer 4

```lisp
(walled-city cx cz size density)
```

A fortress perimeter with randomly placed interior keeps.

### Layer 5

```lisp
(citadel cx cz size platform-h)
(twin-cities cx cz city-size spacing)
(monastery cx cz size)
```

Large compositions built from the lower layers.

## Scene Navigation

```lisp
(babel:set-scene! 2)
(babel:next-scene!)
(babel:prev-scene!)
```

## Inspection

```lisp
(babel:list-macros-by-layer)
(babel:? 'babel:fortress)
(babel:print-macro-tree 'babel:fortress)
(babel:print-top-macros 10)
(babel:macro-geometry-stats 'babel:keep)
```

Use inspection when you are unsure about a function's signature, dependencies, score, or generated geometry.

## Custom Macro Registration

```lisp
(in-package :babel)

(let* ((body '(loop for i from 0 below count
                    for a = (* 2.0 pi (/ i count))
                    do (keep (* radius (cos a))
                             (* radius (sin a))
                             base-r floors)))
       (m (make-babel-macro
           :name 'ring-of-keeps
           :layer 3
           :params '(radius count base-r floors)
           :body body
           :dependencies '(keep)
           :complexity (tree-depth body)
           :score 0.85
           :usage-count 0
           :invented-at 0
           :doc "Circular arrangement of keeps.")))
  (register-macro! m))
```

Rules of thumb:

* set the layer higher than the macros you call
* list every BABEL dependency
* keep the body as a quoted s-expression
* avoid unbounded loops in generated vocabulary
