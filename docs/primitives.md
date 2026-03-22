# BABEL — Layer-0 Primitive Reference

Layer 0 contains the fundamental geometry functions. Every higher-layer macro
ultimately calls these. They all call `emit-edges` which accumulates geometry
into the frame buffers.

All coordinates are in world-space units. Y is up.

---

## Coordinate Conventions

| Axis | Direction |
|---|---|
| X | right |
| Y | up |
| Z | toward viewer (south) |

Most primitives are centred on their given (X Y Z) unless stated otherwise.
`wall-segment` and `staircase` use a corner/endpoint convention instead.

---

## box

```lisp
(box x y z  w h d)
```

Axis-aligned wireframe box centred at (X Y Z).

| Param | Meaning |
|---|---|
| `x y z` | Centre position |
| `w` | Width (along X) |
| `h` | Height (along Y) |
| `d` | Depth (along Z) |

Emits 12 edges: 4 bottom, 4 top, 4 vertical pillars.

```lisp
(box 0.0 5.0 0.0  10.0 10.0 10.0)   ; 10-unit cube centred at y=5
```

---

## sphere

```lisp
(sphere x y z  r steps)
```

Full wireframe sphere (all latitude and longitude lines).

| Param | Meaning |
|---|---|
| `x y z` | Centre |
| `r` | Radius |
| `steps` | Latitude subdivisions (longitude = 2×steps) |

Use `half-dome` if you want only the upper half sitting on a flat base.

```lisp
(sphere 0.0 8.0 0.0  8.0 10)
```

---

## half-dome

```lisp
(half-dome x y z  r steps)
```

Upper hemisphere only. The flat base sits at Y, the apex at Y+R.
This is the correct primitive for architectural domes — `sphere` and the
original `dome` macro both draw a full ball.

| Param | Meaning |
|---|---|
| `x y z` | Centre of the flat base |
| `r` | Radius (dome height = r) |
| `steps` | Latitude subdivisions |

```lisp
(half-dome 0.0 20.0 0.0  14.0 14)   ; base at y=20, apex at y=34
```

---

## cylinder

```lisp
(cylinder x y z  r h steps)
```

Vertical cylinder. Bottom ring at Y, top ring at Y+H. No caps.

| Param | Meaning |
|---|---|
| `x y z` | Centre of the bottom ring |
| `r` | Radius |
| `h` | Height |
| `steps` | Number of facets |

```lisp
(cylinder 0.0 0.0 0.0  4.0 20.0 12)   ; round tower, base at ground
```

---

## cone

```lisp
(cone x y z  r h steps)
```

Wireframe cone. Base ring at Y, apex at Y+H.

| Param | Meaning |
|---|---|
| `x y z` | Centre of the base ring |
| `r` | Base radius |
| `h` | Height |
| `steps` | Number of facets |

```lisp
(cone 0.0 0.0 0.0  5.0 15.0 8)
```

---

## pyramid

```lisp
(pyramid x y z  base-w base-d height)
```

Square pyramid. Base centred at (X Y Z), apex at Y+HEIGHT.

| Param | Meaning |
|---|---|
| `x y z` | Centre of the base |
| `base-w` | Base width (along X) |
| `base-d` | Base depth (along Z) |
| `height` | Vertical height |

Emits 4 base edges + 4 lateral edges to apex. No diagonals.

```lisp
(pyramid 0.0 0.0 0.0  40.0 40.0 30.0)   ; great pyramid proportions
```

---

## torus

```lisp
(torus x y z  r tube steps)
```

Wireframe torus lying flat in the XZ plane, centred at (X Y Z).

| Param | Meaning |
|---|---|
| `x y z` | Centre |
| `r` | Major radius (centreline) |
| `tube` | Minor radius (tube thickness) |
| `steps` | Segments in both directions |

```lisp
(torus 0.0 0.5 0.0  30.0 1.0 32)   ; thin perimeter ring
```

---

## arch

```lisp
(arch x y z  span rise width style)
```

Structural arch. Always spans along **X** (left-right). The arch profile
faces along Z, so the arch is viewed from the front.

| Param | Meaning |
|---|---|
| `x y z` | Centre of the base (between the two column feet) |
| `span` | Total width (column foot to column foot) |
| `rise` | Height of the arch curve above the column tops |
| `width` | Extrusion depth along Z (wall thickness) |
| `style` | `:roman` or `:gothic` (both currently draw the same curve) |

The arch emits two vertical columns plus a curved arc, duplicated and
connected into a solid arch volume.

```lisp
(arch 0.0 0.0 -50.0  12.0 14.0 1.5 :gothic)   ; portal facing south
```

> **Limitation:** `arch` cannot rotate. For a north/south-spanning arch,
> use `wall-segment` pairs framing the gap instead.

---

## vault

```lisp
(vault x y z  span length steps)
```

Barrel vault: a semicircular arch profile extruded `length` along +Z.
The arch is centred at (X Y Z); the vault runs from Z to Z+LENGTH.

| Param | Meaning |
|---|---|
| `x y z` | Centre of the first arch ring |
| `span` | Total width (chord). Rise = span/2 |
| `length` | Extrusion length along Z |
| `steps` | Arc subdivisions per ring |

