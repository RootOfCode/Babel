# BABEL Documentation

This directory contains the English documentation for BABEL.

## Contents

### Main guide

* [Getting Started](getting-started.md)
* [Core Concepts](core-concepts.md)
* [How BABEL Works](how-babel-works.md)
* [World DSL Reference](world-dsl-reference.md)
* [GUI Workflow](gui-workflow.md)
* [Persistence and Export](persistence-and-export.md)
* [Examples Guide](examples-guide.md)

### Detailed reference

* [Layer-0 Primitive Reference](reference/primitives.md)
* [Vocabulary Reference](reference/vocabulary.md)
* [Writing World Programs](reference/worlds.md)
* [AI System Reference](reference/ai-system.md)
* [Persistence Reference](reference/persistence.md)
* [Legacy README before Documentation Refresh](reference/legacy-readme-before-docs-refresh.md)

## What BABEL Is

BABEL is a Common Lisp system for live 3D wireframe world programming.

It lets you describe:

* worlds as Lisp forms
* geometry with Layer-0 primitives such as boxes, spheres, arches, planes, towers, walls, and terrain
* higher-level architectural structures through registered BABEL macros
* reusable vocabularies with `.voc` files
* saveable world source with `.world` files
* geometry exports as OBJ, SVG, SVG quad-view, and EDN

The system itself runs in SBCL and uses SDL2/OpenGL for the interactive window. The worlds are not loaded from a fixed asset set; they are programs that emit geometry.

## Current Scope

BABEL is currently centered on:

* SBCL and Quicklisp
* SDL2 and OpenGL 2.1-style wireframe rendering
* architectural, abstract, terrain, and city-like procedural scenes
* in-window GUI controls and live structure source editing
* AI-assisted macro invention, scoring, mutation, and crossover
* simple persistence/export formats for experimentation

It is not yet a full game engine, full mesh editor, physics simulator, animation package, or secure sandbox for untrusted Lisp code.

## Recommended Reading Order

1. [Getting Started](getting-started.md)
2. [Core Concepts](core-concepts.md)
3. [How BABEL Works](how-babel-works.md)
4. [World DSL Reference](world-dsl-reference.md)
5. [GUI Workflow](gui-workflow.md)
6. [Persistence and Export](persistence-and-export.md)
7. [Examples Guide](examples-guide.md)
8. [Detailed Reference](reference/primitives.md)
