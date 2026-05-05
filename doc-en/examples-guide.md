# Examples Guide

BABEL ships with built-in scenes, saved `.world` files, a REPL tour, and an import example.

## Guided REPL Tour

Use:

```lisp
(load "repl-tour.lisp")
```

The tour demonstrates loading, initializing, opening the window, evaluating worlds, inspecting macros, and saving/exporting.

## Import Example

`examples/import-example.lisp` is intended as a starting file for the GUI import button. Copy or edit it, then import it from the Structure Code editor.

## Built-In Scenes

Built-in scenes live in `src/worlds.lisp` and corresponding editor snippets live in `src/scene-source.lisp`.

You can browse with the GUI or from the REPL:

```lisp
(babel:set-scene! 0)
(babel:next-scene!)
(babel:prev-scene!)
```

## Scene 0 — Layer-0 Sampler

A compact view of primitives such as box, sphere, cone, torus, plane, arch, and line.

Use it to learn the basic coordinate system and primitive shape signatures.

## Scene 1 — Tower Row

A row of towers plus a dome. Useful for understanding Layer-1 compound forms.

## Scene 2 — Fortress

A Layer-3 fortress with corner keeps, walls, a gate arch, and small outbuildings.

Use it as the first architectural composition reference.

## Scene 3 — Walled City

A larger Layer-4 scene that combines fortress boundaries, keeps, colonnades, and domes.

Use it as a reference for city-like procedural arrangements.

## Scene 4 — Towers of Babel

An abstract radial tower composition. Useful for loop-based layout patterns.

## Scene 5 — Orbital Ring Stations

A circular/radial arrangement of structures and connecting lines.

## Scene 6 — Cave / Strata Cross-Section

A vertical composition with surface grids, strata, stalactite/stalagmite forms, underground fortress geometry, and a sphere void.

## Scene 7 — Terrain Landscape

Combines diamond-square terrain with architecture.

## Scene 8 — Grand Cathedral

A larger architectural example with nave, transept, apse, towers, arches, buttresses, cloisters, and walls.

## Scene 9 — Amphitheatre

A radial tiered seating style example.

## Scene 10 — Procedural City Grid

A grid/city-style procedural scene.

## Saved Worlds

The `worlds/` directory includes named `.world` files such as:

* `The_Basilica_Of_Broken_Skies.world`
* `The_Cathedral_of_Spires.world`
* `The_Great_Aqueduct.world`
* `The_Necropolis_of_Ahk-Meren.world`
* `The_Obsidian_Monastery.world`
* `backpack.world`

Load one from the REPL:

```lisp
(babel:load-world-file! #P"worlds/The_Cathedral_of_Spires.world")
```

## Writing Your Own Example

```lisp
(babel:babel-eval
  (world (:seed 123)
    (plane 0.0 0.0 240.0 240.0 0.0)
    (citadel 0.0 0.0 50.0 10.0)
    (loop for i from 0 below 8
          for a = (* 2.0 pi (/ i 8))
          do (keep (* 80.0 (cos a))
                   (* 80.0 (sin a))
                   2.0
                   5))))
```

This is the normal pattern for custom examples: start with ground or terrain, compose vocabulary, then use loops for repetition.
