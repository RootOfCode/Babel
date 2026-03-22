# BABEL — Writing World Programs

A world program is a sequence of function calls that populates the geometry
buffers. It can be anything from a single primitive to hundreds of nested
loops. This document covers how to write, evaluate, debug, and save them.

---

## babel-eval

The primary interface for live world programming:

```lisp
(babel:babel-eval
  FORM-1
  FORM-2
  ...)
```

`babel-eval` is a macro. It:
1. Rewrites all bare symbols (`fortress`, `keep`, etc.) into fully qualified
   `babel::` symbols, so it works from any package including `CL-USER`
2. Stores the source forms in `*current-world-source*` for later saving
3. Compiles and runs the forms as a thunk, swapping the live scene

The window updates within one render tick (a few milliseconds).

```lisp
;; Works from CL-USER — no babel: prefix needed inside babel-eval
(babel:babel-eval
  (plane 0.0 0.0 300.0 300.0 0.0)
  (fortress 0.0 0.0 50.0))
```

### show-macro

Preview a single function call:

```lisp
(babel:show-macro fortress 0.0 0.0 50.0)
(babel:show-macro keep -20.0 0.0 2.0 8)
```

---

## Coordinate System

- Y is up.
- Positive Z is toward the viewer (south in architectural terms).
- The ground plane is at y=0 by convention.
- Most functions centre their geometry on (X Y Z).
- `tower` and `keep` have no Y parameter — they always start at y=0.
- `wall-segment` and `staircase` use endpoint/corner conventions.

### Working with y-base

When building on a raised platform, shift all y-base parameters by the
platform height. If your plateau has `y-base=10`:

```lisp
(plateau 0.0 0.0  100.0 80.0  10.0 10.0)   ; top at y=10

;; All walls must start at y=10
(wall-segment -40.0 -30.0  40.0 -30.0  10.0 16.0 1.5)

;; Pillar centres: halfway up the wall = 10 + height/2
(box 0.0 18.0 0.0  2.0 16.0 2.0)   ; 10 + 16/2 = 18

;; Arch y = top of walls = 10 + 16 = 26
(arch 0.0 26.0 -30.0  20.0 6.0 1.0 :gothic)
```

---

## Common Patterns

### Ground + structure

```lisp
(babel:babel-eval
  (plane 0.0 0.0 300.0 300.0 0.0)
  (fortress 0.0 0.0 50.0))
```

### Radial arrangement

```lisp
(babel:babel-eval
  (plane 0.0 0.0 300.0 300.0 0.0)
  (loop for i from 0 below 8
        for a = (* 2 pi (/ i 8))
        for r = 60.0
        do (keep (* r (cos a)) (* r (sin a)) 1.5 5)))
```

### Explicit position list

More predictable than computed positions:

```lisp
(loop for pz in '(-40.0 -30.0 -20.0 -10.0)
      do (box -10.0 12.0 pz  2.0 20.0 2.0)
         (box  10.0 12.0 pz  2.0 20.0 2.0))
```

### Walls with door gaps

Split a wall-segment call into two pieces:

```lisp
;; South wall with 10-unit door gap centred at x=0
(wall-segment -40.0 -30.0  -5.0 -30.0  0.0 14.0 1.5)   ; left of gap
(wall-segment   5.0 -30.0  40.0 -30.0  0.0 14.0 1.5)   ; right of gap
(arch 0.0 0.0 -30.0  10.0 10.0 1.5 :gothic)             ; arch over gap
```

### Staircase to a platform

```lisp
;; Platform top at y=10, front edge at z=-60
(plateau 0.0 -10.0  80.0 80.0  10.0 10.0)

;; Staircase: 8 steps × h=1.25 × d=1.5 → rises 10, runs 12
;; Starts at z = -60-12 = -72, lands at z=-60 y=10
(staircase 0.0 0.0 -72.0  10.0 8 1.25 1.5)
```

### Semicircular apse

```lisp
;; Apse centred at (0, z=24), radius 14, 6 wall segments
(loop for i from 0 below 6
      for a0 = (* pi (/ i 6.0))
      for a1 = (* pi (/ (1+ i) 6.0))
      do (wall-segment
            (* 14.0 (cos a0)) (+ 24.0 (* 14.0 (sin a0)))
            (* 14.0 (cos a1)) (+ 24.0 (* 14.0 (sin a1)))
            0.0 16.0 1.5))
```

### Rooflines with babel-line

```lisp
;; Gabled roof: ridge at apex, rafters at each bay
(loop for pz in '(-50.0 -40.0 -30.0 -20.0 -10.0)
      do (babel-line -12.0 20.0 pz   0.0 26.0 pz)
         (babel-line  12.0 20.0 pz   0.0 26.0 pz))
;; Ridge beam
(babel-line 0.0 26.0 -50.0  0.0 26.0 -10.0)
;; Eave lines
(babel-line -12.0 20.0 -50.0  -12.0 20.0 -10.0)
(babel-line  12.0 20.0 -50.0   12.0 20.0 -10.0)
```

---

## Debugging

### Checking function signatures

```lisp
(babel:? 'babel:tower)          ; full profile: params, score, doc, deps
(babel:list-macros-by-layer)    ; all registered names by layer
```

### Common mistakes

**Wrong argument count** — `tower` takes `(x z floors radius taper)`, no Y.
`keep` takes `(x z base-r floors)`, no Y. Always check with `(babel:? 'name)`.

**colonnade only runs along X** — for a colonnade along Z, use a loop of
`box` calls with varying Z positions.

**arch only spans along X** — for an arch spanning Z (e.g. a transept end
window), use a tall `box` with a small X dimension to suggest a window frame.

**wall-segment x0 z0** — the first two params are XZ, not XY. The Y position
is controlled by `y-base`.

**staircase x is the centre** — not the left edge. A staircase at x=0
width=10 spans x=-5 to x=+5.

**dome draws a full ball** — use `half-dome` for an actual dome shape.

### Undo

```lisp
(babel:world-undo!)   ; or press Z in the window
```

---

## Inspecting World Internals

```lisp
;; How much geometry does the current scene have?
(length babel:*vertex-buffer*)
(length babel:*edge-buffer*)

;; Geometry stats for a specific macro
(babel:macro-geometry-stats 'babel:fortress)

;; Preview expansion without displaying
(babel:preview-expansion 'babel:fortress 0.0 0.0 50.0)
```

---

## Built-in Demo Scenes

The demo scenes show what the vocabulary can produce. Browse them with
arrow keys or jump directly:

```lisp
(babel:set-scene! 2)    ; Fortress
(babel:set-scene! 8)    ; Grand Cathedral
(babel:set-scene! 10)   ; Procedural City Grid
(babel:next-scene!)
(babel:prev-scene!)
```

Access a scene's geometry function:

```lisp
(nth 2 babel:*scenes*)   ; → ("Fortress (Layer 3)" . #<function>)
```
