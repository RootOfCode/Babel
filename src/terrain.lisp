;;;; src/terrain.lisp
;;;; Procedural terrain generation via the diamond-square algorithm.
;;;; Produces a heightmap that is emitted as a wireframe mesh using EMIT-EDGES.
;;;; The terrain macro is registered at Layer 1 so higher-layer macros can
;;;; compose it with architecture.

(in-package #:babel)

;;; ─── Diamond-square heightmap ────────────────────────────────────────────────

(defun make-heightmap (size)
  "Allocate a SIZE×SIZE float array initialised to 0."
  (make-array (list size size) :element-type 'single-float :initial-element 0.0))

(defun hmap-ref (hmap x z size)
  "Wrap-safe heightmap read."
  (aref hmap (mod x size) (mod z size)))

(defun hmap-set! (hmap x z val)
  (setf (aref hmap x z) val))

(defun diamond-square! (hmap size roughness)
  "Run the diamond-square algorithm in-place on HMAP.
   SIZE must be (2^n)+1.  ROUGHNESS ∈ [0,1] controls amplitude decay."
  ;; Seed corners
  (hmap-set! hmap 0         0         (- (random 2.0) 1.0))
  (hmap-set! hmap (1- size) 0         (- (random 2.0) 1.0))
  (hmap-set! hmap 0         (1- size) (- (random 2.0) 1.0))
  (hmap-set! hmap (1- size) (1- size) (- (random 2.0) 1.0))
  (let ((step (1- size))
        (scale 1.0))
    (loop while (> step 1) do
      (let ((half (floor step 2)))
        ;; Diamond step
        (loop for x from 0 below (1- size) by step do
          (loop for z from 0 below (1- size) by step do
            (let* ((avg (/ (+ (hmap-ref hmap x        z        size)
                              (hmap-ref hmap (+ x step) z        size)
                              (hmap-ref hmap x        (+ z step) size)
                              (hmap-ref hmap (+ x step) (+ z step) size))
                           4.0))
                   (cx  (+ x half))
                   (cz  (+ z half)))
              (hmap-set! hmap cx cz (+ avg (* scale (- (random 2.0) 1.0)))))))
        ;; Square step
        (loop for x from 0 below (1- size) by half do
          (loop for z from (if (zerop (mod x step)) half 0)
                  below (1- size) by step do
            (let* ((sum   0.0)
                   (count 0))
              (flet ((add (ax az)
                       (when (and (>= ax 0) (< ax size) (>= az 0) (< az size))
                         (incf sum (hmap-ref hmap ax az size))
                         (incf count))))
                (add x         (- z half))
                (add x         (+ z half))
                (add (- x half) z)
                (add (+ x half) z))
              (hmap-set! hmap x z
                         (+ (/ sum (float count))
                            (* scale (- (random 2.0) 1.0)))))))
        (setf step half
              scale (* scale (expt 2.0 (- roughness 1.0))))))))

;;; ─── Heightmap → wireframe ───────────────────────────────────────────────────

(defun emit-terrain-edges (cx cz width depth resolution amplitude)
  "Emit a wireframe terrain mesh.
   CX, CZ   — world-space centre.
   WIDTH, DEPTH — horizontal extents.
   RESOLUTION   — grid divisions (power-of-two recommended, e.g. 16 32 64).
   AMPLITUDE    — vertical scale of height variation."
  (let* ((n       (1+ resolution))      ; vertices per side
         (size    (1+ (expt 2 (ceiling (log resolution 2))))) ; DS needs 2^k+1
         (hmap    (make-heightmap size))
         (verts   '())
         (edges   '()))
    ;; Generate heightmap
    (diamond-square! hmap size 0.6)
    ;; Normalise heights to [0, 1]
    (let ((lo  most-positive-single-float)
          (hi  most-negative-single-float))
      (dotimes (ix size)
        (dotimes (iz size)
          (let ((v (aref hmap ix iz)))
            (setf lo (min lo v) hi (max hi v)))))
      (when (/= lo hi)
        (dotimes (ix size)
          (dotimes (iz size)
            (hmap-set! hmap ix iz
                       (/ (- (aref hmap ix iz) lo)
                          (- hi lo)))))))
    ;; Build vertex grid (sample hmap at resolution×resolution)
    (let ((hw (* 0.5 width))
          (hd (* 0.5 depth)))
      (dotimes (iz n)
        (dotimes (ix n)
          (let* ((u   (/ (float ix) (float (1- n))))
                 (v   (/ (float iz) (float (1- n))))
                 (sx  (round (* u (1- size))))
                 (sz  (round (* v (1- size))))
                 (h   (hmap-ref hmap sx sz size))
                 (px  (+ cx (- (* u width) hw)))
                 (py  (* h amplitude))
                 (pz  (+ cz (- (* v depth) hd))))
            (push (list px py pz) verts)))))
    ;; Build edges: X strips + Z strips
    (setf verts (nreverse verts))
    (dotimes (iz n)
      (dotimes (ix (1- n))
        (push (list (+ (* iz n) ix) (+ (* iz n) ix 1)) edges)))
    (dotimes (ix n)
      (dotimes (iz (1- n))
        (push (list (+ (* iz n) ix) (+ (* (1+ iz) n) ix)) edges)))
    (emit-edges (nreverse verts) (nreverse edges))))

;;; ─── TERRAIN function ────────────────────────────────────────────────────────

(defun terrain (cx cz width depth resolution amplitude)
  "Wireframe terrain centred at (CX, 0, CZ) with given dimensions.
   RESOLUTION — grid cells per side (16, 32, 64 …).
   AMPLITUDE  — height scale."
  (emit-terrain-edges cx cz width depth resolution amplitude))

;;; ─── Register terrain as a Layer-1 BABEL macro ───────────────────────────────

(defun register-terrain-macro! ()
  "Add TERRAIN to the BABEL registry at layer 1."
  (unless (gethash 'terrain *babel-registry*)
    (register-macro!
     (make-babel-macro
      :name        'terrain
      :layer       1
      :params      '(cx cz width depth resolution amplitude)
      :body        '(emit-terrain-edges cx cz width depth resolution amplitude)
      :dependencies '()
      :complexity  2
      :score       0.85
      :usage-count 0
      :invented-at 0
      :doc         "Diamond-square procedural terrain mesh."))))

;;; ─── Convenience: flat plateau ───────────────────────────────────────────────

(defun emit-plateau-edges (cx cz width depth y-base height)
  "Emit a flat raised platform with sloped sides."
  ;; Top face
  (emit-plane-edges cx cz width depth y-base 4)
  ;; Edge walls: four sides as colonnades of vertical lines
  (let ((hw (* 0.5 width))
        (hd (* 0.5 depth))
        (steps 8))
    (dotimes (i (1+ steps))
      (let ((u (/ (float i) steps)))
        ;; Front and back edges
        (let ((px (+ cx (- (* u width) hw))))
          (emit-edges
           (list (list px y-base (+ cz hd))
                 (list px (- y-base height) (+ cz hd)))
           '((0 1)))
          (emit-edges
           (list (list px y-base (- cz hd))
                 (list px (- y-base height) (- cz hd)))
           '((0 1))))
        ;; Left and right edges
        (let ((pz (+ cz (- (* u depth) hd))))
          (emit-edges
           (list (list (+ cx hw) y-base pz)
                 (list (+ cx hw) (- y-base height) pz))
           '((0 1)))
          (emit-edges
           (list (list (- cx hw) y-base pz)
                 (list (- cx hw) (- y-base height) pz))
           '((0 1))))))))

(defun plateau (cx cz width depth y-base wall-height)
  "Flat raised platform at Y-BASE with WALL-HEIGHT drop on all sides."
  (emit-plateau-edges cx cz width depth y-base wall-height))
