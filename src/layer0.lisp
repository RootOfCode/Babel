;;;; src/layer0.lisp
;;;; Layer-0 primitives — regular CL *functions* (not macros).
;;;;
;;;; All geometry builders are plain defuns that call emit-edges or the
;;;; helper emitters in geometry.lisp at runtime. Being functions means:
;;;;   • They compose naturally without macroexpansion-time type errors.
;;;;   • Higher-layer builders (tower, dome, …) are also just functions.
;;;;   • The WORLD macro and scene lambdas compile cleanly regardless of
;;;;     whether the functions are defined yet (forward references are fine
;;;;     for functions; they are fatal for macros).

(in-package #:babel)

;;; ─── Layer-0 function definitions ───────────────────────────────────────────

(defun box (x y z w h d)
  "Axis-aligned wireframe box centred at (X Y Z) with dimensions W H D."
  (let ((hw (/ (float w) 2.0))
        (hh (/ (float h) 2.0))
        (hd (/ (float d) 2.0)))
    (emit-edges
     (list (list (- x hw) (- y hh) (- z hd))   ; 0 bottom-left-back
           (list (+ x hw) (- y hh) (- z hd))   ; 1 bottom-right-back
           (list (+ x hw) (- y hh) (+ z hd))   ; 2 bottom-right-front
           (list (- x hw) (- y hh) (+ z hd))   ; 3 bottom-left-front
           (list (- x hw) (+ y hh) (- z hd))   ; 4 top-left-back
           (list (+ x hw) (+ y hh) (- z hd))   ; 5 top-right-back
           (list (+ x hw) (+ y hh) (+ z hd))   ; 6 top-right-front
           (list (- x hw) (+ y hh) (+ z hd)))  ; 7 top-left-front
     '((0 1)(1 2)(2 3)(3 0)
       (4 5)(5 6)(6 7)(7 4)
       (0 4)(1 5)(2 6)(3 7)))))

(defun sphere (x y z r steps)
  "Wireframe sphere at (X Y Z) with radius R and STEPS subdivisions."
  (emit-sphere-edges x y z r steps))