The vault sides reach their lowest point at Y (ground level) and the crown
sits at Y + span. Plan accordingly: `(vault 0 0 z  10 40 8)` means the
vault sides are at ground level (y=0), crown at y=10.

```lisp
(vault 0.0 0.0 -20.0  16.0 40.0 8)   ; covered corridor, 16 wide
```

---

## spire

```lisp
(spire x y z  height base-r sides)
```

Polygonal spire. Base polygon at Y, apex at Y+HEIGHT.

| Param | Meaning |
|---|---|
| `x y z` | Centre of the base polygon |
| `height` | Total height |
| `base-r` | Circumscribed radius of the base polygon |
| `sides` | Number of sides (4 = square, 8 = octagonal) |

```lisp
(spire 0.0 52.0 0.0  28.0 4.0 8)    ; octagonal spire on a tower top
(spire 0.0 20.0 0.0  14.0 3.0 4)    ; square spike on a transept
```

---

## staircase

```lisp
(staircase x y z  width n-steps step-h step-d)
```

Staircase rising along **+Z** from (X Y Z). X is the **centre** of the
flight (not the left edge). Steps rise in Y and advance in Z.

| Param | Meaning |
|---|---|
| `x y z` | Centre of the bottom-front edge of the first step |
| `width` | Width of the flight along X |
| `n-steps` | Number of steps |
| `step-h` | Height of each step (rise) |
| `step-d` | Depth of each step (run/tread) |

Total rise = `n-steps × step-h`. Total run = `n-steps × step-d`.
The staircase lands at Z + `n-steps × step-d`, height Y + `n-steps × step-h`.

```lisp
;; 8 steps, rises 10 over 12 depth — from z=-72 to z=-60, y=0 to y=10
(staircase 0.0 0.0 -72.0  10.0 8 1.25 1.5)
```

---

## wall-segment

```lisp
(wall-segment x0 z0  x1 z1  y-base height thickness)
```

Thick wall panel running from XZ point (X0, Z0) to (X1, Z1).
The wall rises from Y-BASE to Y-BASE+HEIGHT. Thickness is extruded
perpendicular to the wall direction in the XZ plane.

| Param | Meaning |
|---|---|
| `x0 z0` | Start point (XZ) |
| `x1 z1` | End point (XZ) |
| `y-base` | Bottom Y of the wall |
| `height` | Wall height |
| `thickness` | Wall thickness |

Works for any direction: north-south, east-west, or diagonal. This is the
fundamental wall primitive — use it in preference to `box` for any wall
that needs to run in a specific direction.

```lisp
;; North wall of a fortress, y-base=0, 14 units tall
(wall-segment -50.0 50.0  50.0 50.0  0.0 14.0 2.0)

;; Diagonal curtain wall
(wall-segment -30.0 -30.0  30.0 30.0  0.0 10.0 1.5)
```

---

## flying-buttress

```lisp
(flying-buttress  wall-x wall-y wall-z  pier-x pier-y pier-z  thickness)
```

A Bezier-arc flying buttress leaping from a wall attachment point to a
free-standing pier. The midpoint is automatically lifted by 55% of the
horizontal span to produce a natural arch curve.

| Param | Meaning |
|---|---|
| `wall-x wall-y wall-z` | Point where the buttress meets the wall (high up) |
| `pier-x pier-y pier-z` | Point where the buttress meets the pier base (low) |
| `thickness` | Arch depth (extruded perpendicular to the arc plane) |

Always use in pairs, one on each side of the structure being braced.

```lisp
;; Nave buttress: wall attach at x=14 y=32, pier at x=24 y=10
(flying-buttress  14.0 32.0 -30.0   24.0 10.0 -30.0  1.4)
(flying-buttress -14.0 32.0 -30.0  -24.0 10.0 -30.0  1.4)
```

---

## plane

```lisp
(plane cx cz  w d  y)
```

Flat horizontal wireframe grid at height Y.

| Param | Meaning |
|---|---|
| `cx cz` | Centre (note: X and Z, not X Y Z) |
| `w` | Width along X |
| `d` | Depth along Z |
| `y` | Height |

```lisp
(plane 0.0 0.0  300.0 300.0  0.0)   ; ground plane
```

---

## babel-line

```lisp
(babel-line x0 y0 z0  x1 y1 z1)
```

A single wireframe edge between two 3D points. Use for roof ridges,
tie-beams, and any geometry that isn't captured by a higher primitive.

```lisp
;; Ridge beam along the nave roof
(babel-line  0.0 25.0 -50.0   0.0 25.0 -9.0)
```

---

## Geometry Pipeline

All primitives ultimately call `emit-edges`:

```
(box ...) → emit-edges → *vertex-buffer* *edge-buffer*
                              ↓
                        (collect-geometry)
                              ↓
                        OpenGL :lines per frame
```

The buffers are cleared before each world evaluation. Indices in edge pairs
are relative to the current call's vertex list and are offset automatically
on insertion, so primitives compose safely without index collisions.
