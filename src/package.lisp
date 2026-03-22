;;;; src/package.lisp — Package definitions for BABEL

(defpackage #:babel
  (:use #:cl #:alexandria)
  (:export
   ;; ── Entry points ──────────────────────────────────────────────────────────
   #:run
   #:run-threaded
   #:initialize
   ;; ── Output directory ──────────────────────────────────────────────────────
   #:*output-dir*
   #:set-output-dir!
   #:babel-out

   ;; ── Registry ──────────────────────────────────────────────────────────────
   #:*babel-registry*
   #:babel-macro
   #:babel-macro-name #:babel-macro-layer #:babel-macro-params
   #:babel-macro-body #:babel-macro-score #:babel-macro-usage-count
   #:babel-macro-complexity #:babel-macro-dependencies
   #:babel-macro-doc #:babel-macro-invented-at
   #:register-macro! #:find-babel-macro
   #:macros-up-to-layer #:babel-macro-names #:export-library

   ;; ── Layer-0 macros ────────────────────────────────────────────────────────
   #:box #:sphere #:babel-line #:plane #:cone #:torus #:arch
   #:wall-segment #:half-dome
   #:cylinder #:pyramid #:vault #:staircase #:spire #:flying-buttress
   #:emit-wall-segment-edges #:emit-hemisphere-edges
   #:emit-cylinder-edges #:emit-pyramid-edges #:emit-vault-edges
   #:emit-staircase-edges #:emit-spire-edges #:emit-flying-buttress-edges

   ;; ── Geometry accumulator ──────────────────────────────────────────────────
   #:*edge-buffer* #:*vertex-buffer*
   #:emit-edges #:clear-geometry! #:collect-geometry

   ;; ── Inventor ──────────────────────────────────────────────────────────────
   #:invent-layer! #:try-invent-macro #:bootstrap-vocabulary!

   ;; ── Scoring / evolution ───────────────────────────────────────────────────
   #:score-macro! #:rescore-all! #:evolve!
   #:score-connectivity

   ;; ── Camera ────────────────────────────────────────────────────────────────
   #:*camera* #:make-camera
   #:camera-reset! #:camera-orbit! #:camera-zoom! #:camera-pan!

   ;; ── Renderer state ────────────────────────────────────────────────────────
   #:*window-width* #:*window-height*
   #:*geometry-dirty* #:*current-fps*
   #:*world-mutex*

   ;; ── Gizmo toggles ─────────────────────────────────────────────────────────
   #:*show-gizmo* #:*show-origin*

   ;; ── World helpers ─────────────────────────────────────────────────────────
   #:world #:run-world
   #:set-scene! #:next-scene! #:prev-scene!
   #:*scenes* #:*current-scene*

   ;; ── Persistence ───────────────────────────────────────────────────────────
   #:save-world! #:load-world!
   #:save-session! #:load-session!
   #:world-undo! #:*world-journal*
   ;; .world / .voc dedicated formats
   #:save-world-file! #:load-world-file!
   #:save-vocabulary! #:load-vocabulary!
   #:*current-world-source*

   ;; ── Inspector / REPL ──────────────────────────────────────────────────────
   #:inspect-macro #:print-macro-tree
   #:print-layer-summary #:print-top-macros
   #:macro-geometry-stats #:list-macros-by-layer
   #:validate-all-scenes! #:?
   #:babel-eval #:show-macro
   #:babel-resolve-sym #:babel-rewrite-forms

   ;; ── Colour modes ──────────────────────────────────────────────────────────
   #:*colour-mode* #:*colour-modes*
   #:next-colour-mode! #:set-wire-colour #:tick-colour!

   ;; ── Terrain ───────────────────────────────────────────────────────────────
   #:terrain #:plateau
   #:emit-terrain-edges #:emit-plateau-edges
   #:register-terrain-macro!

   ;; ── Export ────────────────────────────────────────────────────────────────
   #:export-obj! #:export-svg! #:export-svg-quad!
   #:export-edn! #:export-all!))
