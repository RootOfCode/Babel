# Persistence and Export

BABEL separates source persistence, vocabulary persistence, session persistence, and geometry export.

## Output Directory

Most save/export helpers write into the BABEL output directory.

```lisp
babel:*output-dir*
(babel:babel-out "filename.ext")
```

The output directory is normally created during `initialize`.

## World Files

A `.world` file stores a label and the source forms for a world.

```lisp
(babel:save-world-file! (babel:babel-out "my-world.world") "my-world")
(babel:load-world-file! (babel:babel-out "my-world.world"))
```

`babel-eval` updates `*current-world-source*`, which is what `save-world-file!` uses.

## Vocabulary Files

A `.voc` file stores registered macro definitions.

```lisp
(babel:save-vocabulary! (babel:babel-out "my-vocab.voc"))
(babel:load-vocabulary! (babel:babel-out "my-vocab.voc"))
```

To merge loaded vocabulary with the current registry:

```lisp
(babel:load-vocabulary! (babel:babel-out "extra.voc") :merge t)
```

## Session Save/Load

Session helpers save and restore broader state into a directory.

```lisp
(babel:save-session! (babel:babel-out "session/"))
(babel:load-session! (babel:babel-out "session/"))
```

## Undo Journal

BABEL keeps a small world journal so recent scene changes can be undone.

```lisp
(babel:world-undo!)
```

The GUI also exposes undo through the keyboard.

## Geometry Export

### OBJ

```lisp
(babel:export-obj!)
(babel:export-obj! (babel:babel-out "scene.obj"))
```

### SVG

```lisp
(babel:export-svg!)
(babel:export-svg! (babel:babel-out "scene.svg"))
```

### Quad SVG

```lisp
(babel:export-svg-quad!)
(babel:export-svg-quad! (babel:babel-out "scene-quad.svg"))
```

### EDN

```lisp
(babel:export-edn!)
(babel:export-edn! (babel:babel-out "scene.edn"))
```

### Export All

```lisp
(babel:export-all!)
(babel:export-all! (babel:babel-out "export/"))
```

`export-all!` is the easiest way to produce a small bundle of current-scene artifacts.

## Practical Notes

* Save `.world` when you want source that can rebuild the scene.
* Save `.voc` when you want reusable generated or custom vocabulary.
* Export OBJ/SVG/EDN when you want geometry snapshots.
* Use `.world` plus `.voc` together when a world depends on custom invented vocabulary.
