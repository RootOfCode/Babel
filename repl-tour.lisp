;;;; repl-tour.lisp — Interactive guided tour of BABEL from the REPL
;;;;
;;;; This file is meant to be evaluated expression-by-expression while the
;;;; BABEL window is open in a background thread.
;;;;
;;;; Start the system first:
;;;;   (ql:quickload :babel-world)
;;;;   (babel:initialize)
;;;;
;;;; IMPORTANT: Do NOT call (babel:run) directly — it blocks the current
;;;; thread because sdl2:make-this-thread-main takes over the event loop.
;;;; Use run-threaded instead, which starts the window in a background thread
;;;; and leaves the REPL free for live evaluation:
;;;;
;;;;   (babel:run-threaded)
;;;;
;;;; Then step through this file in your editor / REPL.

(in-package #:babel)

;;;; ════════════════════════════════════════════════════════════════
;;;; STEP 1 — Inspect the vocabulary
;;;; ════════════════════════════════════════════════════════════════

;; What macros do we have at each layer?
(list-macros-by-layer)

;; How many macros total?
(hash-table-count *babel-registry*)

;; Inspect a specific macro
(find-babel-macro 'fortress)

;; Print its dependency tree
(print-macro-tree 'fortress)

;; Print the walled-city tree
(print-macro-tree 'walled-city)


;;;; ════════════════════════════════════════════════════════════════
;;;; STEP 2 — Evaluate custom world expressions live
;;;; ════════════════════════════════════════════════════════════════

;; Minimal box scene
(babel-eval
  (box 0.0 2.5 0.0 5.0 5.0 5.0))

;; Nested macro composition
(babel-eval
  (keep 0.0 0.0 3.0 8)
  (dome 0.0 (* 8 3.5) 0.0 5.0 10)
  (plane 0.0 0.0 80.0 80.0 0.0))

;; The full fortress scene
(babel-eval
  (fortress 0.0 0.0 50.0)
  (plane 0.0 0.0 150.0 150.0 0.0))

;; Walled city
(babel-eval
  (walled-city 0.0 0.0 70.0 0.3)
  (plane 0.0 0.0 200.0 200.0 0.0))

;; Radial torus garden
(babel-eval
  (plane 0.0 0.0 100.0 100.0 0.0)
  (loop for i from 0 below 8
        for a = (* 2 pi (/ i 8))
        for r = 30.0
        do (torus (* r (cos a)) 3.0 (* r (sin a)) 4.0 1.5 12))
  (sphere 0.0 8.0 0.0 6.0 10))


;;;; ════════════════════════════════════════════════════════════════
;;;; STEP 3 — AI macro invention
;;;; ════════════════════════════════════════════════════════════════

;; Grow Layer 5 (AI-invented from Layer 4 vocabulary)
(invent-layer! 5 15 4)

;; Check what was invented
(list-macros-by-layer)

;; Score all new macros
(rescore-all!)

;; See the top scorers
(let ((all (loop for v being the hash-values of *babel-registry* collect v)))
  (mapc (lambda (m)
          (format t "~A  layer=~D  score=~,3f~%"
                  (babel-macro-name m)
                  (babel-macro-layer m)
                  (babel-macro-score m)))
        (subseq (sort all #'> :key #'babel-macro-score) 0 (min 10 (length all)))))

;; Try using an AI-invented macro (replace MACRO-5-XXXX with actual name)
;; (show-macro <invented-name> 0.0 0.0 3.0 5)


;;;; ════════════════════════════════════════════════════════════════
;;;; STEP 4 — Macro evolution
;;;; ════════════════════════════════════════════════════════════════

;; Run three rounds of mutation
(evolve! 3)

;; How many macros now?
(hash-table-count *babel-registry*)

;; Show new variants
(list-macros-by-layer)


;;;; ════════════════════════════════════════════════════════════════
;;;; STEP 5 — Export the living library
;;;; ════════════════════════════════════════════════════════════════

;; Save the entire AI-grown vocabulary as a plain Lisp source file.
;; This file can be loaded in any CL environment — no BABEL runtime needed.
(babel:export-library (babel:babel-out "babel-library.lisp"))

;; Verify it's readable
(with-open-file (f (babel:babel-out "babel-library.lisp"))
  (loop repeat 20
        for line = (read-line f nil nil)
        while line do (format t "~A~%" line)))


;;;; ════════════════════════════════════════════════════════════════
;;;; STEP 6 — Build a world program using the deep vocabulary
;;;; ════════════════════════════════════════════════════════════════

;; A complete world in ~10 lines using all 4 hand-crafted layers:
(babel-eval
  ;; Ground plane
  (plane 0.0 0.0 300.0 300.0 0.0)

  ;; Central walled city
  (walled-city 0.0 0.0 80.0 0.30)

  ;; Outpost fortresses at cardinal points
  (fortress  120.0 0.0    30.0)
  (fortress -120.0 0.0    30.0)
  (fortress    0.0 0.0  120.0)
  (fortress    0.0 0.0 -120.0)

  ;; Aqueduct-like colonnades connecting outposts to centre
  (colonnade  60.0 0.0 90.0 10 0.6 12.0)
  (colonnade -60.0 0.0 90.0 10 0.6 12.0)

  ;; Monumental tori marking city perimeter
  (loop for i from 0 below 6
        for a = (* (/ pi 3) i)
        do (torus (* 50.0 (cos a)) 0.0 (* 50.0 (sin a)) 5.0 1.2 12))

  ;; Crowning dome over the city centre
  (dome 0.0 0.0 0.0 15.0 12))