(defun babel-line (x0 y0 z0 x1 y1 z1)
  "Single wireframe edge from (X0 Y0 Z0) to (X1 Y1 Z1)."
  (emit-edges (list (list x0 y0 z0) (list x1 y1 z1)) '((0 1))))

(defun plane (cx cz w d y)
  "Horizontal wireframe grid centred at (CX, Y, CZ) with footprint W × D."
  (emit-plane-edges cx cz w d y 4))

(defun cone (x y z r h steps)
  "Wireframe cone at (X Y Z) with base radius R, height H and STEPS facets."
  (emit-cone-edges x y z r h steps))

(defun torus (x y z r tube steps)
  "Wireframe torus at (X Y Z) with major radius R, tube radius TUBE."
  (emit-torus-edges x y z r tube steps))

(defun arch (x y z span rise width style)
  "Structural arch at (X Y Z). STYLE is :roman or :gothic."
  (emit-arch-edges x y z span rise width style))

(defun half-dome (x y z r steps)
  "Wireframe hemisphere sitting at (X Y Z): flat base at Y, apex at Y+R.
   Use this instead of DOME/SPHERE when you want an actual dome, not a ball."
  (emit-hemisphere-edges x y z r steps))

(defun cylinder (x y z r h steps)
  "Vertical cylinder at (X Y Z), radius R, height H, STEPS facets.
   Flat base at Y, flat top at Y+H. Use for round towers, columns, cisterns."
  (emit-cylinder-edges x y z r h steps))

(defun pyramid (x y z base-w base-d height)
  "Square pyramid with base centred at (X Y Z), apex at Y+HEIGHT.
   Use for roofs, obelisks, and tent tops."
  (emit-pyramid-edges x y z base-w base-d height))

(defun vault (x y z span length steps)
  "Barrel vault of width SPAN extruded LENGTH along Z.
   The semicircular profile is centred at (X Y Z). Use for covered corridors,
   crypts, and undercrofts."
  (emit-vault-edges x y z span length steps))

(defun staircase (x y z width n-steps step-h step-d)
  "Staircase rising along +Z from (X Y Z). N-STEPS steps, each STEP-H tall
   and STEP-D deep, WIDTH wide. Use for exterior entry stairs, battlements."
  (emit-staircase-edges x y z width n-steps step-h step-d))

(defun spire (x y z height base-r sides)
  "Polygonal spire rising from Y to Y+HEIGHT. BASE-R is the base polygon
   radius, SIDES is the number of faces (4=square, 8=octagonal).
   Use on top of towers, chapels, and gatehouse roofs."
  (emit-spire-edges x y z height base-r sides))

(defun flying-buttress (wall-x wall-y wall-z pier-x pier-y pier-z thickness)
  "A Bezier-arc flying buttress leaping from the wall attachment point
   (WALL-X WALL-Y WALL-Z) to a free-standing pier at (PIER-X PIER-Y PIER-Z).
   THICKNESS is the arch depth. Use paired on each side of a nave or chapel."
  (emit-flying-buttress-edges wall-x wall-y wall-z
                               pier-x pier-y pier-z thickness))

(defun wall-segment (x0 z0 x1 z1 y-base height thickness)
  "Thick wall panel whose base runs from (X0,Z0) to (X1,Z1), rising from
   Y-BASE to Y-BASE+HEIGHT with the given THICKNESS. The wall is extruded
   perpendicular to its run direction. Use this as the fundamental building
   block for any connected wall structure."
  (emit-wall-segment-edges x0 z0 x1 z1 y-base height thickness))

;;; ─── Register all Layer-0 functions in the registry ─────────────────────────
;;; register-macro! now calls DEFUN (see registry.lisp), so these bodies
;;; are plain function bodies — no quasiquoting, no macroexpansion tricks.

(defun register-layer-0! ()
  "Install all Layer-0 primitives into *babel-registry*."
  (flet ((reg (name params body &optional (doc ""))
           (register-macro!
            (make-babel-macro
             :name name :layer 0 :params params :body body
             :dependencies '() :complexity 1
             :score 1.0 :usage-count 0 :invented-at 0
             :doc doc))))

    (reg 'box '(x y z w h d)
         '(let ((hw (/ (float w) 2.0))
                (hh (/ (float h) 2.0))
                (hd (/ (float d) 2.0)))
           (emit-edges
            (list (list (- x hw) (- y hh) (- z hd))
                  (list (+ x hw) (- y hh) (- z hd))
                  (list (+ x hw) (- y hh) (+ z hd))
                  (list (- x hw) (- y hh) (+ z hd))
                  (list (- x hw) (+ y hh) (- z hd))
                  (list (+ x hw) (+ y hh) (- z hd))
                  (list (+ x hw) (+ y hh) (+ z hd))
                  (list (- x hw) (+ y hh) (+ z hd)))
            '((0 1)(1 2)(2 3)(3 0)
              (4 5)(5 6)(6 7)(7 4)
              (0 4)(1 5)(2 6)(3 7))))
         "Axis-aligned wireframe box")

    (reg 'sphere '(x y z r steps)
         '(emit-sphere-edges x y z r steps)
         "Wireframe sphere")

    (reg 'babel-line '(x0 y0 z0 x1 y1 z1)
         '(emit-edges (list (list x0 y0 z0) (list x1 y1 z1)) '((0 1)))
         "Single wireframe edge")

    (reg 'plane '(cx cz w d y)
         '(emit-plane-edges cx cz w d y 4)
         "Horizontal wireframe grid")

    (reg 'cone '(x y z r h steps)
         '(emit-cone-edges x y z r h steps)
         "Wireframe cone")

    (reg 'torus '(x y z r tube steps)
         '(emit-torus-edges x y z r tube steps)
         "Wireframe torus")

    (reg 'arch '(x y z span rise width style)
         '(emit-arch-edges x y z span rise width style)
         "Structural arch")

    (reg 'wall-segment '(x0 z0 x1 z1 y-base height thickness)
         '(emit-wall-segment-edges x0 z0 x1 z1 y-base height thickness)
         "Thick wall panel between two XZ points")

    (reg 'half-dome '(x y z r steps)
         '(emit-hemisphere-edges x y z r steps)
         "True hemisphere — flat base at Y, apex at Y+R")

    (reg 'cylinder '(x y z r h steps)
         '(emit-cylinder-edges x y z r h steps)
         "Vertical cylinder: bottom ring at Y, top ring at Y+H")

    (reg 'pyramid '(x y z base-w base-d height)
         '(emit-pyramid-edges x y z base-w base-d height)
         "Square pyramid: base at Y, apex at Y+HEIGHT")

    (reg 'vault '(x y z span length steps)
         '(emit-vault-edges x y z span length steps)
         "Barrel vault: semicircular arch extruded LENGTH along Z")

    (reg 'staircase '(x y z width n-steps step-h step-d)
         '(emit-staircase-edges x y z width n-steps step-h step-d)
         "Staircase rising along +Z from X Y Z")

    (reg 'spire '(x y z height base-r sides)
         '(emit-spire-edges x y z height base-r sides)
         "Polygonal spire: base polygon at Y, apex at Y+HEIGHT")

    (reg 'flying-buttress '(wall-x wall-y wall-z pier-x pier-y pier-z thickness)
         '(emit-flying-buttress-edges wall-x wall-y wall-z
                                      pier-x pier-y pier-z thickness)
         "Bezier arc flying buttress between wall and pier"))

  (format t "~&[BABEL] Layer 0 registered (~D macros)~%"
          (hash-table-count *babel-registry*)))

