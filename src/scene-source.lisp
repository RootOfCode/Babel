;;;; src/scene-source.lisp
;;;; Source text shown in the in-window Structure Code editor.
;;;; Generated from src/worlds.lisp so the GUI can show the Lisp program
;;;; behind each built-in structure without depending on terminal output.

(in-package #:babel)

(defparameter *scene-code-snippets*
  (vector
   ";; Built-in scene 0: Layer-0 Sampler
;; Click scene 0 or evaluate a similar structure.

(cons \"Layer-0 Sampler\"
    (lambda ()
      (world (:seed 1)
        (box     0.0  2.5  0.0  5.0 5.0 5.0)
        (sphere  12.0 3.0  0.0  3.0 8)
        (cone   -12.0 0.0  0.0  3.0 6.0 10)
        (torus    0.0 0.0 12.0  4.0 1.2 12)
        (plane    0.0 0.0 60.0 60.0 0.0)
        (arch    -25.0 0.0  0.0  8.0 5.0 2.0 :roman)
        (arch     25.0 0.0  0.0  8.0 5.0 2.0 :gothic)
        (babel-line -30.0 0.0 -30.0 30.0 0.0 30.0)
        (babel-line  30.0 0.0 -30.0 -30.0 0.0 30.0))))"
   ";; Built-in scene 1: Tower Row (Layer 1)
;; Click scene 1 or evaluate a similar structure.

(cons \"Tower Row (Layer 1)\"
    (lambda ()
      (world (:seed 2)
        (plane 0.0 0.0 80.0 80.0 0.0)
        (loop for x from -30 to 30 by 15
              for floors = (+ 3 (random 5))
              do (tower (float x) 0.0 floors 2.0 0.15))
        (dome   0.0 0.0 20.0 6.0 8))))"
   ";; Built-in scene 2: Fortress (Layer 3)
;; Click scene 2 or evaluate a similar structure.

(cons \"Fortress (Layer 3)\"
    (lambda ()
      (world (:seed 7)
        (plane 0.0 0.0 120.0 120.0 0.0)
        (fortress 0.0 0.0 40.0)
        ;; A few outbuildings
        (dome   25.0 0.0 25.0 5.0 8)
        (colonnade -15.0 0.0 10.0 5 0.8 8.0)
        (torus  0.0 20.0 0.0 8.0 1.0 16))))"
   ";; Built-in scene 3: Walled City (Layer 4)
;; Click scene 3 or evaluate a similar structure.

(cons \"Walled City (Layer 4)\"
    (lambda ()
      (world (:seed 77)
        (plane 0.0 0.0 200.0 200.0 0.0)
        (walled-city 0.0 0.0 60.0 0.25)
        ;; Outpost towers
        (keep  80.0  80.0 2.5 5)
        (keep -80.0  80.0 2.5 5)
        (keep  80.0 -80.0 2.5 5)
        (keep -80.0 -80.0 2.5 5)
        ;; Aqueduct approximation (colonnades)
        (colonnade  0.0 0.0 120.0 13 0.6 12.0)
        ;; Domes
        (dome  0.0 0.0  0.0 10.0 12)
        (dome 40.0 0.0 40.0  6.0  8))))"
   ";; Built-in scene 4: Towers of Babel (Abstract)
;; Click scene 4 or evaluate a similar structure.

(cons \"Towers of Babel (Abstract)\"
    (lambda ()
      (world (:seed 99)
        (plane 0.0 0.0 150.0 150.0 0.0)
        ;; Radial arrangement of towers
        (loop for i from 0 below 8
              for angle = (* 2.0 pi (/ i 8))
              for radius = 35.0
              for floors = (+ 4 (random 8))
              do (let ((tx (* radius (cos angle)))
                       (tz (* radius (sin angle))))
                   (keep (float tx) (float tz) (+ 1.5 (random 3.0)) floors)))
        ;; Central mega-tower
        (tower 0.0 0.0 20 8.0 0.05)
        (dome  0.0 (* 20 3.5) 0.0 10.0 12)
        ;; Perimeter arches
        (loop for i from 0 below 4
              for angle = (* 0.5 pi i)
              do (arch (* 55.0 (cos angle)) 0.0 (* 55.0 (sin angle))
                       10.0 7.0 2.5 :gothic)))))"
   ";; Built-in scene 5: Orbital Ring Stations
;; Click scene 5 or evaluate a similar structure.

(cons \"Orbital Ring Stations\"
    (lambda ()
      (world (:seed 512)
        ;; Three concentric rings of structures
        (plane 0.0 0.0 200.0 200.0 0.0)
        (dolist (ring '((20.0 . 6) (45.0 . 9) (75.0 . 12)))
          (let ((r (car ring)) (n (cdr ring)))
            (loop for i from 0 below n
                  for angle = (* 2.0 pi (/ i n))
                  for tx = (* r (cos angle))
                  for tz = (* r (sin angle))
                  for h  = (+ 2 (random 5))
                  do (keep (float tx) (float tz) (+ 0.8 (random 1.5)) h))))
        ;; Spokes
        (loop for i from 0 below 6
              for angle = (* (/ pi 3) i)
              do (babel-line (* 20.0 (cos angle)) 0.0 (* 20.0 (sin angle))
                             (* 75.0 (cos angle)) 0.0 (* 75.0 (sin angle))))
        (dome 0.0 0.0 0.0 14.0 12)
        (loop for angle in (list 0.0 (/ pi 2) pi (* 3 (/ pi 2)))
              do (arch (* 85.0 (cos angle)) 0.0 (* 85.0 (sin angle))
                       12.0 9.0 3.0 :gothic)))))"
   ";; Built-in scene 6: Cave / Strata Cross-Section
;; Click scene 6 or evaluate a similar structure.

(cons \"Cave / Strata Cross-Section\"
    (lambda ()
      (world (:seed 333)
        ;; Surface grid
        (loop for ix from -2 to 2 do
          (loop for iz from -2 to 2 do
            (plane (* (float ix) 20.0) (* (float iz) 20.0) 18.0 18.0 0.0)))
        ;; Strata
        (dolist (entry '((-8.0 . 0.6) (-18.0 . 0.4) (-30.0 . 0.25)))
          (let ((y (car entry)) (sc (cdr entry)))
            (loop for ix from -3 to 3 do
              (loop for iz from -3 to 3 do
                (box (* (float ix) 12.0 sc) (float y) (* (float iz) 12.0 sc)
                     (* 10.0 sc) 0.4 (* 10.0 sc))))))
        ;; Stalactites / stalagmites
        (loop repeat 18
              for cx = (- (random 60.0) 30.0)
              for cz = (- (random 60.0) 30.0)
              for ch = (+ 4.0 (random 10.0))
              do (cone cx (- -8.0 ch) cz (+ 0.3 (random 1.2)) ch 6)
                 (cone cx -8.0 cz (+ 0.3 (random 1.2)) (- ch) 6))
        ;; Underground fortress
        (fortress 0.0 -20.0 30.0)
        ;; Sphere void
        (sphere 15.0 -15.0 10.0 8.0 8))))"
   ";; Built-in scene 7: Terrain Landscape
;; Click scene 7 or evaluate a similar structure.

(cons \"Terrain Landscape\"
    (lambda ()
      (world (:seed 888)
        ;; Terrain amplitude 5 — gentle rolling hills, max 5 units tall.
        ;; All architecture builds at y=0, so it always sits above terrain.
        (terrain 0.0 0.0 200.0 200.0 32 5.0)
        ;; Central fortress on flat ground
        (fortress 0.0 0.0 36.0)
        ;; Outpost keeps at four corners
        (keep  70.0  70.0 1.8 6)
        (keep -70.0  70.0 1.8 5)
        (keep  70.0 -70.0 1.8 5)
        (keep -70.0 -70.0 1.8 7)
        ;; Colonnades forming roads between keeps and fortress
        (colonnade  35.0  0.0 60.0 8 0.4 8.0)
        (colonnade -35.0  0.0 60.0 8 0.4 8.0)
        ;; Dome at the centre
        (dome 0.0 0.0 0.0 10.0 10))))"
   ";; Built-in scene 8: Grand Cathedral
;; Click scene 8 or evaluate a similar structure.

(cons \"Grand Cathedral\"
    (lambda ()
      (world (:seed 42)
        ;; Ground plane
        (plane 0.0 0.0 200.0 200.0 0.0)
        ;; Cathedral nave — central long box
        (box    0.0 10.0  0.0  20.0 20.0 70.0)
        ;; Transept arms
        (box  -22.0  8.0  10.0 24.0 16.0 18.0)
        (box   22.0  8.0  10.0 24.0 16.0 18.0)
        ;; Apse (rounded east end) — dome + colonnade
        (dome  0.0 20.0 -32.0 10.0 12)
        (colonnade -8.0 -32.0 16.0 5 0.6 12.0)
        ;; West facade — two towers flanking central arch
        (tower -12.0 35.0  7 3.0 0.05)
        (tower  12.0 35.0  7 3.0 0.05)
        (arch    0.0  0.0 35.0 10.0 8.0 2.5 :gothic)
        ;; Flying buttresses along nave — arches on each side
        (loop for z from -20 to 20 by 10 do
          (arch -16.0 0.0 (float z) 12.0 7.0 1.0 :roman)
          (arch  16.0 0.0 (float z) 12.0 7.0 1.0 :roman))
        ;; Clerestory windows — small boxes cut into nave walls
        (loop for z from -25 to 25 by 10 do
          (box -10.0 16.0 (float z)  0.5 4.0 4.0)
          (box  10.0 16.0 (float z)  0.5 4.0 4.0))
        ;; Bell tower behind apse
        (keep  0.0 -50.0 2.5 10)
        ;; Cloisters — two colonnades forming an L
        (colonnade -30.0 -15.0 40.0 9 0.5 8.0)
        (colonnade -15.0 -30.0 40.0 9 0.5 8.0)
        ;; Chapter house — small domed octagon approximation
        (dome -40.0 0.0 -20.0 8.0 8)
        (box  -40.0  4.0 -20.0 14.0  8.0 14.0)
        ;; Perimeter stone wall
        (battlement  0.0 0.0  70.0 80.0 1.0 2.5 20)
        (battlement  0.0 0.0 -70.0 80.0 1.0 2.5 20)
        (battlement -40.0 0.0  0.0 80.0 1.0 2.5 20)
        (battlement  40.0 0.0  0.0 80.0 1.0 2.5 20))))"
   ";; Built-in scene 9: Amphitheatre
;; Click scene 9 or evaluate a similar structure.

(cons \"Amphitheatre\"
    (lambda ()
      (world (:seed 234)
        (plane 0.0 0.0 250.0 250.0 0.0)
        ;; Tiered seating — concentric rings of colonnades at rising heights
        (loop for tier from 0 below 5
              for r = (+ 20.0 (* tier 12.0))
              for y = (* tier 2.5)
              for n = (max 8 (round (* 2 pi r 0.15)))
              do (loop for i from 0 below n
                       for angle = (* 2.0 pi (/ i n))
                       do (box (* r (cos angle))
                               (+ y 1.0)
                               (* r (sin angle))
                               2.5 2.0 2.0)))
        ;; Stage floor
        (box 0.0 0.5 0.0 18.0 1.0 24.0)
        ;; Proscenium arch
        (arch 0.0 1.0 12.0 16.0 9.0 3.0 :roman)
        ;; Stage backdrop — colonnade
        (colonnade 0.0 -10.0 18.0 9 0.8 12.0)
        ;; Four entrance arches on cardinal axes
        (loop for angle in (list 0.0 (* 0.5 pi) pi (* 1.5 pi))
              for r = 72.0
              do (arch (* r (cos angle)) 0.0 (* r (sin angle))
                       10.0 7.0 2.0 :roman))
        ;; Outer perimeter wall
        (loop for i from 0 below 32
              for a0 = (* 2.0 pi (/ i 32))
              for a1 = (* 2.0 pi (/ (1+ i) 32))
              for r  = 80.0
              do (babel-line (* r (cos a0)) 6.0 (* r (sin a0))
                             (* r (cos a1)) 6.0 (* r (sin a1)))
                 (babel-line (* r (cos a0)) 0.0 (* r (sin a0))
                             (* r (cos a0)) 6.0 (* r (sin a0)))))))"
   ";; Built-in scene 10: Procedural City Grid
;; Click scene 10 or evaluate a similar structure.

(cons \"Procedural City Grid\"
    (lambda ()
      (world (:seed 1001)
        (plane 0.0 0.0 300.0 300.0 0.0)
        ;; City blocks on a regular grid
        (loop for gx from -3 to 3
              do (loop for gz from -3 to 3
                       for bx = (* (float gx) 36.0)
                       for bz = (* (float gz) 36.0)
                       for variant = (random 4)
                       do (case variant
                            (0 ;; Tower block
                             (let ((h (+ 3 (random 9))))
                               (tower bx bz h (+ 2.0 (random 3.0)) 0.05)))
                            (1 ;; Wide low building
                             (box bx (+ 3.0 (random 4.0)) bz
                                  (+ 14.0 (random 8.0))
                                  (+ 6.0  (random 8.0))
                                  (+ 14.0 (random 8.0))))
                            (2 ;; Keep
                             (keep bx bz (+ 1.5 (random 2.0)) (+ 2 (random 5))))
                            (3 ;; Dome
                             (dome bx 0.0 bz
                                   (+ 4.0 (random 6.0))
                                   8)))))
        ;; Road grid — lines between blocks
        (loop for g from -3 to 3
              for coord = (* (float g) 36.0)
              do (babel-line coord 0.5 -120.0  coord 0.5  120.0)
                 (babel-line -120.0 0.5 coord  120.0 0.5  coord))
        ;; Central plaza — fountain torus + dome
        (torus 0.0 1.5 0.0 8.0 1.0 16)
        (dome  0.0 0.0 0.0 12.0 10)
        ;; City wall perimeter
        (battlement   0.0 0.0  130.0 280.0 1.5 4.0 28)
        (battlement   0.0 0.0 -130.0 280.0 1.5 4.0 28)
        (battlement  130.0 0.0   0.0 280.0 1.5 4.0 28)
        (battlement -130.0 0.0   0.0 280.0 1.5 4.0 28))))"
   ))

(defun scene-code-snippet (index)
  "Return a displayable source snippet for a built-in scene index."
  (when (and (integerp index)
             (<= 0 index)
             (< index (length *scene-code-snippets*)))
    (aref *scene-code-snippets* index)))

(defun read-scene-code-forms (source)
  "Read all Lisp forms from a scene-code string in the BABEL package."
  (let ((*package* (find-package :babel))
        (forms '()))
    (with-input-from-string (in source)
      (loop for form = (read in nil :eof)
            until (eq form :eof) do
              (push form forms)))
    (nreverse forms)))

(defun scene-code-function (index)
  "Compile the visible scene-code snippet into the function used by the main view.
This keeps the Structure Code editor and the 3D object synchronized."
  (let ((source (scene-code-snippet index)))
    (when source
      (handler-case
          (let* ((forms (read-scene-code-forms source))
                 (result (and forms (eval (first forms)))))
            (cond
              ((functionp result)
               result)
              ((and (consp result) (functionp (cdr result)))
               (cdr result))
              (t nil)))
        (error (e)
          (format t "~&[BABEL] Could not compile scene code for scene ~D: ~A~%" index e)
          nil)))))
